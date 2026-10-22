// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import XCTest
@testable import WallpaperInstaller

final class SavedUUIDCompatibilityTests: XCTestCase {
    func testSavedUUIDRangeIsIndependentOfDiscoveryDevice() {
        for (major, minor, patch, supported) in [
            (16, 7, 0, false), (17, 0, 0, true), (17, 7, 0, true),
            (18, 6, 2, true), (18, 7, 4, true), (18, 7, 5, false),
            (18, 8, 0, false), (19, 0, 0, false), (26, 0, 0, true),
            (26, 1, 1, true), (26, 2, 0, false), (27, 0, 0, false)
        ] {
            XCTAssertEqual(PosterBoardAccessCoordinator.supportsSavedUUID(version: .init(
                majorVersion: major, minorVersion: minor, patchVersion: patch)), supported,
                "Version \(major).\(minor).\(patch)")
        }
    }
}
