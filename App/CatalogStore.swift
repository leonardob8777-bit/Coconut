// SPDX-License-Identifier: GPL-3.0-only
import Foundation

/// Un tema publicado en el catálogo. Así se escribe cada entrada del JSON:
///
///     { "themes": [ { "id": "aurora", "name": "Aurora", "author": "Leonardo",
///                     "previewURL": "https://…/aurora.jpg",
///                     "packageURL": "https://…/aurora.tendies",
///                     "sha256": "eb1a2c…" } ] }
struct CatalogTheme: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let author: String?
    let previewURL: URL?
    let previewVideoURL: URL?
    let packageURL: URL
    /// Huella del .tendies publicado. El motor rechaza la descarga si no coincide.
    let sha256: String
    var fullResolutionPreviewURL: URL? = nil

    var hasValidIdentity: Bool {
        !id.isEmpty && id.utf8.count <= 64 &&
        id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") } &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        sha256.count == 64 && sha256.allSatisfy { $0.isASCII && $0.isHexDigit }
    }

    var hasValidRemoteResources: Bool {
        let resources: [URL?] = [packageURL, previewURL, previewVideoURL, fullResolutionPreviewURL]
        for case let url? in resources {
            guard url.scheme == "https", let host = url.host, !host.isEmpty,
                  url.user == nil, url.password == nil else { return false }
        }
        return true
    }

    /// Resuelve las rutas relativas del catálogo que viaja dentro de la IPA.
    func resolvingResources(relativeTo directory: URL) throws -> CatalogTheme {
        func resolve(_ url: URL) throws -> URL {
            if url.scheme == "https", url.host != nil, url.user == nil, url.password == nil {
                return url
            }
            guard url.scheme == nil, !url.relativeString.hasPrefix("/"),
                  !url.relativeString.split(separator: "/").contains("..") else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let resolved = directory.appendingPathComponent(url.relativeString)
            guard FileManager.default.fileExists(atPath: resolved.path) else {
                throw CocoaError(.fileNoSuchFile)
            }
            return resolved
        }
        return try CatalogTheme(id: id, name: name, author: author,
                                previewURL: previewURL.map(resolve),
                                previewVideoURL: previewVideoURL.map(resolve),
                                packageURL: resolve(packageURL), sha256: sha256,
                                fullResolutionPreviewURL: fullResolutionPreviewURL.map(resolve))
    }
}

private struct CatalogFile: Decodable {
    let themes: [CatalogTheme]
}

/// Lee el catálogo y descarga temas hacia la biblioteca de Importar.
@MainActor @Observable
final class CatalogStore {
    enum State {
        case notConfigured
        case loading
        case loaded([CatalogTheme])
        case failed(String)
    }

    private(set) var state: State = .notConfigured
    private(set) var downloading: Set<String> = []
    enum UpdateState: Equatable { case idle, checking, current, unavailable }
    private(set) var updateState: UpdateState = .idle
    private(set) var lastUpdatedAt: Date?
    @ObservationIgnored private let fetch: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    @ObservationIgnored private let fetchPackage: @Sendable (URLRequest) async throws -> (URL, URLResponse)

    init(fetch: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = {
        try await URLSession.shared.data(for: $0)
    }) {
        self.fetch = fetch
        self.fetchPackage = { try await URLSession.shared.download(for: $0) }
    }

    init(fetchPackage: @escaping @Sendable (URLRequest) async throws -> (URL, URLResponse),
         fetch: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) {
        self.fetch = fetch
        self.fetchPackage = fetchPackage
    }

    /// Catálogo publicado en GitHub (repositorio Coconut-Catalog).
    static let publishedURL: URL? = URL(string: "https://raw.githubusercontent.com/leonardob8777-bit/Coconut-Catalog/main/catalog.json")

    private var sourceURL: URL? {
        #if DEBUG
        // Solo para pruebas en el Mac: permite apuntar a un catálogo local.
        if let override = ProcessInfo.processInfo.environment["COCONUT_CATALOG_URL"] {
            return URL(string: override)
        }
        #endif
        return Self.publishedURL
    }

    func load() async {
        guard updateState != .checking else { return }
        let previousUpdateState = updateState
        updateState = .checking
        defer { if updateState == .checking { updateState = previousUpdateState } }
        let alreadyLoaded: Bool
        if case .loaded = state { alreadyLoaded = true } else { alreadyLoaded = false; state = .loading }
        let bundled: [CatalogTheme]
        do {
            guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json", subdirectory: "BundledCatalog") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let file = try JSONDecoder().decode(CatalogFile.self, from: Data(contentsOf: url))
            guard file.themes.allSatisfy(\.hasValidIdentity),
                  Set(file.themes.map(\.id)).count == file.themes.count else {
                throw CocoaError(.fileReadCorruptFile)
            }
            bundled = try file.themes.map { try $0.resolvingResources(relativeTo: url.deletingLastPathComponent()) }
        } catch {
            if !alreadyLoaded { state = .failed(L.text("No se pudo leer la colección incluida en esta versión de Coconut.")) }
            updateState = .unavailable
            return
        }
        if !alreadyLoaded { state = .loaded(bundled) }
        guard let sourceURL else { return }
        // Los fondos de prueba están disponibles inmediatamente, incluso sin red.
        do {
            var request = URLRequest(url: sourceURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.timeoutInterval = 8
            let (data, response) = try await fetch(request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
            let remote = try JSONDecoder().decode(CatalogFile.self, from: data).themes
            // El orden lo manda el catálogo publicado (lo más nuevo primero); los temas que solo vienen
            // dentro de la app quedan al final.
            let positions = Dictionary(uniqueKeysWithValues: bundled.enumerated().map { ($0.element.id, $0.offset) })
            var merged: [CatalogTheme] = []
            var remoteIDs = Set<String>()
            for theme in remote where theme.hasValidIdentity && theme.hasValidRemoteResources && remoteIDs.insert(theme.id).inserted {
                // Keep offline artwork for the identical revision; adopt new published revisions.
                if let position = positions[theme.id], bundled[position].sha256 == theme.sha256 {
                    let local = bundled[position]
                    merged.append(CatalogTheme(id: theme.id, name: theme.name, author: theme.author,
                                               previewURL: local.previewURL,
                                               previewVideoURL: theme.previewVideoURL ?? local.previewVideoURL,
                                               packageURL: theme.packageURL, sha256: theme.sha256,
                                               fullResolutionPreviewURL: theme.fullResolutionPreviewURL ?? local.fullResolutionPreviewURL))
                } else {
                    merged.append(theme)
                }
            }
            merged += bundled.filter { !remoteIDs.contains($0.id) }
            state = .loaded(merged)
            lastUpdatedAt = .now
            updateState = .current
        } catch {
            // Keep the last loaded collection, including remote themes, during failed refreshes.
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                updateState = previousUpdateState
            } else {
                updateState = .unavailable
            }
        }
    }

    /// Descarga el .tendies, lo pasa por el motor con su huella y devuelve el fondo importado.
    func download(_ requestedTheme: CatalogTheme, into library: PackageLibrary) async throws -> UUID {
        let selectedID = requestedTheme.id
        guard !downloading.contains(selectedID) else { throw CatalogDownloadError.inProgress }
        guard !selectedID.isEmpty, selectedID.utf8.count <= 64,
              selectedID.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else {
            throw CatalogDownloadError.invalidTheme
        }
        downloading.insert(selectedID)
        defer { downloading.remove(selectedID) }
        // Details may still hold a revision from the IPA or an earlier refresh.
        // Resolve metadata again before requesting bytes from a mutable release URL.
        if !requestedTheme.packageURL.isFileURL { await load() }
        try Task.checkCancellation()
        let theme: CatalogTheme
        if !requestedTheme.packageURL.isFileURL, case .loaded(let themes) = state,
           let current = themes.first(where: { $0.id == selectedID }) {
            theme = current
        } else { theme = requestedTheme }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoconutDownload-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent("\(theme.id).tendies")
            if theme.packageURL.isFileURL {
                try FileManager.default.copyItem(at: theme.packageURL, to: file)
            } else {
                var components = URLComponents(url: theme.packageURL, resolvingAgainstBaseURL: false)
                var query = components?.queryItems ?? []
                query.removeAll { $0.name == "coconutRevision" }
                query.append(URLQueryItem(name: "coconutRevision", value: theme.sha256))
                components?.queryItems = query
                var request = URLRequest(url: components?.url ?? theme.packageURL)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                let (temporary, response) = try await fetchPackage(request)
                defer { try? FileManager.default.removeItem(at: temporary) }
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                try FileManager.default.moveItem(at: temporary, to: file)
            }
            try Task.checkCancellation()
            struct Revision: Decodable { let oldSHA256: String; let newSHA256: String }
            let revisions = Bundle.main.url(forResource: "BundledPackageUpdates", withExtension: "json")
                .flatMap { try? Data(contentsOf: $0) }
                .flatMap { try? JSONDecoder().decode([Revision].self, from: $0) } ?? []
            let previous = revisions.filter { $0.newSHA256 == theme.sha256 }
                .compactMap { library.package(withSHA256: $0.oldSHA256) }.first
            return try await library.storePackage(at: file, expectedSHA256: theme.sha256,
                                               title: theme.name, previewURL: theme.artworkURL, replacing: previous)
        } catch let error as URLError {
            throw CatalogDownloadError.network(error.code)
        }
    }
}

enum CatalogDownloadError: LocalizedError {
    case inProgress, invalidTheme, network(URLError.Code)
    var errorDescription: String? {
        switch self {
        case .inProgress: "La descarga de este tema sigue en curso."
        case .invalidTheme: "El identificador de este fondo no es válido."
        case .network(let code):
            switch code {
            case .notConnectedToInternet, .networkConnectionLost:
                "Comprueba tu conexión y vuelve a intentarlo."
            case .timedOut:
                "La descarga tardó demasiado. Vuelve a intentarlo."
            case .badServerResponse:
                "El servidor no entregó el archivo. Vuelve a intentarlo."
            default:
                "No se pudo descargar el tema. Vuelve a intentarlo."
            }
        }
    }
}
