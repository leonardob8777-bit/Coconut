// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import XCTest
@testable import WallpaperInstaller

final class PocketPosterTransportTests: XCTestCase {
    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    func testLiveContainerUsesHostTrashAndGuestStaging() throws {
        let root = try fixture(), guest = root.appendingPathComponent("Guest/Documents")
        let host = root.appendingPathComponent("Host"), hostDocuments = host.appendingPathComponent("Documents")
        try FileManager.default.createDirectory(at: guest, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: hostDocuments, withIntermediateDirectories: true)
        let locations = try PocketPosterLocations(stagingDocuments: guest, liveContainerHome: host.path)
        XCTAssertEqual(locations.stagingDocuments, guest)
        XCTAssertEqual(locations.trashDocuments.path, hostDocuments.path)
        let source = guest.appendingPathComponent("descriptor")
        try Data("descriptor bytes".utf8).write(to: source)
        let target = root.appendingPathComponent("Target")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        try PocketPosterTransport(locations: locations).perform(stagedDescriptor: source, destinationDirectory: target.path) { staged in
            XCTAssertEqual(staged, source)
            XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: locations.link.path), target.path)
            XCTAssertFalse(FileManager.default.fileExists(atPath: guest.appendingPathComponent(".Trash").path))
            try FileManager.default.moveItem(at: staged, to: target.appendingPathComponent(staged.lastPathComponent))
        }
        XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("descriptor")), Data("descriptor bytes".utf8))
        XCTAssertThrowsError(try FileManager.default.destinationOfSymbolicLink(atPath: locations.link.path))
    }
    func testRecoversOnlyStaleLinkToSameDestinationAndCleansAfterFailure() throws {
        let root = try fixture()
        let locations = try PocketPosterLocations(stagingDocuments: root, liveContainerHome: nil)
        let target = root.appendingPathComponent("Target")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        let sentinel = target.appendingPathComponent("existing-wallpaper")
        try Data("keep".utf8).write(to: sentinel)
        try FileManager.default.createSymbolicLink(at: locations.link, withDestinationURL: target)
        XCTAssertThrowsError(try PocketPosterTransport(locations: locations).perform(
            stagedDescriptor: root.appendingPathComponent("unused"), destinationDirectory: target.path
        ) { _ in throw CocoaError(.fileWriteUnknown) })
        XCTAssertThrowsError(try FileManager.default.destinationOfSymbolicLink(atPath: locations.link.path))
        XCTAssertEqual(try Data(contentsOf: sentinel), Data("keep".utf8))
    }
    func testPreservesAndRestoresExistingTrashDirectoryAndUnrelatedLink() throws {
        let root = try fixture()
        let locations = try PocketPosterLocations(stagingDocuments: root, liveContainerHome: nil)
        let transport = PocketPosterTransport(locations: locations)
        try FileManager.default.createSymbolicLink(atPath: locations.link.path, withDestinationPath: "/unrelated")
        try transport.perform(stagedDescriptor: root, destinationDirectory: "/target") { _ in
            XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: locations.link.path), "/target")
        }
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: locations.link.path), "/unrelated")
        try FileManager.default.removeItem(at: locations.link)
        try FileManager.default.createDirectory(at: locations.link, withIntermediateDirectories: false)
        let sentinel = locations.link.appendingPathComponent("preserved-file")
        try Data("preserve ordinary trash".utf8).write(to: sentinel)
        XCTAssertThrowsError(try transport.perform(stagedDescriptor: root, destinationDirectory: "/target") { _ in
            throw CocoaError(.fileWriteUnknown)
        })
        XCTAssertEqual(try Data(contentsOf: sentinel), Data("preserve ordinary trash".utf8))
        let files = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertFalse(files.contains { $0.hasPrefix(".CoconutTrashBackup-") })
    }
    func testCleanupConflictIsReportedAndPreservedFilesRemainIntact() throws {
        let root = try fixture()
        let locations = try PocketPosterLocations(stagingDocuments: root, liveContainerHome: nil)
        try FileManager.default.createDirectory(at: locations.link, withIntermediateDirectories: false)
        try Data("keep".utf8).write(to: locations.link.appendingPathComponent("original"))
        XCTAssertThrowsError(try PocketPosterTransport(locations: locations).perform(
            stagedDescriptor: root, destinationDirectory: "/target"
        ) { _ in
            try FileManager.default.removeItem(at: locations.link)
            try FileManager.default.createDirectory(at: locations.link, withIntermediateDirectories: false)
        })
        let backup = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent.hasPrefix(".CoconutTrashBackup-") })
        XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent("original")), Data("keep".utf8))
    }

    func testRejectsInvalidLiveContainerHomeRatherThanUsingWrongTrash() throws {
        let root = try fixture()
        for home in ["relative", "/tmp/../wrong", root.appendingPathComponent("Missing").path] {
            XCTAssertThrowsError(try PocketPosterLocations(stagingDocuments: root, liveContainerHome: home))
        }
    }
}
