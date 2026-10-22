// SPDX-License-Identifier: GPL-3.0-only
import XCTest

/// Exercises the actual Foundation trash API on a disposable app-owned file.
/// Does not create a symlink or touch PosterBoard.
final class CoconutFileSupportTests: XCTestCase {
    func testDocumentsCanTrashAnAppOwnedFile() throws {
        let fm = FileManager.default
        let documents = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let trash = documents.appendingPathComponent(".Trash")
        guard (try? fm.destinationOfSymbolicLink(atPath: trash.path)) == nil else {
            throw XCTSkip("A preexisting symlink must not be used by this local test")
        }
        let source = documents.appendingPathComponent("coconut-file-support-test-\(UUID().uuidString).txt")
        let content = Data("Coconut local file support test".utf8)
        try content.write(to: source, options: .withoutOverwriting)
        defer { try? fm.removeItem(at: source) }
        var result: NSURL?
        try fm.trashItem(at: source, resultingItemURL: &result)
        XCTAssertFalse(fm.fileExists(atPath: source.path))
        let destination = try XCTUnwrap(result as URL?)
        // Clean up only the returned disposable file inside this app's Documents.
        guard destination.resolvingSymlinksInPath().path.hasPrefix(documents.resolvingSymlinksInPath().path + "/") else {
            XCTFail("Unexpected trash destination outside the app's Documents")
            return
        }
        defer { try? fm.removeItem(at: destination) }
        XCTAssertEqual(try Data(contentsOf: destination), content)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "UIFileSharingEnabled") as? Bool, true)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "LSSupportsOpeningDocumentsInPlace") as? Bool, true)
    }
}
