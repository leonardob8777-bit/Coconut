// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import XCTest
@testable import WallpaperInstaller

final class DescriptorFingerprintTests: XCTestCase {
    func testCopyMustMatchEveryDescriptorFile() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("CoconutFingerprint-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        let copy = root.appendingPathComponent("copy")
        try fm.createDirectory(at: source.appendingPathComponent("versions/1"), withIntermediateDirectories: true)
        for (name, value) in [
            ("com.apple.posterkit.provider.descriptor.identifier", "12345"),
            ("com.apple.posterkit.role.identifier", "PRPosterRoleLockScreen"),
            ("providerInfo.plist", String(repeating: "p", count: 80)),
            ("versions/1/content", String(repeating: "a", count: 80))
        ] {
            try Data(value.utf8).write(to: source.appendingPathComponent(name))
        }
        let expected = try DescriptorFingerprint.capture(at: source)
        try fm.copyItem(at: source, to: copy)
        XCTAssertEqual(try DescriptorFingerprint.capture(at: copy), expected)
        try Data(String(repeating: "b", count: 80).utf8)
            .write(to: copy.appendingPathComponent("versions/1/content"))
        XCTAssertNotEqual(try DescriptorFingerprint.capture(at: copy), expected)
    }
}
