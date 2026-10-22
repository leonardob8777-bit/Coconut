// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import WallpaperPackageManager

/// One user tap: validate, stage, write once, then release the temporary files.
/// Opening PosterBoard is handled by the UI only after this operation returns.
public actor WallpaperApplySession {
    typealias Write = @Sendable (PosterBoardWritePlan, WriteConsent) async throws -> WriteAttemptReceipt
    private let write: Write
    private var started = false

    public init() {
        let writer = ExperimentalPosterBoardWriter.shared
        write = { plan, consent in try await writer.attemptWrite(plan: plan, consent: consent) }
    }

    // Internal injection for tests; production never replaces the physical writer.
    init(write: @escaping Write) { self.write = write }

    public func apply(archive: URL, expectedSHA256: String, containerUUID: String,
                      accessRoute: PosterBoardAccessRoute = .pocketPoster) async throws -> WriteAttemptReceipt {
        guard !started else { throw InstallerError.stopped("Esta acción Aplicar ya fue procesada.") }
        started = true
        try Task.checkCancellation()
        let staged = try PackageInspector().stage(archive, expectedSHA256: expectedSHA256)
        defer { try? FileManager.default.removeItem(at: staged.directory) }
        try Task.checkCancellation()
        guard staged.inspection.descriptors.count == 1, let descriptor = staged.inspection.descriptors.first else {
            throw InstallerError.stopped("Se necesita un único descriptor.")
        }
        let plan = try PosterBoardWritePlan(
            sourceDirectory: staged.directory.appendingPathComponent("payload").appendingPathComponent(descriptor.relativePath),
            provider: descriptor.provider, containerUUID: containerUUID, packageSHA256: staged.inspection.sha256,
            accessRoute: accessRoute)
        return try await write(plan, WriteConsent(explicitlyAuthorized: true, planID: plan.id))
    }
}
