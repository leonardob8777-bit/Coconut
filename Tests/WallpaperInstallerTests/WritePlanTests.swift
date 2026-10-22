// SPDX-License-Identifier: GPL-3.0-only
import XCTest
import WallpaperInstaller

final class WritePlanTests: XCTestCase {
    func plan(container: String = "42DEC0C3-E00A-5ABA-8061-29684C520E16",
              provider: String = "com.apple.WallpaperKit.CollectionsPoster", digest: String = String(repeating: "a", count: 64)) throws -> PosterBoardWritePlan {
        try PosterBoardWritePlan(sourceDirectory: URL(fileURLWithPath: "/tmp/not-executed"),
                                 provider: provider, containerUUID: container, packageSHA256: digest)
    }

    func testInvalidDestinationAndDigestCannotProducePlan() throws {
        XCTAssertThrowsError(try plan(container: "../escape"))
        XCTAssertThrowsError(try plan(provider: "../../other"))
        XCTAssertThrowsError(try plan(digest: "wrong"))
        let prepared = try plan()
        XCTAssertTrue(prepared.destinationDirectory.hasSuffix("/61/Extensions/com.apple.WallpaperKit.CollectionsPoster/descriptors"))
        XCTAssertNotNil(UUID(uuidString: prepared.descriptorUUID))
    }

    func testApplyAuthorizationIsBoundToExactPlan() throws {
        let first = try plan(), second = try plan()
        let consent = WriteConsent(explicitlyAuthorized: true, planID: first.id)
        XCTAssertTrue(consent.authorizes(first))
        XCTAssertFalse(consent.authorizes(second))
        XCTAssertFalse(WriteConsent(explicitlyAuthorized: false, planID: first.id).authorizes(first))
    }

    func testWriterCannotOperateOnMacOrSimulator() async throws {
        let prepared = try plan()
        let writer = ExperimentalPosterBoardWriter()
        let consent = WriteConsent(explicitlyAuthorized: true, planID: prepared.id)
        do {
            _ = try await writer.attemptWrite(plan: prepared, consent: consent)
            XCTFail("The test environment must never write to PosterBoard")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("macOS ni simulador"))
        }
    }
}
