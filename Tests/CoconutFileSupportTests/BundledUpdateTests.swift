// SPDX-License-Identifier: GPL-3.0-only
import XCTest
@testable import CoconutLab

final class BundledUpdateTests: XCTestCase {
    @MainActor
    func testKnownOldPackageUpdatesWithoutLosingLibraryIdentity() async throws {
        #if targetEnvironment(simulator)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let original = root.appendingPathComponent("build/layout-fix/original-packages/globos.tendies")
        guard FileManager.default.fileExists(atPath: original.path) else { throw XCTSkip("Original revision required for upgrade regression") }
        let savedIndex = try? Data(contentsOf: PackageStorage.indexURL)
        defer {
            if let savedIndex { try? savedIndex.write(to: PackageStorage.indexURL, options: .atomic) }
            else { try? FileManager.default.removeItem(at: PackageStorage.indexURL) }
        }
        let library = PackageLibrary()
        let oldSHA = "4c037606fbdf9caf0574c4c31662b1e190de6114adae8dc441961885bc87efe7"
        let id = await library.importPackage(at: original, expectedSHA256: oldSHA, title: "Globos")
        XCTAssertNotNil(id)
        await library.updateBundledPackages()
        XCTAssertNil(library.lastError)
        XCTAssertNil(library.package(withSHA256: oldSHA))
        let updated = try XCTUnwrap(library.packages.first { $0.id == id })
        XCTAssertEqual(updated.title, "Globos")
        XCTAssertNotEqual(updated.inspection.sha256, oldSHA)
        XCTAssertTrue(FileManager.default.fileExists(atPath: updated.archiveURL.path))
        let reloaded = PackageLibrary()
        XCTAssertEqual(reloaded.packages.first { $0.id == id }?.inspection.sha256, updated.inspection.sha256)
        #else
        throw XCTSkip("This regression uses a local archived package on the simulator")
        #endif
    }
}
