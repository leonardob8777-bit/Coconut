// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

public enum PosterBoardAccessRoute: String, Sendable {
    case direct = "direct-filesystem"
    case pocketPoster = "pocket-poster-trash"
    case darkSword = "darksword-sandbox"
}

public struct PreparedPosterBoardAccess: Sendable {
    public let containerUUID: String
    public let route: PosterBoardAccessRoute
    public init(containerUUID: String, route: PosterBoardAccessRoute) {
        self.containerUUID = containerUUID
        self.route = route
    }
}

public enum PosterBoardAccessError: Error, LocalizedError {
    case unsupportedDevice, debuggerAttached, exploitFailed(Int), notReadable

    public var errorDescription: String? {
        switch self {
        case .unsupportedDevice:
            "Este iPhone no tiene acceso directo y su versión no está habilitada para la ruta DarkSword integrada."
        case .debuggerAttached:
            "Desconecta Xcode y vuelve a activar el motor."
        case .exploitFailed(let code):
            "No se pudo preparar el acceso al iPhone (código \(code)). No se escribió ningún descriptor."
        case .notReadable:
            "El acceso se preparó, pero no se pudo leer el contenedor de PosterBoard."
        }
    }
}

/// Discovers the PosterBoard UUID locally. Uses an existing privileged route
/// (for example TrollStore) when available and otherwise the gated DarkSword
/// bridge. No UUID or computer connection is required.
public enum PosterBoardAccessCoordinator {
    /// Upstream range for the saved-UUID writer, independent of UUID discovery.
    public static func supportsSavedUUID(version: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion) -> Bool {
        version.majorVersion == 17
            || (version.majorVersion == 18 &&
                (version.minorVersion < 7 || (version.minorVersion == 7 && version.patchVersion < 5)))
            || (version.majorVersion == 26 && version.minorVersion < 2)
    }

    /// Confirms that the prepared container still identifies PosterBoard. No exploit runs here.
    public static func validate(_ access: PreparedPosterBoardAccess) async throws {
        #if os(iOS) && !targetEnvironment(simulator)
        try await Task.detached(priority: .userInitiated) {
            guard UUID(uuidString: access.containerUUID) != nil,
                  try PosterBoardContainerReader().findContainerUUID() == access.containerUUID else {
                throw PosterBoardAccessError.notReadable
            }
        }.value
        #else
        throw PosterBoardAccessError.unsupportedDevice
        #endif
    }

    public static func prepare() async throws -> PreparedPosterBoardAccess {
        #if os(iOS) && !targetEnvironment(simulator)
        if let uuid = try? PosterBoardContainerReader().findContainerUUID() {
            let destination = PosterBoardContainerReader().descriptorDirectory(containerUUID: uuid)
            let route: PosterBoardAccessRoute = FileManager.default.isWritableFile(atPath: destination.path)
                ? .direct : .pocketPoster
            return PreparedPosterBoardAccess(containerUUID: uuid, route: route)
        }
        let status = await Task.detached(priority: .userInitiated) {
            CoconutPrepareAccess()
        }.value
        switch status {
        case 0: break
        case 1: throw PosterBoardAccessError.unsupportedDevice
        case 2: throw PosterBoardAccessError.debuggerAttached
        default: throw PosterBoardAccessError.exploitFailed(Int(status))
        }
        guard let uuid = try? PosterBoardContainerReader().findContainerUUID() else {
            throw PosterBoardAccessError.notReadable
        }
        return PreparedPosterBoardAccess(containerUUID: uuid, route: .darkSword)
        #else
        throw PosterBoardAccessError.unsupportedDevice
        #endif
    }
}

private struct PosterBoardContainerReader {
    func descriptorDirectory(containerUUID: String) -> URL {
        URL(fileURLWithPath: "/private/var/mobile/Containers/Data/Application", isDirectory: true)
            .appendingPathComponent(containerUUID, isDirectory: true)
            .appendingPathComponent("Library/Application Support/PRBPosterExtensionDataStore/61/Extensions/com.apple.WallpaperKit.CollectionsPoster/descriptors", isDirectory: true)
    }

    func findContainerUUID() throws -> String {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: "/private/var/mobile/Containers/Data/Application", isDirectory: true)
        let children = try fm.contentsOfDirectory(at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
        let matches = children.compactMap { child -> String? in
            guard UUID(uuidString: child.lastPathComponent) != nil,
                  let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isDirectory == true, values.isSymbolicLink != true else { return nil }
            let metadata = child.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            guard let metaValues = try? metadata.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey]),
                  metaValues.isSymbolicLink != true, let size = metaValues.fileSize, size < 1_048_576,
                  let data = try? Data(contentsOf: metadata),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  plist["MCMMetadataIdentifier"] as? String == "com.apple.PosterBoard" else { return nil }
            return child.lastPathComponent.uppercased()
        }
        guard matches.count == 1, let match = matches.first else {
            throw PosterBoardAccessError.notReadable
        }
        return match
    }
}

#if os(iOS)
@_silgen_name("CoconutPrepareAccess")
private func CoconutPrepareAccess() -> Int32
#endif
