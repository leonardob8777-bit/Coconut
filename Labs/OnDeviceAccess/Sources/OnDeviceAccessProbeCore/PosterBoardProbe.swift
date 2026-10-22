// SPDX-License-Identifier: GPL-3.0-only
import Foundation

public struct AccessProbeReport: Codable, Sendable {
    public let containerUUID: String
    public let readableCollectionDescriptors: Int
    public let recordedAt: Date
    public let wallpaperInstallationVerified: Bool
}

public enum AccessProbeError: Error, LocalizedError {
    case notFound, ambiguous, unavailableStore
    public var errorDescription: String? {
        switch self {
        case .notFound: "No se encontró un contenedor legible de PosterBoard."
        case .ambiguous: "Se encontraron varios contenedores de PosterBoard; no se seleccionó ninguno."
        case .unavailableStore: "Se encontró PosterBoard, pero su colección no se puede leer."
        }
    }
}

/// Discovery only. Never writes to, creates, or deletes a system container.
public struct PosterBoardProbe: Sendable {
    private let root: URL
    public init() {
        root = URL(fileURLWithPath: "/private/var/mobile/Containers/Data/Application", isDirectory: true)
    }
    // Fixture injection is confined to this module's tests.
    init(root: URL) { self.root = root }

    public func inspect() throws -> AccessProbeReport {
        let fm = FileManager.default
        let children = try fm.contentsOfDirectory(at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
        var matches: [URL] = []
        for child in children {
            guard UUID(uuidString: child.lastPathComponent) != nil else { continue }
            let attributes = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard attributes.isDirectory == true, attributes.isSymbolicLink != true else { continue }
            let metadata = child.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            guard let info = try? metadata.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey]),
                  info.isSymbolicLink != true, let size = info.fileSize, size < 1_048_576,
                  let data = try? Data(contentsOf: metadata),
                  let dictionary = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  dictionary["MCMMetadataIdentifier"] as? String == "com.apple.PosterBoard" else { continue }
            matches.append(child)
        }
        guard !matches.isEmpty else { throw AccessProbeError.notFound }
        guard matches.count == 1, let container = matches.first else { throw AccessProbeError.ambiguous }
        let store = container.appendingPathComponent("Library/Application Support/PRBPosterExtensionDataStore/61/Extensions/com.apple.WallpaperKit.CollectionsPoster/descriptors", isDirectory: true)
        guard let entries = try? fm.contentsOfDirectory(at: store,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) else {
            throw AccessProbeError.unavailableStore
        }
        let count = entries.filter {
            guard UUID(uuidString: $0.lastPathComponent) != nil,
                  let values = try? $0.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
            return values.isDirectory == true && values.isSymbolicLink != true
        }.count
        return AccessProbeReport(containerUUID: container.lastPathComponent,
            readableCollectionDescriptors: count, recordedAt: Date(), wallpaperInstallationVerified: false)
    }
}

