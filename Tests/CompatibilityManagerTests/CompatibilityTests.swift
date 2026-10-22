// SPDX-License-Identifier: GPL-3.0-only
import XCTest
import CompatibilityManager

final class CompatibilityTests: XCTestCase {
    func testPatchBoundariesAreNotAdvertisedAsWorking() {
        for version in ["18.7.5", "18.7.7", "18.10", "26.2", "26.2.1", "26.6"] {
            let assessment = CompatibilityManager.assess(version: IOSVersion(version)!, productType: "iPhone17,1")
            XCTAssertEqual(assessment.evidence, .patchedAccordingToUpstream, version)
            XCTAssertFalse(assessment.installationVerifiedByCoconut)
            XCTAssertFalse(assessment.matchesInitialExperimentalTarget)
        }
        for version in ["17", "17.7.1", "18.0", "18.6.2", "18.7.4", "26.0.1", "26.1"] {
            let assessment = CompatibilityManager.assess(version: IOSVersion(version)!, productType: "iPhone17,1")
            XCTAssertEqual(assessment.evidence, .announcedCandidate, version)
            XCTAssertFalse(assessment.installationVerifiedByCoconut)
        }
    }

    func testUnknownAndPreliminaryAreNotVerified() {
        XCTAssertEqual(CompatibilityManager.assess(version: IOSVersion("16.7")!, productType: "unknown").evidence, .preliminary)
        XCTAssertEqual(CompatibilityManager.assess(version: IOSVersion("15.8")!, productType: "unknown").evidence, .outsidePublishedScope)
        XCTAssertEqual(CompatibilityManager.assess(version: IOSVersion("27")!, productType: "unknown").evidence, .outsidePublishedScope)
        XCTAssertEqual(CompatibilityManager.assess(version: IOSVersion("19")!, productType: "unknown").evidence, .unknownReleaseFamily)
    }

    func testInitialTargetIsSeparateFromUpstreamRange() {
        let version = IOSVersion("18.6.2")!
        XCTAssertTrue(CompatibilityManager.assess(version: version, productType: "iPhone17,1").matchesInitialExperimentalTarget)
        XCTAssertFalse(CompatibilityManager.assess(version: version, productType: "iPhone17,1", isSimulator: true).matchesInitialExperimentalTarget)
        XCTAssertFalse(CompatibilityManager.assess(version: version, productType: "iPhone17,2").matchesInitialExperimentalTarget)
    }

    func testVersionParsingIsNumericAndRejectsAmbiguousInput() {
        XCTAssertGreaterThan(IOSVersion("18.10")!, IOSVersion("18.7.5")!)
        XCTAssertEqual(IOSVersion("26.1"), IOSVersion("26.1.0"))
        for invalid in ["", "18..6", "18.6 beta 1", "18.6.2.1", "-18.6", " 18.6.2", "１８.６"] {
            XCTAssertNil(IOSVersion(invalid), invalid)
        }
    }
}
