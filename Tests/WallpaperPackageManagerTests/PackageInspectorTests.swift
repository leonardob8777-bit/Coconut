// SPDX-License-Identifier: GPL-3.0-only
import XCTest
@testable import WallpaperPackageManager

final class PackageInspectorTests: XCTestCase {
    private func fixture(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: "tendies", subdirectory: "Fixtures")!
    }

    func testSyntheticDescriptorInspectsWithoutClaimingInstallation() throws {
        let staged = try PackageInspector().stage(fixture("synthetic-descriptor"))
        defer { try? FileManager.default.removeItem(at: staged.directory) }
        XCTAssertEqual(staged.inspection.descriptors.count, 1)
        XCTAssertEqual(staged.inspection.descriptors[0].provider, "com.apple.WallpaperKit.CollectionsPoster")
        XCTAssertFalse(staged.inspection.installationVerified)
        XCTAssertEqual(staged.inspection.sha256.count, 64)
        XCTAssertTrue(FileManager.default.fileExists(atPath: staged.directory.appendingPathComponent("payload/descriptor/TEST-ONLY/versions/1/contents/TEST-ONLY.txt").path))
    }

    func testVideoProvider() throws {
        let staged = try PackageInspector().stage(fixture("synthetic-video"))
        defer { try? FileManager.default.removeItem(at: staged.directory) }
        XCTAssertEqual(staged.inspection.descriptors[0].provider, "com.apple.PhotosUIPrivate.PhotosPosterProvider")
    }

    func testUnsafeOrUnsupportedArchivesAreRejectedAndStagingCleaned() throws {
        let fm = FileManager.default
        let before = Set(try fm.contentsOfDirectory(atPath: fm.temporaryDirectory.path).filter { $0.hasPrefix("WallpaperLab-") })
        for name in ["traversal", "absolute", "backslash", "case-collision", "file-parent", "container",
                     "incomplete", "multiple", "empty", "symlink", "bad-crc", "not-zip"] {
            XCTAssertThrowsError(try PackageInspector().stage(fixture(name)), name)
        }
        let after = Set(try fm.contentsOfDirectory(atPath: fm.temporaryDirectory.path).filter { $0.hasPrefix("WallpaperLab-") })
        XCTAssertEqual(before, after)
    }

    func testDigestMustMatchAndSourceRemainsUnchanged() throws {
        let source = fixture("synthetic-descriptor")
        let original = try Data(contentsOf: source)
        let staged = try PackageInspector().stage(source)
        defer { try? FileManager.default.removeItem(at: staged.directory) }
        let verified = try PackageInspector().stage(source, expectedSHA256: staged.inspection.sha256)
        defer { try? FileManager.default.removeItem(at: verified.directory) }
        XCTAssertThrowsError(try PackageInspector().stage(source, expectedSHA256: String(repeating: "0", count: 64)))
        XCTAssertThrowsError(try PackageInspector().stage(source, expectedSHA256: "invalid"))
        XCTAssertEqual(original, try Data(contentsOf: source))
    }

    func testEntryCountAndSizeBudgets() throws {
        var limits = InspectionLimits()
        limits.entryCount = 1
        XCTAssertThrowsError(try PackageInspector(limits: limits).stage(fixture("synthetic-descriptor")))
        limits = InspectionLimits()
        limits.expandedBytes = 4
        XCTAssertThrowsError(try PackageInspector(limits: limits).stage(fixture("synthetic-descriptor")))
        limits = InspectionLimits()
        limits.entryBytes = 4
        XCTAssertThrowsError(try PackageInspector(limits: limits).stage(fixture("synthetic-descriptor")))
        limits = InspectionLimits()
        limits.archiveBytes = 10
        XCTAssertThrowsError(try PackageInspector(limits: limits).stage(fixture("synthetic-descriptor")))
    }
}
