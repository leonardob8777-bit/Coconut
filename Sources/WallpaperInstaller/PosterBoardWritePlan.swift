// SPDX-License-Identifier: GPL-3.0-only
import Foundation

/// Immutable operation prepared for the selected wallpaper. Does not write files.
public struct PosterBoardWritePlan: Sendable {
    public let id: UUID
    public let descriptorUUID: String
    public let containerUUID: String
    public let provider: String
    public let packageSHA256: String
    public let sourceDirectory: URL
    public let accessRoute: PosterBoardAccessRoute
    public let datastoreVersion: String

    public var destinationDirectory: String {
        "/var/mobile/Containers/Data/Application/\(containerUUID)/Library/Application Support/PRBPosterExtensionDataStore/\(datastoreVersion)/Extensions/\(provider)/descriptors"
    }

    public init(sourceDirectory: URL, provider: String, containerUUID: String, packageSHA256: String,
                accessRoute: PosterBoardAccessRoute = .pocketPoster, osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) throws {
        guard sourceDirectory.isFileURL,
              let container = UUID(uuidString: containerUUID),
              ["com.apple.WallpaperKit.CollectionsPoster", "com.apple.PhotosUIPrivate.PhotosPosterProvider"].contains(provider),
              packageSHA256.count == 64, packageSHA256.allSatisfy({ $0.isASCII && $0.isHexDigit }) else {
            throw InstallerError.stopped("No se pudo preparar el plan: UUID, proveedor, archivo o SHA-256 inválido.")
        }
        id = UUID()
        descriptorUUID = UUID().uuidString
        self.containerUUID = container.uuidString
        self.provider = provider
        self.packageSHA256 = packageSHA256.lowercased()
        self.sourceDirectory = sourceDirectory
        self.accessRoute = accessRoute
        self.datastoreVersion = osMajorVersion <= 16 ? "59" : "61"
    }
}
