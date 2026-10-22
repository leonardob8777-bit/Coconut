// SPDX-License-Identifier: GPL-3.0-only
// Derived from Pocket Poster, created by lemin (2025).
// Upstream: leminlimez/Pocket-Poster, fb07aa45586ea4d2590c6f6d258777b207e1b8c9
// SymHandler.swift:38-65; PosterBoardManager.swift:127-182, 215-235.
// Modified 2026-10-20 for Coconut: validate UUID/provider/device; preserve unrelated .Trash;
// direct-write only when the device grants filesystem access; stage copies; require explicit
// consent from the Apply action; return an attempt receipt, never claim success
// in PosterBoard. No reset, bulk cleanup, UIKit, network or kernel exploit.
// GPL-3.0 text is supplied at repository root in LICENSE.
import Foundation

public struct WriteConsent: Sendable {
    public let explicitlyAuthorized: Bool
    public let planID: UUID
    public init(explicitlyAuthorized: Bool, planID: UUID) {
        self.explicitlyAuthorized = explicitlyAuthorized
        self.planID = planID
    }

    public func authorizes(_ plan: PosterBoardWritePlan) -> Bool {
        explicitlyAuthorized && planID == plan.id
    }
}

public struct WriteAttemptReceipt: Codable, Sendable {
    public let planID: UUID
    public let packageSHA256: String
    public let descriptorUUID: String
    public let provider: String
    public let attemptedAt: Date
    /// True only when the destination descriptor matches the staged bytes.
    public let descriptorVerified: Bool
    public let posterBoardVerified: Bool
}

public enum InstallerError: Error, LocalizedError {
    case stopped(String)
    public var errorDescription: String? {
        switch self { case .stopped(let message): return message }
    }
}

/// EXPERIMENTAL, UNVALIDATED ON HARDWARE. Called only after the exact plan is
/// created for a user-initiated Apply action. No backup declaration is required.
/// This writes outside the app sandbox through the upstream trash mechanism.
/// A successful return means only that trashItem returned without error.
/// No automatic rollback is possible with this write-only mechanism.
public actor ExperimentalPosterBoardWriter {
    private var attemptedPlans: Set<UUID> = []
    public init() {}
    public static let shared = ExperimentalPosterBoardWriter()

    public func attemptWrite(plan: PosterBoardWritePlan, consent: WriteConsent) throws -> WriteAttemptReceipt {
        try Task.checkCancellation()
        guard consent.authorizes(plan) else {
            throw InstallerError.stopped("Se requiere una acción Aplicar autorizada para este plan exacto.")
        }
        #if os(iOS) && !targetEnvironment(simulator)
        let descriptorDirectory = plan.sourceDirectory
        let provider = plan.provider
        let posterBoardContainerUUID = plan.containerUUID
        if plan.accessRoute != .direct && !PosterBoardAccessCoordinator.supportsSavedUUID() {
            throw InstallerError.stopped("Esta versión de iOS está fuera del rango de Pocket Poster para la ruta .Trash.")
        }
        guard UUID(uuidString: posterBoardContainerUUID) != nil,
              ["com.apple.WallpaperKit.CollectionsPoster", "com.apple.PhotosUIPrivate.PhotosPosterProvider"].contains(provider) else {
            throw InstallerError.stopped("UUID de contenedor o proveedor no permitido.")
        }
        let fm = FileManager.default
        let locations = try PocketPosterLocations.current(fileManager: fm)
        let documents = locations.stagingDocuments
        guard try descriptorDirectory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]).isDirectory == true,
              try descriptorDirectory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true,
              fm.fileExists(atPath: descriptorDirectory.appendingPathComponent("com.apple.posterkit.provider.descriptor.identifier").path),
              fm.fileExists(atPath: descriptorDirectory.appendingPathComponent("versions").path) else {
            throw InstallerError.stopped("Descriptor de staging no válido.")
        }
        guard let items = fm.enumerator(at: descriptorDirectory, includingPropertiesForKeys: [.isSymbolicLinkKey]) else {
            throw InstallerError.stopped("No se pudo inspeccionar el descriptor.")
        }
        for case let url as URL in items {
            if try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true {
                throw InstallerError.stopped("El descriptor contiene un enlace simbólico.")
            }
        }
        guard attemptedPlans.insert(plan.id).inserted else {
            throw InstallerError.stopped("Este plan ya fue intentado. Revisa PosterBoard antes de preparar otro intento.")
        }
        let descriptorUUID = plan.descriptorUUID
        let journal = documents.appendingPathComponent("CoconutWriteAttempts", isDirectory: true)
        try fm.createDirectory(at: journal, withIntermediateDirectories: true)
        let transaction = journal.appendingPathComponent(descriptorUUID, isDirectory: true)
        try fm.createDirectory(at: transaction, withIntermediateDirectories: false)
        // Upstream stages the descriptor directly under Documents so that trashItem
        // uses Documents/.Trash. Keep the journal separate from the moved item.
        let copy = documents.appendingPathComponent(descriptorUUID, isDirectory: true)
        try fm.copyItem(at: descriptorDirectory, to: copy)
        defer { try? fm.removeItem(at: copy) }
        try Self.randomizeWallpaperID(at: copy)
        let fingerprint = try DescriptorFingerprint.capture(at: copy)
        let target = plan.destinationDirectory
        let targetURL = URL(fileURLWithPath: target, isDirectory: true)
        let providerURL = targetURL.deletingLastPathComponent()
        let destination = targetURL.appendingPathComponent(descriptorUUID, isDirectory: true)
        // The saved-UUID route is write-only. It must not depend on a live
        // sandbox escape to enumerate or read another app's container.
        if plan.accessRoute != .pocketPoster {
            guard try providerURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]).isDirectory == true,
                  try providerURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
                throw InstallerError.stopped("La colección de PosterBoard no está preparada.")
            }
            if !fm.fileExists(atPath: targetURL.path) {
                try fm.createDirectory(at: targetURL, withIntermediateDirectories: false)
            }
            guard !fm.fileExists(atPath: destination.path) else {
                throw InstallerError.stopped("El descriptor ya existe en PosterBoard.")
            }
        }
        var verified = false
        defer {
            // A write-only attempt cannot establish ownership or safely roll back.
            if !verified && plan.accessRoute != .pocketPoster { try? fm.removeItem(at: destination) }
        }
        // Journal lives in this app, BEFORE the persistent operation. It is not a backup.
        let journalEntry: [String: String] = ["planID": plan.id.uuidString, "packageSHA256": plan.packageSHA256,
                                     "descriptorUUID": descriptorUUID, "provider": provider,
                                     "authorizationSource": "apply-button", "target": target,
                                     "status": "prepared-unverified",
                                     "trashLocation": locations.trashDocuments == locations.stagingDocuments
                                        ? "app-documents" : "livecontainer-host-documents"]
        try JSONSerialization.data(withJSONObject: journalEntry, options: [.prettyPrinted, .sortedKeys])
            .write(to: transaction.appendingPathComponent("attempt.json"), options: .atomic)
        if plan.accessRoute == .direct {
            try Self.installDirectly(copy, target: target, descriptorUUID: descriptorUUID, fileManager: fm)
            guard try DescriptorFingerprint.capture(at: destination) == fingerprint else {
                throw InstallerError.stopped("La copia en PosterBoard no coincide con el descriptor preparado.")
            }
            verified = true
            let receipt = WriteAttemptReceipt(planID: plan.id, packageSHA256: plan.packageSHA256,
                                              descriptorUUID: descriptorUUID, provider: provider,
                                              attemptedAt: Date(), descriptorVerified: true,
                                              posterBoardVerified: false)
            try JSONEncoder().encode(receipt).write(to: transaction.appendingPathComponent("receipt.json"), options: .atomic)
            return receipt
        }
        try PocketPosterTransport(locations: locations).perform(
            stagedDescriptor: copy, destinationDirectory: target, fileManager: fm
        ) { staged in
            var resultingURL: NSURL?
            try fm.trashItem(at: staged, resultingItemURL: &resultingURL)
            // iOS may report success for a move to the app's ordinary trash.
            // If it reports a destination, ensure it is the intended descriptor.
            if let resultingURL {
                let actual = (resultingURL as URL).resolvingSymlinksInPath().standardizedFileURL.path
                let expected = destination.resolvingSymlinksInPath().standardizedFileURL.path
                guard actual == expected else {
                    throw InstallerError.stopped("iOS movió el descriptor a otro destino. El tema no se confirmó en PosterBoard.")
                }
            }
        }
        if plan.accessRoute == .pocketPoster {
            // Verify when readable, but never invent verification when sandboxed.
            if let actual = try? DescriptorFingerprint.capture(at: destination) {
                guard actual == fingerprint else {
                    throw InstallerError.stopped("El descriptor importado no coincide con el paquete preparado.")
                }
                verified = true
            }
        } else {
            guard try DescriptorFingerprint.capture(at: destination) == fingerprint else {
                throw InstallerError.stopped("El descriptor importado no coincide con el paquete preparado.")
            }
            verified = true
        }
        let receipt = WriteAttemptReceipt(planID: plan.id, packageSHA256: plan.packageSHA256,
                                          descriptorUUID: descriptorUUID, provider: provider,
                                          attemptedAt: Date(), descriptorVerified: verified,
                                          posterBoardVerified: false)
        try JSONEncoder().encode(receipt).write(to: transaction.appendingPathComponent("receipt.json"), options: .atomic)
        return receipt
        #else
        throw InstallerError.stopped("La escritura experimental solo puede ejecutarse en el iPhone objetivo. No se ejecuta en macOS ni simulador.")
        #endif
    }

    #if os(iOS)
    private static func installDirectly(_ staged: URL, target: String, descriptorUUID: String,
                                        fileManager fm: FileManager) throws {
        let targetURL = URL(fileURLWithPath: target, isDirectory: true)
        let providerURL = targetURL.deletingLastPathComponent()
        guard try providerURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]).isDirectory == true,
              try providerURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true,
              fm.isWritableFile(atPath: providerURL.path) else {
            throw InstallerError.stopped("iOS no concede escritura directa en la colección de PosterBoard.")
        }
        if !fm.fileExists(atPath: targetURL.path) {
            try fm.createDirectory(at: targetURL, withIntermediateDirectories: false)
        }
        guard try targetURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]).isDirectory == true,
              try targetURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
            throw InstallerError.stopped("La carpeta de descriptores de PosterBoard no es segura.")
        }
        let destination = targetURL.appendingPathComponent(descriptorUUID, isDirectory: true)
        guard !fm.fileExists(atPath: destination.path) else {
            throw InstallerError.stopped("Este descriptor ya existe; se detuvo la copia.")
        }
        try fm.copyItem(at: staged, to: destination)
        let required = ["com.apple.posterkit.provider.descriptor.identifier",
                        "com.apple.posterkit.role.identifier", "providerInfo.plist", "versions"]
        guard required.allSatisfy({ fm.fileExists(atPath: destination.appendingPathComponent($0).path) }),
              try destination.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
            try? fm.removeItem(at: destination)
            throw InstallerError.stopped("La copia directa no pasó la validación de estructura y se retiró.")
        }
    }

    private static func randomizeWallpaperID(at url: URL) throws {
        let randomizedID = Int.random(in: 9999...99999)
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) else {
            throw InstallerError.stopped("No se pudo recorrer el descriptor.")
        }
        for case let file as URL in enumerator {
            guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            if file.lastPathComponent == "com.apple.posterkit.provider.descriptor.identifier" {
                try Data(String(randomizedID).utf8).write(to: file)
            } else {
                let key: String
                switch file.lastPathComponent {
                case "com.apple.posterkit.provider.contents.userInfo": key = "wallpaperRepresentingIdentifier"
                case "Wallpaper.plist": key = "identifier"
                default: continue
                }
                let data = try Data(contentsOf: file)
                var format = PropertyListSerialization.PropertyListFormat.xml
                guard var plist = try PropertyListSerialization.propertyList(from: data, format: &format) as? [String: Any] else {
                    throw InstallerError.stopped("Plist inválido: \(file.lastPathComponent)")
                }
                plist[key] = randomizedID
                try PropertyListSerialization.data(fromPropertyList: plist, format: format, options: 0).write(to: file)
            }
        }
    }
    #endif
}
