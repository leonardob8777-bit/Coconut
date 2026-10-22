// SPDX-License-Identifier: GPL-3.0-only
import XCTest
import AVFoundation
import WallpaperInstaller
import WallpaperPackageManager
import UniformTypeIdentifiers
#if canImport(CoconutDesignPreview)
@testable import CoconutDesignPreview
#else
@testable import CoconutLab
#endif

@MainActor final class ExperienceTests: XCTestCase {
    func testAppCatalogContainsThumbnailsButNoWallpaperArchivesOrVideos() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "catalog", withExtension: "json", subdirectory: "BundledCatalog"))
        let directory = url.deletingLastPathComponent()
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
        XCTAssertFalse(files.contains { ["tendies", "mp4"].contains($0.pathExtension) })
        let size = try files.reduce(0) { try $0 + ($1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
        XCTAssertLessThan(size, 15_000_000)
        let themes = try JSONDecoder().decode([String: [CatalogTheme]].self, from: Data(contentsOf: url))["themes"] ?? []
        XCTAssertGreaterThanOrEqual(themes.count, 76, "The included collection must remain available as new themes are added")
        XCTAssertEqual(Set(themes.map(\.id)).count, themes.count)
        for theme in themes {
            let resolved = try theme.resolvingResources(relativeTo: directory)
            XCTAssertEqual(resolved.packageURL.scheme, "https")
            if let video = resolved.previewVideoURL { XCTAssertEqual(video.scheme, "https") }
            XCTAssertTrue(try XCTUnwrap(resolved.previewURL).isFileURL)
        }
    }

    func testLightweightCatalogResolvesLocalArtworkAndHTTPSDownloads() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data([1]).write(to: directory.appendingPathComponent("thumb.jpg"))
        let json = """
        {"id":"test","name":"Test","previewURL":"thumb.jpg","previewVideoURL":"https://example.com/video.mp4","packageURL":"https://example.com/theme.tendies","sha256":"test"}
        """
        let theme = try JSONDecoder().decode(CatalogTheme.self, from: Data(json.utf8))
        let resolved = try theme.resolvingResources(relativeTo: directory)
        XCTAssertTrue(try XCTUnwrap(resolved.previewURL).isFileURL)
        XCTAssertEqual(resolved.packageURL.scheme, "https")
        if let video = resolved.previewVideoURL { XCTAssertEqual(video.scheme, "https") }
        for invalid in ["http://example.com/theme.tendies", "https://user:password@example.com/theme.tendies", "../theme.tendies", "file:///tmp/theme.tendies"] {
            let bad = CatalogTheme(id: theme.id, name: theme.name, author: nil, previewURL: nil,
                                   previewVideoURL: nil, packageURL: try XCTUnwrap(URL(string: invalid)), sha256: theme.sha256)
            XCTAssertThrowsError(try bad.resolvingResources(relativeTo: directory))
        }
    }

    func testEnglishDefaultAndLanguagePersistence() throws {
        let name = "CoconutLanguageTests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let language = AppLanguageStore(defaults: defaults)
        XCTAssertEqual(language.language, .english)
        language.language = .spanish
        XCTAssertEqual(AppLanguageStore(defaults: defaults).language, .spanish)
        defaults.set("unsupported", forKey: "Coconut.language")
        XCTAssertEqual(AppLanguageStore(defaults: defaults).language, .english)
    }

    func testInvalidRemoteEntriesCannotReplaceWorkingBundledThemes() async throws {
        let catalog = CatalogStore { request in
            let data = Data("""
            {"themes":[
              {"id":"fr-focus","name":"Broken","packageURL":"https://example.com/new.tendies","sha256":"bad"},
              {"id":"remote-valid","name":"First","packageURL":"https://example.com/new.tendies","sha256":"\(String(repeating: "b", count: 64))"},
              {"id":"remote-valid","name":"Duplicate","packageURL":"https://example.com/new.tendies","sha256":"\(String(repeating: "b", count: 64))"},
              {"id":"bad-media","name":"Bad media","packageURL":"https://example.com/new.tendies","previewURL":"file:///missing","sha256":"\(String(repeating: "b", count: 64))"}
            ]}
            """.utf8)
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        await catalog.load()
        guard case .loaded(let themes) = catalog.state else { return XCTFail("Missing collection") }
        XCTAssertEqual(themes.filter { $0.id == "remote-valid" }.count, 1)
        XCTAssertEqual(themes.first?.name, "First")
        XCTAssertFalse(themes.contains { $0.id == "bad-media" })
        XCTAssertTrue(themes.contains { $0.id == "fr-focus" && $0.name != "Broken" })
    }

    func testNewVideoMetadataUpdatesWithoutChangingPackageHash() async throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "catalog", withExtension: "json", subdirectory: "BundledCatalog"))
        let seed = try JSONDecoder().decode([String: [CatalogTheme]].self, from: Data(contentsOf: url))["themes"]!.first!
        let hash = seed.sha256
        let id = seed.id
        let catalog = CatalogStore { request in
            let data = Data("""
            {"themes":[{"id":"\(id)","name":"Updated media","packageURL":"https://example.com/theme.tendies","sha256":"\(hash)","previewURL":"https://example.com/art.jpg","previewVideoURL":"https://example.com/original.mp4"}]}
            """.utf8)
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        await catalog.load()
        guard case .loaded(let themes) = catalog.state else { return XCTFail("Missing collection") }
        let theme = try XCTUnwrap(themes.first { $0.id == id })
        XCTAssertEqual(theme.motionURL?.absoluteString, "https://example.com/original.mp4")
        XCTAssertEqual(theme.previewURL?.isFileURL, true, "Offline thumbnail should remain available")
        XCTAssertEqual(theme.sha256, hash)
    }

    func testPublishedRevisionReplacesSeedWithoutDuplicatingWallpaper() async throws {
        let catalog = CatalogStore { request in
            let data = Data("""
            {"themes":[{"id":"fr-focus","name":"Focus updated","packageURL":"https://example.com/new.tendies","sha256":"\(String(repeating: "b", count: 64))"}]}
            """.utf8)
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        await catalog.load()
        guard case .loaded(let themes) = catalog.state else { return XCTFail("Catalog did not load") }
        let revisions = themes.filter { $0.id == "fr-focus" }
        XCTAssertEqual(revisions.count, 1)
        XCTAssertEqual(revisions.first?.name, "Focus updated")
        XCTAssertEqual(revisions.first?.packageURL.absoluteString, "https://example.com/new.tendies")
        XCTAssertNil(revisions.first?.artworkURL, "A new revision must not reuse stale bundled artwork")
    }

    func testCatalogRetainsRemoteThemesOnFailedRefreshAndRecovers() async throws {
        let probe = CatalogRefreshProbe()
        let catalog = CatalogStore(fetch: { try await probe.fetch($0) })
        await catalog.load()
        XCTAssertEqual(catalog.updateState, .current)
        let updated = try XCTUnwrap(catalog.lastUpdatedAt)
        for failure in [CatalogRefreshProbe.Mode.networkFailure, .serverFailure, .malformed, .cancelled] {
            await probe.set(failure)
            let previous = catalog.updateState
            await catalog.load()
            guard case .loaded(let themes) = catalog.state else { return XCTFail("A failed refresh must keep the collection") }
            XCTAssertTrue(themes.contains { $0.id == "remote-test" })
            XCTAssertTrue(themes.contains { $0.id == "fr-focus" })
            XCTAssertEqual(catalog.lastUpdatedAt, updated)
            XCTAssertEqual(catalog.updateState, failure == .cancelled ? previous : .unavailable)
        }
        await probe.set(.success)
        await catalog.load()
        XCTAssertEqual(catalog.updateState, .current)
        guard case .loaded(let themes) = catalog.state else { return XCTFail("Recovered collection is missing") }
        XCTAssertEqual(themes.filter { $0.id == "remote-test" }.count, 1)
    }

    func testPublishedCatalogOrderPutsNewestThemesFirst() async throws {
        let catalog = CatalogStore(fetch: { try await CatalogRefreshProbe().fetch($0) })
        await catalog.load()
        guard case .loaded(let themes) = catalog.state else { return XCTFail("Collection is missing") }
        XCTAssertEqual(themes.first?.id, "remote-test", "The published catalog order (newest first) must lead")
        XCTAssertTrue(themes.contains { $0.id == "fr-focus" }, "Themes only bundled with the app stay available")
    }

    func testCatalogRefreshIsSingleFlightAndKeepsThemesWhileChecking() async throws {
        let probe = CatalogRefreshProbe()
        let catalog = CatalogStore(fetch: { try await probe.fetch($0) })
        await catalog.load()
        await probe.set(.delayed)
        let task = Task { await catalog.load() }
        while catalog.updateState != .checking { await Task.yield() }
        await catalog.load()
        XCTAssertEqual(catalog.updateState, .checking)
        guard case .loaded(let themes) = catalog.state else { task.cancel(); return XCTFail("Refreshing must not empty the gallery") }
        XCTAssertTrue(themes.contains { $0.id == "remote-test" })
        task.cancel()
        await task.value
        XCTAssertEqual(catalog.updateState, .current)
        let calls = await probe.calls
        XCTAssertEqual(calls, 2)
    }

    func testFirstOfflineLoadKeepsIncludedCollection() async {
        let catalog = CatalogStore(fetch: { _ in throw URLError(.notConnectedToInternet) })
        await catalog.load()
        XCTAssertEqual(catalog.updateState, .unavailable)
        XCTAssertNil(catalog.lastUpdatedAt)
        guard case .loaded(let themes) = catalog.state else { return XCTFail("Included wallpapers must work offline") }
        XCTAssertTrue(themes.contains { $0.id == "fr-focus" })
    }

    func testRuntimeMessagesAndTitlesFollowLanguage() {
        let old = AppLanguageStore.shared.language
        defer { AppLanguageStore.shared.language = old }
        AppLanguageStore.shared.language = .english
        XCTAssertEqual(L.text("Polillas"), "Moths")
        XCTAssertEqual(L.message("CRC o tamaño incorrecto: layer.png"), "Incorrect CRC or size: layer.png")
        XCTAssertEqual(L.format("%@ temas", "27"), "27 wallpapers")
        AppLanguageStore.shared.language = .spanish
        XCTAssertEqual(L.message("Could not download Moths."), "No se pudo descargar Moths.")
        XCTAssertEqual(L.text("Polillas"), "Polillas")
    }

    func testImportedExternalArchiveKeepsStableIdentityWithoutInventingCatalogMetadata() async throws {
        let index = try? Data(contentsOf: PackageStorage.indexURL)
        defer {
            if let index { try? index.write(to: PackageStorage.indexURL, options: .atomic) }
            else { try? FileManager.default.removeItem(at: PackageStorage.indexURL) }
        }
        let source = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "polillas", withExtension: "tendies"))
        let library = PackageLibrary()
        let first = await library.importPackage(at: source)
        let id = try XCTUnwrap(first)
        let imported = try XCTUnwrap(library.packages.first { $0.id == id })
        XCTAssertNil(imported.title, "This fixture is no longer included in the bundled catalog")
        XCTAssertNil(imported.previewURL, "An external import must not borrow another theme's artwork")
        XCTAssertEqual(imported.displayName, "polillas")
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported.archiveURL.path))
        var external = imported
        external.title = "Cabaña del campo"
        XCTAssertTrue(ThemeSearch.matches(external, query: "  campo\n CABANA  "))
        XCTAssertTrue(ThemeSearch.matches(external, query: "polillas.tendies"))
        XCTAssertTrue(ThemeSearch.matches(external, query: "   "))
        XCTAssertFalse(ThemeSearch.matches(external, query: "campo luna"))
        let duplicate = await library.importPackage(at: source)
        XCTAssertEqual(duplicate, id)
        XCTAssertEqual(library.packages.filter { $0.inspection.sha256 == imported.inspection.sha256 }.count, 1)
    }

    func testRealFoundationTrashWorksInAppDocuments() throws {
        let fm = FileManager.default
        let documents = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let trash = documents.appendingPathComponent(".Trash")
        guard (try? fm.destinationOfSymbolicLink(atPath: trash.path)) == nil else {
            throw XCTSkip("Do not use a preexisting symlink in a local test")
        }
        let source = documents.appendingPathComponent("coconut-trash-check-" + UUID().uuidString + ".txt")
        let bytes = Data("Coconut local Foundation check".utf8)
        try bytes.write(to: source, options: .withoutOverwriting)
        defer { try? fm.removeItem(at: source) }
        var result: NSURL?
        try fm.trashItem(at: source, resultingItemURL: &result)
        let destination = try XCTUnwrap(result as URL?)
        guard destination.resolvingSymlinksInPath().path.hasPrefix(documents.resolvingSymlinksInPath().path + "/") else {
            XCTFail("Unexpected destination outside app Documents")
            return
        }
        defer { try? fm.removeItem(at: destination) }
        XCTAssertFalse(fm.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: destination), bytes)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "UIFileSharingEnabled") as? Bool, true)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "LSSupportsOpeningDocumentsInPlace") as? Bool, true)
    }

    func testWallpaperDocumentRegistration() throws {
        let types = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleDocumentTypes") as? [[String: Any]])
        XCTAssertEqual(types.first?["LSItemContentTypes"] as? [String], ["dev.leonardobaptiste.coconut.tendies"])
        let type = try XCTUnwrap(UTType(filenameExtension: "tendies"))
        XCTAssertTrue(type.conforms(to: .zip))
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDevelopmentRegion") as? String, "en")
    }

    private func uuidDefaults() -> UserDefaults {
        let name = "CoconutUUIDTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        return defaults
    }

    private func uuidEngine(_ probe: AccessProbe, defaults: UserDefaults? = nil,
                            supported: Bool = true, discovery: Bool = true) -> EngineSession {
        EngineSession(isSimulator: false, defaults: defaults ?? uuidDefaults(),
                      installationSupported: supported, automaticDiscoverySupported: discovery,
                      prepare: { await probe.prepare() }, validate: { try await probe.validate($0) })
    }

    func testApplyCannotInitializeAccess() async {
        let probe = AccessProbe()
        let engine = uuidEngine(probe)
        do { _ = try await engine.validatedAccess(); XCTFail("Missing UUID must be rejected") } catch {}
        let preparations = await probe.preparations
        XCTAssertEqual(preparations, 0)
        XCTAssertFalse(engine.isReady)
    }

    func testDefaultDiscoveryAllowsEngineAttemptWithoutInitialDeviceTuple() async {
        let probe = AccessProbe()
        let engine = EngineSession(isSimulator: false, defaults: uuidDefaults(),
                                   installationSupported: true,
                                   prepare: { await probe.prepare() },
                                   validate: { try await probe.validate($0) })
        XCTAssertTrue(engine.canActivate)
        await engine.activate()
        XCTAssertTrue(engine.isReady)
        XCTAssertNotNil(engine.savedUUID)
        let preparations = await probe.preparations
        XCTAssertEqual(preparations, 1)
    }

    func testDiscoveryIsSingleFlightAndPersistsOnlyUUID() async throws {
        let probe = AccessProbe()
        let defaults = uuidDefaults()
        let engine = uuidEngine(probe, defaults: defaults)
        async let first: Void = engine.activate()
        async let second: Void = engine.activate()
        _ = await (first, second)
        XCTAssertTrue(engine.isReady)
        XCTAssertEqual(engine.access?.route, .pocketPoster)
        XCTAssertEqual(defaults.string(forKey: EngineSession.uuidKey), engine.savedUUID)
        await probe.loseAccess()
        _ = try await engine.validatedAccess()
        let restored = uuidEngine(probe, defaults: defaults)
        for _ in 0..<3 { _ = try await restored.validatedAccess() }
        XCTAssertTrue(restored.isReady, "UUID configuration must survive loss of privileged access and relaunch")
        let counts = await probe.counts
        XCTAssertEqual(counts.0, 1)
        XCTAssertEqual(counts.1, 1, "Only discovery requires reading the container")
    }

    func testFailedDiscoveryDoesNotPersistUUIDAndManualEntryStillWorks() async throws {
        let probe = AccessProbe()
        await probe.loseAccess()
        let engine = uuidEngine(probe)
        await engine.activate()
        XCTAssertEqual(engine.state, .failed)
        XCTAssertNil(engine.savedUUID)
        XCTAssertFalse(engine.canActivate)
        try engine.saveUUID("F63F4723-5928-41AF-9319-C8A9CBAA6D7F")
        XCTAssertTrue(engine.isReady)
        XCTAssertNil(engine.failure)
        _ = try await engine.validatedAccess()
        let count = await probe.preparations
        XCTAssertEqual(count, 1)
    }

    func testComputerUUIDWorksWithoutDiscoveryCompatibility() async throws {
        let probe = AccessProbe()
        let defaults = uuidDefaults()
        let engine = uuidEngine(probe, defaults: defaults, discovery: false)
        XCTAssertFalse(engine.canActivate)
        await engine.activate()
        try engine.saveUUID("  f63f4723-5928-41af-9319-c8a9cbaa6d7f\n")
        XCTAssertEqual(engine.savedUUID, "F63F4723-5928-41AF-9319-C8A9CBAA6D7F")
        let restored = uuidEngine(probe, defaults: defaults, discovery: false)
        XCTAssertTrue(restored.isReady)
        let access = try await restored.validatedAccess()
        XCTAssertEqual(access.route, .pocketPoster)
        let counts = await probe.counts
        XCTAssertEqual(counts.0, 0)
        XCTAssertEqual(counts.1, 0)
    }

    func testInvalidUUIDDoesNotReplaceSavedConfiguration() throws {
        let engine = uuidEngine(AccessProbe())
        let uuid = "F63F4723-5928-41AF-9319-C8A9CBAA6D7F"
        try engine.saveUUID(uuid)
        for invalid in ["", "not-a-uuid", "../../" + uuid, "00008140-000000000000001E", "/var/mobile/" + uuid] {
            XCTAssertThrowsError(try engine.saveUUID(invalid))
            XCTAssertEqual(engine.savedUUID, uuid)
        }
    }

    func testSavedUUIDDoesNotOverrideInstallationCompatibility() async throws {
        let probe = AccessProbe()
        let engine = uuidEngine(probe, supported: false)
        try engine.saveUUID("F63F4723-5928-41AF-9319-C8A9CBAA6D7F")
        XCTAssertNotNil(engine.savedUUID)
        XCTAssertFalse(engine.isReady)
        XCTAssertFalse(engine.canActivate)
        do { _ = try await engine.validatedAccess(); XCTFail("Patched versions must remain blocked") } catch {}
        let count = await probe.preparations
        XCTAssertEqual(count, 0)
    }

    func testReferenceDateFollowsSelectedLanguage() {
        let previous = AppLanguageStore.shared.language
        defer { AppLanguageStore.shared.language = previous }
        AppLanguageStore.shared.language = .english
        XCTAssertTrue(ReferenceClock.dateLabel.contains("October"))
        AppLanguageStore.shared.language = .spanish
        XCTAssertTrue(ReferenceClock.dateLabel.contains("octubre"))
    }

    func testFavoriteMigrationDatesAndPlaybackPreferencePersist() throws {
        let name = "CoconutFavoritesTests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(["polillas", "niebla"], forKey: "Coconut.favoriteThemes")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let preferences = GalleryPreferences(defaults: defaults, now: { date })
        XCTAssertEqual(preferences.favorites, ["polillas", "niebla"])
        XCTAssertNil(preferences.favoriteAddedAt("polillas"), "Migration must not invent timestamps")
        preferences.toggle("polillas")
        preferences.toggle("polillas")
        XCTAssertTrue(preferences.autoplayPreviews)
        preferences.autoplayPreviews = false
        let restored = GalleryPreferences(defaults: defaults)
        XCTAssertEqual(restored.favoriteAddedAt("polillas"), date)
        XCTAssertNil(restored.favoriteAddedAt("niebla"))
        XCTAssertFalse(restored.autoplayPreviews)
        restored.toggle("polillas")
        XCTAssertNil(GalleryPreferences(defaults: defaults).favoriteAddedAt("polillas"))
    }

    func testForgetUUIDPersistsAndNeverPreparesAccess() async throws {
        let probe = AccessProbe()
        let defaults = uuidDefaults()
        let engine = uuidEngine(probe, defaults: defaults)
        try engine.saveUUID("F63F4723-5928-41AF-9319-C8A9CBAA6D7F")
        engine.forgetUUID()
        XCTAssertNil(engine.savedUUID)
        XCTAssertNil(defaults.string(forKey: EngineSession.uuidKey))
        XCTAssertFalse(uuidEngine(probe, defaults: defaults).isReady)
        let count = await probe.preparations
        XCTAssertEqual(count, 0)
    }

    func testFailedDownloadIsLocalAndAllowsVerifiedRetry() async throws {
        let index = try? Data(contentsOf: PackageStorage.indexURL)
        defer {
            if let index { try? index.write(to: PackageStorage.indexURL, options: .atomic) }
            else { try? FileManager.default.removeItem(at: PackageStorage.indexURL) }
        }
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "polillas", withExtension: "tendies"))
        let staged = try PackageInspector().stage(fixture)
        defer { try? FileManager.default.removeItem(at: staged.directory) }
        let theme = CatalogTheme(id: "local-retry-fixture", name: "Retry fixture", author: nil,
                                 previewURL: nil, previewVideoURL: nil,
                                 packageURL: fixture, sha256: staged.inspection.sha256)
        let corruptDigest = CatalogTheme(id: theme.id, name: theme.name, author: theme.author,
                                         previewURL: theme.previewURL, previewVideoURL: theme.previewVideoURL,
                                         packageURL: theme.packageURL, sha256: String(repeating: "0", count: 64))
        let catalog = CatalogStore()
        let library = PackageLibrary()
        library.lastError = nil
        let originalIDs = library.packages.map(\.id)
        do { _ = try await catalog.download(corruptDigest, into: library); XCTFail("Mismatched content must fail") } catch {}
        XCTAssertNil(library.lastError, "A preview download must not trigger the root alert behind its modal")
        XCTAssertEqual(library.packages.map(\.id), originalIDs)
        XCTAssertFalse(library.busy)
        XCTAssertTrue(catalog.downloading.isEmpty)
        let id = try await catalog.download(theme, into: library)
        XCTAssertEqual(library.packages.first { $0.id == id }?.inspection.sha256, theme.sha256)
        XCTAssertTrue(catalog.downloading.isEmpty)
        XCTAssertNil(library.lastError)
    }

    func testDownloadRefreshesStaleRevisionBeforeVerifyingBytes() async throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "polillas", withExtension: "tendies"))
        let staged = try PackageInspector().stage(fixture)
        defer { try? FileManager.default.removeItem(at: staged.directory) }
        let hash = staged.inspection.sha256
        let stale = CatalogTheme(id: "revision-test", name: "Old", author: nil, previewURL: nil,
                                 previewVideoURL: nil, packageURL: URL(string: "https://example.com/theme.tendies")!,
                                 sha256: String(repeating: "0", count: 64))
        let catalog = CatalogStore(fetchPackage: { request in
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?
                .first(where: { $0.name == "coconutRevision" })?.value, hash)
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.copyItem(at: fixture, to: temporary)
            return (temporary, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }, fetch: { request in
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            let data = Data("""
            {"themes":[{"id":"revision-test","name":"Updated","packageURL":"https://example.com/theme.tendies","sha256":"\(hash)"}]}
            """.utf8)
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let library = PackageLibrary()
        let id = try await catalog.download(stale, into: library)
        XCTAssertEqual(library.packages.first { $0.id == id }?.inspection.sha256, hash)
        XCTAssertTrue(catalog.downloading.isEmpty)
    }

    func testSearchMatchesBothLanguagesAndAllQueryTerms() {
        let previous = AppLanguageStore.shared.language
        defer { AppLanguageStore.shared.language = previous }
        let theme = CatalogTheme(id: "polillas", name: "Polillas", author: nil, previewURL: nil,
                                 previewVideoURL: nil, packageURL: URL(fileURLWithPath: "/tmp/test.tendies"), sha256: "")
        AppLanguageStore.shared.language = .english
        XCTAssertTrue(ThemeSearch.matches(theme, query: "  POLILLAS   art  "))
        XCTAssertTrue(ThemeSearch.matches(theme, query: "Moths"))
        XCTAssertFalse(ThemeSearch.matches(theme, query: "Moths Nature"))
        AppLanguageStore.shared.language = .spanish
        XCTAssertTrue(ThemeSearch.matches(theme, query: "Moths Art"))
        XCTAssertTrue(ThemeSearch.matches(theme, query: "Polillas Arte"))
        XCTAssertTrue(ThemeSearch.matches(theme, query: "   "))
        XCTAssertEqual(ThemeSearch.normalized("  a\n b "), "a b")
    }

    func testRecentSearchesAreBoundedDeduplicatedAndClearable() throws {
        let name = "CoconutSearchTests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = GalleryPreferences(defaults: defaults)
        preferences.rememberSearch("   ")
        XCTAssertTrue(preferences.recentSearches.isEmpty)
        preferences.rememberSearch(" Arcoíris ")
        preferences.rememberSearch("ARCOIRIS")
        XCTAssertEqual(preferences.recentSearches, ["ARCOIRIS"])
        for number in 0..<8 { preferences.rememberSearch("Search \(number)") }
        let restored = GalleryPreferences(defaults: defaults)
        XCTAssertEqual(restored.recentSearches.count, 6)
        XCTAssertEqual(restored.recentSearches.first, "Search 7")
        restored.clearRecentSearches()
        XCTAssertTrue(GalleryPreferences(defaults: defaults).recentSearches.isEmpty)
    }

    func testSimulatorNeverInitializesAccess() async {
        let probe = AccessProbe()
        let engine = EngineSession(isSimulator: true, defaults: uuidDefaults(), prepare: { await probe.prepare() }, validate: { try await probe.validate($0) })
        await engine.activate()
        XCTAssertEqual(engine.state, .unavailable)
        let count = await probe.preparations
        XCTAssertEqual(count, 0)
    }

    func testReferenceVideoLoadsPlaysPausesAndReopens() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "polillas-motion", withExtension: "mp4"))
        let video = WallpaperMotionPlayer(url: url)
        defer { video.stop() }
        video.start(playing: false)
        try await waitForMedia { video.phase == .ready }
        XCTAssertFalse(video.isPlaying)
        XCTAssertTrue(video.player.isMuted)
        video.setPlayback(true)
        try await waitForMedia { video.isPlaying }
        video.setPlayback(false)
        try await waitForMedia { !video.isPlaying }
        XCTAssertFalse(video.isBuffering)
        video.stop()
        XCTAssertNil(video.player.currentItem)
        video.start(playing: false)
        try await waitForMedia { video.phase == .ready }
        XCTAssertFalse(video.isPlaying, "Reopening a paused preview must not start playback")
    }

    func testShowcaseFinishesAtVideoEndAndRemovesOldObserver() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "polillas-motion", withExtension: "mp4"))
        var finished = 0
        let video = WallpaperMotionPlayer(url: url, loops: false, onFinished: { finished += 1 })
        defer { video.stop() }
        video.start(playing: false)
        try await waitForMedia { video.phase == .ready }
        let item = try XCTUnwrap(video.player.currentItem)
        let duration = try await item.asset.load(.duration)
        video.setPlayback(true)
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertEqual(finished, 0, "Starting playback must not advance the showcase")
        video.setPlayback(false)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(finished, 0, "Pausing must not advance the showcase")
        await video.player.seek(to: CMTimeSubtract(duration, CMTime(seconds: 0.15, preferredTimescale: 600)))
        video.setPlayback(true)
        try await waitForMedia { finished == 1 }
        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: item)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(finished, 1, "Duplicate completion must not skip a theme")
        video.stop()
        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: item)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(finished, 1, "An old video must not advance a newer preview")
    }

    func testReferenceVideoFailureCanRetryAfterResourceRecovers() async throws {
        let source = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "polillas-motion", withExtension: "mp4"))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let destination = folder.appendingPathComponent("recovered.mp4")
        let video = WallpaperMotionPlayer(url: destination)
        defer { video.stop() }
        video.start(playing: true)
        try await waitForMedia { video.phase == .failed }
        XCTAssertFalse(video.isPlaying)
        XCTAssertFalse(video.isBuffering)
        try FileManager.default.copyItem(at: source, to: destination)
        video.retry()
        try await waitForMedia { video.phase == .ready && video.isPlaying }
        XCTAssertTrue(video.player.isMuted)
        video.stop()
        XCTAssertNil(video.player.currentItem)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(video.phase, .loading, "Callbacks from the previous attempt must not restore stale state after stop")
        XCTAssertFalse(video.isPlaying)
    }

    private func waitForMedia(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(12))
        while !condition() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(condition(), "Timed out waiting for the actual AVPlayer state", file: file, line: line)
    }

    func testArtworkDecodesAtBoundedSizeAndReusesCache() async throws {
        let source = try XCTUnwrap(Bundle.main.url(forResource: "fr-focus-artwork", withExtension: "jpg", subdirectory: "BundledCatalog"))
        let repository = ArtworkRepository()
        let first = try await repository.image(at: source)
        XCTAssertGreaterThan(first.height, 0)
        XCTAssertLessThanOrEqual(max(first.width, first.height), 3000)
        XCTAssertEqual(Double(first.width) / Double(first.height), 390.0 / 844.0, accuracy: 0.025)
        let second = try await repository.image(at: source)
        XCTAssertTrue(first === second)
    }

    func testArtworkFailureDoesNotPoisonRetry() async throws {
        let source = try XCTUnwrap(Bundle.main.url(forResource: "fr-focus-artwork", withExtension: "jpg", subdirectory: "BundledCatalog"))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        defer { try? FileManager.default.removeItem(at: file) }
        let repository = ArtworkRepository()
        do { _ = try await repository.image(at: file); XCTFail("Missing images must fail") } catch {}
        try Data("invalid image".utf8).write(to: file)
        do { _ = try await repository.image(at: file); XCTFail("Corrupt images must fail") } catch {}
        try Data(contentsOf: source).write(to: file)
        let recovered = try await repository.image(at: file)
        XCTAssertGreaterThan(recovered.height, 0)
        let cancelled = Task { try await repository.image(at: source) }
        cancelled.cancel()
        do { _ = try await cancelled.value; XCTFail("Cancelled image loads must not publish a result") }
        catch is CancellationError {} catch { XCTFail("Unexpected cancellation error: \(error)") }
    }
}

private actor CatalogRefreshProbe {
    enum Mode { case success, networkFailure, serverFailure, malformed, cancelled, delayed }
    private var mode: Mode = .success
    private(set) var calls = 0
    func set(_ value: Mode) { mode = value }
    func fetch(_ request: URLRequest) async throws -> (Data, URLResponse) {
        calls += 1
        switch mode {
        case .networkFailure: throw URLError(.notConnectedToInternet)
        case .cancelled: throw URLError(.cancelled)
        case .delayed: try await Task.sleep(for: .seconds(10))
        default: break
        }
        let data = mode == .malformed ? Data("invalid".utf8) : Data("""
        {"themes":[{"id":"remote-test","name":"Remote test","packageURL":"https://example.com/theme.tendies","sha256":"\(String(repeating: "a", count: 64))"}]}
        """.utf8)
        let response = HTTPURLResponse(url: request.url!, statusCode: mode == .serverFailure ? 503 : 200,
                                       httpVersion: nil, headerFields: nil)!
        return (data, response)
    }
}

private actor AccessProbe {
    private(set) var preparations = 0
    private var validations = 0
    private var readable = true
    var counts: (Int, Int) { (preparations, validations) }
    func prepare() -> PreparedPosterBoardAccess {
        preparations += 1
        return PreparedPosterBoardAccess(containerUUID: "F63F4723-5928-41AF-9319-C8A9CBAA6D7F", route: .direct)
    }
    func validate(_ access: PreparedPosterBoardAccess) throws {
        validations += 1
        if !readable { throw PosterBoardAccessError.notReadable }
    }
    func loseAccess() { readable = false }
    func restoreAccess() { readable = true }
}
