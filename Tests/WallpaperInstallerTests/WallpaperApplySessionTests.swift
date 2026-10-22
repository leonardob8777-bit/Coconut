// SPDX-License-Identifier: GPL-3.0-only
import XCTest
import WallpaperPackageManager
@testable import WallpaperInstaller

final class WallpaperApplySessionTests: XCTestCase {
    private let container = "42DEC0C3-E00A-5ABA-8061-29684C520E16"
    private var fixture: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("WallpaperPackageManagerTests/Fixtures/synthetic-descriptor.tendies")
    }
    private func digest() throws -> String {
        let staged = try PackageInspector().stage(fixture)
        defer { try? FileManager.default.removeItem(at: staged.directory) }
        return staged.inspection.sha256
    }
    private actor WriterSpy {
        var plans: [PosterBoardWritePlan] = []
        func write(_ plan: PosterBoardWritePlan, consent: WriteConsent, fail: Bool = false) throws -> WriteAttemptReceipt {
            XCTAssertTrue(consent.authorizes(plan))
            XCTAssertTrue(FileManager.default.fileExists(atPath: plan.sourceDirectory.path))
            plans.append(plan)
            if fail { throw InstallerError.stopped("Test write failure") }
            return WriteAttemptReceipt(planID: plan.id, packageSHA256: plan.packageSHA256,
                                       descriptorUUID: plan.descriptorUUID, provider: plan.provider,
                                       attemptedAt: Date(), descriptorVerified: true,
                                       posterBoardVerified: false)
        }
    }

    func testOneTapValidatesWritesOnceAndCleansStaging() async throws {
        let spy = WriterSpy()
        let session = WallpaperApplySession { try await spy.write($0, consent: $1) }
        let hash = try digest()
        let receipt = try await session.apply(archive: fixture, expectedSHA256: hash, containerUUID: container)
        XCTAssertFalse(receipt.posterBoardVerified)
        XCTAssertTrue(receipt.descriptorVerified)
        XCTAssertEqual(receipt.packageSHA256, hash)
        do {
            _ = try await session.apply(archive: fixture, expectedSHA256: hash, containerUUID: container)
            XCTFail("A repeated UI task must not write again")
        } catch {}
        let plans = await spy.plans
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].accessRoute, .pocketPoster)
        XCTAssertFalse(FileManager.default.fileExists(atPath: plans[0].sourceDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.path))
    }

    func testAlreadyCancelledApplyNeverReachesWriter() async throws {
        let spy = WriterSpy()
        let session = WallpaperApplySession { try await spy.write($0, consent: $1) }
        let archive = fixture
        let hash = try digest()
        let container = container
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await session.apply(archive: archive, expectedSHA256: hash, containerUUID: container)
        }
        do {
            _ = try await task.value
            XCTFail("Cancelled action must not write")
        } catch { XCTAssertTrue(error is CancellationError) }
        let plans = await spy.plans
        XCTAssertTrue(plans.isEmpty)
    }

    func testDigestMismatchNeverReachesWriter() async throws {
        let spy = WriterSpy()
        let session = WallpaperApplySession { try await spy.write($0, consent: $1) }
        do {
            _ = try await session.apply(archive: fixture, expectedSHA256: String(repeating: "0", count: 64), containerUUID: container)
            XCTFail("Invalid package must fail")
        } catch {}
        let plans = await spy.plans
        XCTAssertTrue(plans.isEmpty)
    }

    func testWriterFailureIsReportedWithoutRetryAndStagingIsRemoved() async throws {
        let spy = WriterSpy()
        let session = WallpaperApplySession { try await spy.write($0, consent: $1, fail: true) }
        let hash = try digest()
        do {
            _ = try await session.apply(archive: fixture, expectedSHA256: hash, containerUUID: container)
            XCTFail("Failure must reach the UI")
        } catch { XCTAssertEqual(error.localizedDescription, "Test write failure") }
        do {
            _ = try await session.apply(archive: fixture, expectedSHA256: hash, containerUUID: container)
            XCTFail("Failure must not trigger retry")
        } catch {}
        let plans = await spy.plans
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].accessRoute, .pocketPoster)
        XCTAssertFalse(FileManager.default.fileExists(atPath: plans[0].sourceDirectory.path))
    }
}
