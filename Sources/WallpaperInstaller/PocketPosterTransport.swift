// SPDX-License-Identifier: GPL-3.0-only
// Adapted from lemin's Pocket Poster, SymHandler.swift and PosterBoardManager.swift.
// Upstream: leminlimez/Pocket-Poster, fb07aa45586ea4d2590c6f6d258777b207e1b8c9.
// Coconut: isolate the Documents/.Trash lifecycle, support LC_HOME_PATH, preserve
// unrelated folders/links, and never delete target contents.
import Foundation

struct PocketPosterLocations: Sendable {
    let stagingDocuments: URL
    let trashDocuments: URL

    init(stagingDocuments: URL, liveContainerHome: String?, fileManager: FileManager = .default) throws {
        self.stagingDocuments = stagingDocuments
        if let home = liveContainerHome, !home.isEmpty {
            guard home.hasPrefix("/"), !home.split(separator: "/").contains("..") else {
                throw InstallerError.stopped("LC_HOME_PATH no identifica una carpeta válida de LiveContainer.")
            }
            let documents = URL(fileURLWithPath: home, isDirectory: true)
                .appendingPathComponent("Documents", isDirectory: true)
            guard try documents.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
                throw InstallerError.stopped("No se pudo acceder a Documents de LiveContainer.")
            }
            trashDocuments = documents
        } else {
            trashDocuments = stagingDocuments
        }
    }

    static func current(fileManager: FileManager = .default) throws -> Self {
        try Self(stagingDocuments: fileManager.url(for: .documentDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true),
                 liveContainerHome: ProcessInfo.processInfo.environment["LC_HOME_PATH"],
                 fileManager: fileManager)
    }

    var link: URL { trashDocuments.appendingPathComponent(".Trash", isDirectory: false) }
}

/// Mirrors upstream's create link → trash the app-owned staged descriptor →
/// unlink sequence. Existing local trash is preserved and restored; a stale
/// link to the same exact destination can be recovered.
struct PocketPosterTransport: Sendable {
    let locations: PocketPosterLocations

    func perform(stagedDescriptor: URL, destinationDirectory: String,
                 fileManager fm: FileManager = .default,
                 trash: (URL) throws -> Void) throws {
        let link = locations.link
        var backup: URL?
        if let existing = try? fm.destinationOfSymbolicLink(atPath: link.path), existing == destinationDirectory {
            // removeItem on the link itself unlinks it; it never traverses target.
            try fm.removeItem(at: link)
        } else if (try? fm.attributesOfItem(atPath: link.path)) != nil
                    || (try? fm.destinationOfSymbolicLink(atPath: link.path)) != nil {
            // Upstream removes .Trash before creating the link. Preserve existing
            // local contents instead, then restore them after this attempt.
            let preserved = locations.trashDocuments.appendingPathComponent(".CoconutTrashBackup-" + UUID().uuidString)
            try fm.moveItem(at: link, to: preserved)
            backup = preserved
        }
        // Cleanup is part of the operation: never report completion while our
        // temporary link remains installed or ordinary trash cannot be restored.
        func restore() throws {
            if (try? fm.destinationOfSymbolicLink(atPath: link.path)) == destinationDirectory {
                try fm.removeItem(at: link)
            }
            if let backup {
                guard (try? fm.attributesOfItem(atPath: link.path)) == nil,
                      (try? fm.destinationOfSymbolicLink(atPath: link.path)) == nil else {
                    throw InstallerError.stopped("No se pudo restaurar la carpeta temporal. Los archivos originales siguen conservados en Coconut.")
                }
                try fm.moveItem(at: backup, to: link)
            }
        }
        var operationError: Error?
        do {
            try fm.createSymbolicLink(at: link,
                                     withDestinationURL: URL(fileURLWithPath: destinationDirectory, isDirectory: true))
            try trash(stagedDescriptor)
        } catch { operationError = error }
        do { try restore() } catch {
            throw InstallerError.stopped("No se pudo restaurar la carpeta temporal. Los archivos originales siguen conservados en Coconut.")
        }
        if let operationError { throw operationError }
    }
}
