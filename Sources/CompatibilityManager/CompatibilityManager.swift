// SPDX-License-Identifier: GPL-3.0-only
// Original compatibility policy based on published upstream evidence, not a
// statement that Coconut has been tested on any physical iOS version.
public struct IOSVersion: Comparable, Codable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    /// Release versions only. Betas/build strings need a separate evidence record.
    public init?(_ string: String) {
        let components = string.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(components.count), components.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }) else { return nil }
        let values = components.compactMap { Int($0) }
        guard values.count == components.count else { return nil }
        self.major = values[0]
        self.minor = values.count > 1 ? values[1] : 0
        self.patch = values.count > 2 ? values[2] : 0
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

public enum SupportEvidence: String, Codable, Sendable {
    case announcedCandidate
    case preliminary
    case patchedAccordingToUpstream
    case outsidePublishedScope
    case unknownReleaseFamily
}

public struct CompatibilityAssessment: Codable, Sendable {
    public let evidence: SupportEvidence
    public let installationVerifiedByCoconut: Bool
    /// Scope only. Still requires a valid package, live device, UUID, backup,
    /// exact write plan and explicit consent. Never grants permission to write.
    public let matchesInitialExperimentalTarget: Bool
    public let sourceURLs: [String]
}

public enum CompatibilityManager {
    public static func assess(version: IOSVersion, productType: String, isSimulator: Bool = false) -> CompatibilityAssessment {
        let evidence: SupportEvidence
        switch version.major {
        case ...15: evidence = .outsidePublishedScope
        case 16: evidence = .preliminary
        case 17: evidence = .announcedCandidate
        case 18: evidence = version >= IOSVersion("18.7.5")! ? .patchedAccordingToUpstream : .announcedCandidate
        case 26: evidence = version >= IOSVersion("26.2")! ? .patchedAccordingToUpstream : .announcedCandidate
        case 27...: evidence = .outsidePublishedScope
        default: evidence = .unknownReleaseFamily
        }
        return CompatibilityAssessment(
            evidence: evidence,
            installationVerifiedByCoconut: false,
            matchesInitialExperimentalTarget: !isSimulator && productType == "iPhone17,1" && version == IOSVersion("18.6.2")!,
            sourceURLs: [
                "https://github.com/leminlimez/Pocket-Poster",
                "https://github.com/leminlimez/Pocket-Poster/releases/tag/v3.0",
                "https://github.com/leminlimez/Pocket-Poster/issues/68"
            ]
        )
    }
}
