// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import WallpaperPackageManager

@main
struct CoconutLabApp: App {
    @State private var language = AppLanguageStore.shared
    @State private var engine = EngineSession()
    @State private var library = PackageLibrary()
    @State private var catalog = CatalogStore()
    @State private var router = AppRouter()
    @State private var galleryPreferences = GalleryPreferences()
    @AppStorage("Coconut.appearance") private var appearance = "system"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(language)
                .environment(engine)
                .environment(\.locale, language.locale)
                .environment(library)
                .environment(catalog)
                .environment(router)
                .environment(galleryPreferences)
                .tint(Theme.accent)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        }
    }
}

enum AppTab: Hashable { case download, importing }

/// Qué pestaña se ve y qué fondo mostrar al llegar a Importar.
@MainActor @Observable
final class AppRouter {
    var tab: AppTab = .download
    var focusedPackageID: UUID?

    func showImported(_ id: UUID) {
        focusedPackageID = id
        tab = .importing
    }
}

/// Las dos pestañas. La alerta de error vive aquí para verse desde cualquiera de ellas.
struct RootView: View {
    @Environment(PackageLibrary.self) private var library
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            CatalogView()
                .tabItem { Label(L.text("Explorar"), systemImage: "square.grid.2x2") }
                .tag(AppTab.download)
            HomeView()
                .tabItem { Label(L.text("Mi colección"), systemImage: "square.stack") }
                .tag(AppTab.importing)
        }
        .task { await library.updateBundledPackages() }
        .onOpenURL { url in
            Task {
                if let id = await library.importPackage(at: url) { router.showImported(id) }
            }
        }
        .alert(L.text("No se pudo completar"),
               isPresented: Binding(get: { library.lastError != nil },
                                    set: { if !$0 { library.lastError = nil } })) {
            Button(L.text("Aceptar"), role: .cancel) {}
        } message: {
            Text(L.message(library.lastError ?? ""))
        }
    }
}

/// Un paquete que el usuario ya importó y pasó la validación del motor.
/// Conserva el paquete comprobado dentro del sandbox para preparar su aplicación.
struct ImportedPackage: Identifiable, Codable, Sendable {
    var id = UUID()
    let fileName: String
    let importedAt: Date
    let inspection: Inspection
    let reportJSON: String
    /// Nombre e imagen del catálogo, si vino de la pestaña Descargar.
    var title: String?
    var previewURL: URL?

    @MainActor var displayName: String {
        L.text(title ?? (fileName as NSString).deletingPathExtension)
    }

    var archiveURL: URL {
        PackageStorage.directory.appendingPathComponent(inspection.sha256 + ".tendies")
    }
}

enum PackageStorage {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Coconut/Packages", isDirectory: true)
    }
    static var indexURL: URL { directory.deletingLastPathComponent().appendingPathComponent("library.json") }
}

/// Biblioteca persistente de paquetes inspeccionados. Se revalida el SHA antes de aplicar.
@MainActor @Observable
final class PackageLibrary {
    private(set) var packages: [ImportedPackage] = []
    private(set) var busy = false
    var lastError: String?
    private var checkedBundledUpdates = false

    init() {
        guard FileManager.default.fileExists(atPath: PackageStorage.indexURL.path) else { return }
        do {
            let saved = try JSONDecoder().decode([ImportedPackage].self, from: Data(contentsOf: PackageStorage.indexURL))
            packages = saved.filter {
                $0.inspection.sha256.count == 64 && $0.inspection.sha256.allSatisfy { $0.isASCII && $0.isHexDigit }
                    && FileManager.default.fileExists(atPath: $0.archiveURL.path)
            }.map { package in
                var restored = package
                if let preview = restored.previewURL, preview.isFileURL {
                    let name = preview.deletingPathExtension().lastPathComponent
                    restored.previewURL = Bundle.main.url(forResource: name + "-artwork", withExtension: "jpg", subdirectory: "BundledCatalog")
                        ?? Bundle.main.url(forResource: name, withExtension: preview.pathExtension, subdirectory: "BundledCatalog")
                }
                return restored
            }
        } catch { lastError = L.text("No se pudo recuperar la biblioteca guardada. Puedes volver a importar los fondos.") }
    }

    /// Valida el archivo con el motor y lo añade al principio de la lista.
    /// Con `expectedSHA256`, el motor rechaza el archivo si no coincide byte a byte.
    @discardableResult
    func importPackage(at url: URL, expectedSHA256: String? = nil,
                       title: String? = nil, previewURL: URL? = nil,
                       replacing previous: ImportedPackage? = nil) async -> UUID? {
        lastError = nil
        do {
            return try await storePackage(at: url, expectedSHA256: expectedSHA256, title: title, previewURL: previewURL, replacing: previous)
        } catch { lastError = error.localizedDescription; return nil }
    }

    @discardableResult
    func storePackage(at url: URL, expectedSHA256: String? = nil,
                      title: String? = nil, previewURL: URL? = nil,
                      replacing previous: ImportedPackage? = nil) async throws -> UUID {
        guard !busy else { throw LibraryImportError.busy }
        guard url.pathExtension.lowercased() == "tendies" else { throw LibraryImportError.extensionMismatch }
        busy = true
        defer { busy = false }
        let (inspection, json) = try await Task.detached(priority: .userInitiated) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let staged = try PackageInspector().stage(url, expectedSHA256: expectedSHA256)
            defer { try? FileManager.default.removeItem(at: staged.directory) }
            try FileManager.default.createDirectory(at: PackageStorage.directory, withIntermediateDirectories: true)
            let stored = PackageStorage.directory.appendingPathComponent(staged.inspection.sha256 + ".tendies")
            let pending = PackageStorage.directory.appendingPathComponent(UUID().uuidString + ".tendies")
            defer { try? FileManager.default.removeItem(at: pending) }
            try FileManager.default.copyItem(at: staged.directory.appendingPathComponent("package.tendies"), to: pending)
            if FileManager.default.fileExists(atPath: stored.path) {
                _ = try FileManager.default.replaceItemAt(stored, withItemAt: pending)
            } else {
                try FileManager.default.moveItem(at: pending, to: stored)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return (staged.inspection, String(decoding: try encoder.encode(staged.inspection), as: UTF8.self))
        }.value
        var package = ImportedPackage(fileName: url.lastPathComponent, importedAt: .now,
                                      inspection: inspection, reportJSON: json,
                                      title: title, previewURL: previewURL)
        if let catalogURL = Bundle.main.url(forResource: "catalog", withExtension: "json", subdirectory: "BundledCatalog"),
           let data = try? Data(contentsOf: catalogURL),
           let themes = try? JSONDecoder().decode(ImportedCatalog.self, from: data).themes,
           let match = themes.first(where: { $0.sha256 == inspection.sha256 }),
           let resolved = try? match.resolvingResources(relativeTo: catalogURL.deletingLastPathComponent()) {
            package.title = resolved.name
            package.previewURL = resolved.artworkURL
        }
        if let previous { package.id = previous.id }
        else if let existing = self.package(withSHA256: inspection.sha256) { package.id = existing.id }
        let next = [package] + packages.filter {
            $0.inspection.sha256 != inspection.sha256 && $0.inspection.sha256 != previous?.inspection.sha256
        }
        try persist(next)
        packages = next
        return package.id
    }

    /// Updates only exact known Coconut revisions; never writes to PosterBoard.
    func updateBundledPackages() async {
        guard !checkedBundledUpdates else { return }
        checkedBundledUpdates = true
        struct Update: Decodable { let fileName: String; let oldSHA256: String; let newSHA256: String }
        guard let manifest = Bundle.main.url(forResource: "BundledPackageUpdates", withExtension: "json"),
              let data = try? Data(contentsOf: manifest),
              let updates = try? JSONDecoder().decode([Update].self, from: data) else { return }
        for update in updates {
            guard let old = package(withSHA256: update.oldSHA256),
                  !update.fileName.contains("/"),
                  let source = Bundle.main.url(forResource: update.fileName, withExtension: nil,
                                               subdirectory: "BundledCatalog") else { continue }
            if await importPackage(at: source, expectedSHA256: update.newSHA256,
                                   title: old.title, previewURL: old.previewURL, replacing: old) == nil { return }
        }
    }

    var storedBytes: Int64 {
        packages.reduce(0) { total, package in
            let bytes = Int64(clamping: package.inspection.compressedBytes)
            return total > Int64.max - bytes ? Int64.max : total + bytes
        }
    }

    func package(withSHA256 sha256: String) -> ImportedPackage? {
        packages.first { $0.inspection.sha256.caseInsensitiveCompare(sha256) == .orderedSame }
    }

    func remove(_ package: ImportedPackage) {
        do {
            let next = packages.filter { $0.id != package.id }
            try persist(next)
            packages = next
            if !next.contains(where: { $0.inspection.sha256 == package.inspection.sha256 }) {
                try? FileManager.default.removeItem(at: package.archiveURL)
            }
        } catch { lastError = L.text("No se pudo quitar el fondo de la biblioteca.") }
    }

    private func persist(_ next: [ImportedPackage]) throws {
        try FileManager.default.createDirectory(at: PackageStorage.directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: PackageStorage.indexURL, options: .atomic)
    }
}

private struct ImportedCatalog: Decodable { let themes: [CatalogTheme] }

private enum LibraryImportError: LocalizedError {
    case busy, extensionMismatch
    var errorDescription: String? {
        switch self {
        case .busy: "Espera a que termine la importación actual."
        case .extensionMismatch: "Selecciona un archivo .tendies."
        }
    }
}
