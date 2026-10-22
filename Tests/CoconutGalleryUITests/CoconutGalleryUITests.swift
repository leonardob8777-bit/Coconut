// SPDX-License-Identifier: GPL-3.0-only
import XCTest

final class CoconutGalleryUITests: XCTestCase {
    @MainActor
    func testGlassShowcaseAndPhoneDetail() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        let video = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("CoconutExperienceTests/Fixtures/polillas-motion.mp4")
        app.launchEnvironment["COCONUT_PREVIEW_VIDEO_URL"] = video.absoluteString
        app.launchArguments += ["-Coconut.language", "en", "-Coconut.appearance", "light", "-Coconut.previewAutoplay", "YES"]
        launch(app)
        XCTAssertTrue(app.buttons["Search wallpapers"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["Your next\nperspective."].exists)
        XCTAssertFalse(app.buttons["catalog.compare"].exists)
        capture(app, "60-phone-showcase-light")
        app.swipeUp()
        capture(app, "61-showcase-scrolled")
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "catalog.preview."))
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 5))
        let card = try XCTUnwrap(cards.allElementsBoundByIndex.first(where: { $0.isHittable }))
        card.tap()
        XCTAssertTrue(app.buttons["detail.close"].waitForExistence(timeout: 5))
        capture(app, "64-glass-over-collection")
        app.buttons["detail.close"].tap()
        app.buttons["Search wallpapers"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("polillas\n")
        XCTAssertTrue(app.buttons["search.preview.polillas"].waitForExistence(timeout: 5))
        app.buttons["search.preview.polillas"].tap()
        XCTAssertTrue(app.buttons["detail.close"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls["detail.previewMode"].exists)
        XCTAssertFalse(app.buttons["detail.playback"].exists)
        XCTAssertTrue(app.buttons["detail.use"].isEnabled)
        let playing = NSPredicate(format: "value == %@", "Playing")
        expectation(for: playing, evaluatedWith: app.otherElements["preview.video"])
        waitForExpectations(timeout: 12)
        capture(app, "62-glass-phone-detail-light")
        XCTAssertTrue(app.buttons["detail.use"].label.contains("Apply"))
        // A simulator cannot write PosterBoard. It must report that inline,
        // without introducing the old second confirmation screen.
        app.buttons["detail.use"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["apply.confirm"].exists)
        app.alerts.buttons["Cancel"].tap()
        app.buttons["detail.close"].tap()
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["-Coconut.language", "en", "-Coconut.appearance", "dark"]
        launch(app)
        XCTAssertTrue(app.buttons["Search wallpapers"].waitForExistence(timeout: 20))
        capture(app, "63-phone-showcase-dark")
    }

    @MainActor
    func testManualUUIDSetupPersistsAcrossRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-Coconut.language", "en", "-Coconut.appearance", "light"]
        launch(app)
        XCTAssertTrue(app.buttons["catalog.engine"].waitForExistence(timeout: 20))
        app.buttons["catalog.engine"].tap()
        if app.buttons["engine.forgetUUID"].exists {
            app.swipeUp()
            app.buttons["engine.forgetUUID"].tap()
        }
        let input = app.textFields["engine.uuidInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("invalid")
        app.buttons["engine.saveUUID"].tap()
        XCTAssertTrue(app.staticTexts["engine.uuidError"].exists)
        input.tap()
        input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))
        input.typeText("F63F4723-5928-41AF-9319-C8A9CBAA6D7F")
        app.buttons["engine.saveUUID"].tap()
        XCTAssertTrue(app.staticTexts["engine.savedUUID"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["engine.activate"].exists)
        capture(app, "45-saved-uuid")
        app.terminate()
        launch(app)
        XCTAssertTrue(app.buttons["catalog.engine"].waitForExistence(timeout: 20))
        app.buttons["catalog.engine"].tap()
        XCTAssertEqual(app.staticTexts["engine.savedUUID"].label, "F63F4723-5928-41AF-9319-C8A9CBAA6D7F")
        app.buttons["engine.computerHelp"].tap()
        app.swipeUp()
        capture(app, "46-computer-setup")
        XCTAssertTrue(app.descendants(matching: .any)["Open Nugget for desktop"].firstMatch.exists, app.debugDescription)
        app.buttons["engine.forgetUUID"].tap()
        XCTAssertFalse(app.staticTexts["engine.savedUUID"].exists)
        XCTAssertTrue(app.buttons["engine.activate"].exists)
        XCTAssertFalse(app.buttons["engine.activate"].isEnabled)
    }

    @MainActor
    func testGyroscopeCollectionSearchPreviewAndSave() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-Coconut.language", "en", "-Coconut.appearance", "light"]
        launch(app)
        XCTAssertTrue(app.buttons["catalog.featured.polillas"].waitForExistence(timeout: 20))
        for _ in 0..<3 where !app.staticTexts["catalog.resultCount"].exists { app.swipeUp() }
        XCTAssertEqual(app.staticTexts["catalog.resultCount"].label, "194 wallpapers")
        app.buttons["Search wallpapers"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("es-calle\n")
        XCTAssertTrue(app.buttons["search.preview.es-calle"].waitForExistence(timeout: 5))
        capture(app, "47-gyro-search")
        app.buttons["search.preview.es-calle"].tap()
        XCTAssertTrue(app.buttons["detail.save"].waitForExistence(timeout: 5))
        if app.buttons["detail.save"].isEnabled { app.buttons["detail.save"].tap() }
        expectation(for: NSPredicate(format: "label CONTAINS[c] %@", "Saved"), evaluatedWith: app.buttons["detail.save"])
        waitForExpectations(timeout: 20)
        XCTAssertTrue(app.buttons["detail.use"].isEnabled)
        capture(app, "48-gyro-preview")
    }

    @MainActor
    func testExpandedCollectionSearchPreviewAndSave() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-Coconut.language", "en", "-Coconut.appearance", "light"]
        launch(app)
        XCTAssertTrue(app.buttons["catalog.featured.polillas"].waitForExistence(timeout: 20))
        for _ in 0..<3 where !app.staticTexts["catalog.resultCount"].exists { app.swipeUp() }
        XCTAssertEqual(app.staticTexts["catalog.resultCount"].label, "194 wallpapers")
        app.buttons["Search wallpapers"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Tape Figure\n")
        XCTAssertTrue(app.buttons["search.preview.n140"].waitForExistence(timeout: 5))
        capture(app, "43-expanded-collection-search")
        app.buttons["search.preview.n140"].tap()
        XCTAssertTrue(app.buttons["detail.save"].waitForExistence(timeout: 5))
        if app.buttons["detail.save"].isEnabled { app.buttons["detail.save"].tap() }
        expectation(for: NSPredicate(format: "label CONTAINS[c] %@", "Saved"), evaluatedWith: app.buttons["detail.save"])
        waitForExpectations(timeout: 20)
        XCTAssertTrue(app.buttons["detail.use"].isEnabled)
        capture(app, "44-new-wallpaper-preview")
    }

    @MainActor
    func testGalleryPreviewFavoritesAndApplyReviewWithoutRunningInstaller() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-Coconut.appearance", "light"]
        app.launchArguments += ["-Coconut.language", "en"]
        launch(app)
        XCTAssertTrue(app.buttons["catalog.featured.polillas"].waitForExistence(timeout: 15))
        capture(app, "01-explorar")
        app.buttons["catalog.featured.polillas"].tap()
        XCTAssertTrue(app.buttons["detail.close"].waitForExistence(timeout: 5))
        capture(app, "02-vista-previa")
        let favorite = app.buttons["favorite.polillas"]
        if favorite.label == "Remove from favorites" { favorite.tap() }
        favorite.tap()
        XCTAssertTrue(app.buttons["detail.close"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(favorite.label, "Remove from favorites")
        app.buttons["detail.clock"].tap()
        capture(app, "03-referencia-bloqueo")
        app.segmentedControls["detail.previewMode"].buttons["Motion"].tap()
        capture(app, "04-movimiento")
        if app.buttons["detail.save"].isEnabled { app.buttons["detail.save"].tap() }
        XCTAssertTrue(app.buttons["detail.save"].waitForExistence(timeout: 10))
        let saved = NSPredicate(format: "label CONTAINS[c] %@", "Saved")
        expectation(for: saved, evaluatedWith: app.buttons["detail.save"])
        waitForExpectations(timeout: 15)
        app.buttons["detail.use"].tap()
        XCTAssertTrue(app.buttons["apply.confirm"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["apply.configure"].exists)
        XCTAssertFalse(app.buttons["engine.activate"].exists)
        XCTAssertFalse(app.buttons["apply.confirm"].isEnabled, "Simulator review must never invoke the installer")
        capture(app, "05-revision-aplicar")
        app.buttons["apply.close"].tap()
        app.buttons["detail.close"].tap()
        app.tabBars.buttons["My collection"].tap()
        XCTAssertTrue(app.buttons["catalog.preview.polillas"].waitForExistence(timeout: 5))
        capture(app, "06-mi-coleccion")
        app.segmentedControls.buttons["Favorites"].tap()
        XCTAssertTrue(app.buttons["catalog.preview.polillas"].exists)
        app.tabBars.buttons["Explore"].tap()
        app.buttons["catalog.filter.nature"].tap()
        XCTAssertTrue(app.buttons["catalog.preview.blanca"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["catalog.preview.batman"].exists)
        capture(app, "07-coleccion-naturaleza")
    }

    @MainActor
    func testSearchAndDarkAppearance() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-Coconut.language", "en"]
        launch(app)
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 15))
        app.buttons["Settings"].tap()
        app.buttons["settings.appearance"].tap()
        app.buttons["Dark"].tap()
        capture(app, "08-ajustes-oscuro")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        capture(app, "09-explorar-oscuro")
        app.buttons["Search wallpapers"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Moths\n")
        XCTAssertTrue(app.buttons["search.preview.polillas"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 result"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["search.preview.batman"].exists)
        capture(app, "10-busqueda")
        app.buttons["search.preview.polillas"].tap()
        XCTAssertTrue(app.buttons["detail.close"].waitForExistence(timeout: 5))
        capture(app, "11-detalle-oscuro")
        app.buttons["detail.expand"].tap()
        XCTAssertTrue(app.buttons["Close full screen"].waitForExistence(timeout: 5))
        capture(app, "12-vista-completa")
        app.buttons["Close full screen"].tap()
        app.buttons["detail.close"].tap()
        // iOS 26 exposes a native Close control while the search session is active.
        if app.buttons["Close search"].exists {
            app.buttons["Close search"].tap()
        } else {
            app.buttons["Close"].tap()
            if app.buttons["Close search"].waitForExistence(timeout: 3) { app.buttons["Close search"].tap() }
        }
        XCTAssertTrue(app.tabBars.buttons["Explore"].isHittable)
    }

    @MainActor
    func testAccessibilityTextKeepsPrimaryActionsAvailable() throws {
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launchArguments += ["-Coconut.language", "en"]
        launch(app)
        XCTAssertTrue(app.buttons["catalog.featured.polillas"].waitForExistence(timeout: 15))
        app.buttons["catalog.featured.polillas"].tap()
        XCTAssertTrue(app.buttons["detail.use"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["detail.use"].isHittable)
        XCTAssertTrue(app.buttons["detail.close"].isHittable)
        capture(app, "13-texto-accesible")
    }

    @MainActor
    func testLanguageSwitchAndEngineEntryPoints() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        launch(app)
        XCTAssertTrue(app.buttons["catalog.settings"].waitForExistence(timeout: 15))
        app.buttons["catalog.settings"].tap()
        app.buttons["settings.language"].tap()
        app.buttons["Español"].tap()
        XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Explorar"].exists)
        capture(app, "14-idioma-espanol")
        app.terminate()
        launch(app)
        XCTAssertTrue(app.tabBars.buttons["Explorar"].waitForExistence(timeout: 15))
        app.buttons["catalog.settings"].tap()
        app.buttons["settings.language"].tap()
        app.buttons["English"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture(app, "15-settings-english")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["catalog.engine"].tap()
        XCTAssertTrue(app.buttons["engine.activate"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["engine.activate"].isEnabled)
        XCTAssertTrue(app.buttons["engine.saveUUID"].exists)
        capture(app, "16-engine-simulator")
        app.buttons["engine.close"].tap()
        XCTAssertTrue(app.tabBars.buttons["Explore"].isHittable)
    }

    @MainActor
    func testLibrarySearchOrderingAndPackageDetails() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-Coconut.language", "en", "-Coconut.appearance", "light"]
        launch(app)
        XCTAssertTrue(app.buttons["catalog.featured.polillas"].waitForExistence(timeout: 15))
        app.buttons["catalog.featured.polillas"].tap()
        if app.buttons["detail.save"].isEnabled { app.buttons["detail.save"].tap() }
        let saved = NSPredicate(format: "label CONTAINS[c] %@", "Saved")
        expectation(for: saved, evaluatedWith: app.buttons["detail.save"])
        waitForExpectations(timeout: 15)
        app.buttons["detail.more"].tap()
        app.buttons["detail.info"].tap()
        XCTAssertTrue(app.buttons["info.packageDetails"].waitForExistence(timeout: 5))
        capture(app, "17-wallpaper-details")
        app.buttons["info.packageDetails"].tap()
        XCTAssertTrue(app.navigationBars["Diagnostics"].waitForExistence(timeout: 5))
        app.navigationBars["Diagnostics"].buttons["BackButton"].tap()
        XCTAssertTrue(app.buttons["info.close"].waitForExistence(timeout: 5))
        app.buttons["info.close"].tap()
        app.buttons["detail.clock"].tap()
        app.buttons["detail.expand"].tap()
        XCTAssertTrue(app.buttons["Close full screen"].waitForExistence(timeout: 5))
        capture(app, "18-full-screen-clock")
        app.buttons["Close full screen"].tap()
        app.buttons["detail.close"].tap()
        app.tabBars.buttons["My collection"].tap()
        app.buttons["library.sort"].tap()
        app.buttons["library.sort.name"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Moths\n")
        XCTAssertTrue(app.buttons["catalog.preview.polillas"].waitForExistence(timeout: 5))
        capture(app, "19-library-search")
        search.tap()
        search.buttons.firstMatch.tap()
        search.typeText("zzzz-no-wallpaper\n")
        XCTAssertTrue(app.buttons["library.clearSearch"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["catalog.preview.polillas"].exists)
        app.buttons["library.clearSearch"].tap()
        XCTAssertTrue(app.buttons["catalog.preview.polillas"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testManualPlaybackControlsReflectActualPlayerState() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-Coconut.language", "en", "-Coconut.appearance", "light", "-Coconut.previewAutoplay", "NO"]
        launch(app)
        XCTAssertTrue(app.buttons["catalog.featured.polillas"].waitForExistence(timeout: 15))
        app.buttons["catalog.featured.polillas"].tap()
        app.segmentedControls["detail.previewMode"].buttons["Motion"].tap()
        let playback = app.buttons["detail.playback"]
        XCTAssertTrue(playback.waitForExistence(timeout: 5))
        XCTAssertEqual(playback.label, "Play video")
        let video = app.descendants(matching: .any).matching(identifier: "preview.video").firstMatch
        XCTAssertTrue(video.waitForExistence(timeout: 5), app.debugDescription)
        playback.tap()
        expectation(for: NSPredicate(format: "value == %@", "Playing"), evaluatedWith: video)
        waitForExpectations(timeout: 10)
        capture(app, "20-video-playing")
        playback.tap()
        expectation(for: NSPredicate(format: "value == %@", "Paused"), evaluatedWith: video)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(playback.label, "Play video")
        XCTAssertTrue(video.frame.contains(app.buttons["detail.expand"].frame), "Expand must stay inside the artwork bounds")
        capture(app, "21-video-paused")
        app.buttons["detail.expand"].tap()
        XCTAssertTrue(app.buttons["immersive.playback"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["immersive.playback"].label, "Play video")
        app.buttons["immersive.playback"].tap()
        XCTAssertEqual(app.buttons["immersive.playback"].label, "Pause video")
        capture(app, "22-full-screen-playback")
        app.buttons["Close full screen"].tap()
        XCTAssertEqual(app.buttons["detail.playback"].label, "Pause video")
    }

    @MainActor
    func testComparisonSwapsAndOpensChosenTheme() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-Coconut.language", "en", "-Coconut.appearance", "light", "-Coconut.catalogSort", "curated"]
        launch(app)
        XCTAssertTrue(app.buttons["catalog.compare"].waitForExistence(timeout: 15))
        app.buttons["catalog.compare"].tap()
        XCTAssertTrue(app.buttons["compare.first.choose"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["compare.first.choose"].label.contains("Moths"))
        let first = app.descendants(matching: .any).matching(identifier: "compare.first.artwork").firstMatch
        let second = app.descendants(matching: .any).matching(identifier: "compare.second.artwork").firstMatch
        XCTAssertTrue(first.exists && second.exists)
        XCTAssertGreaterThan(first.frame.width, 80)
        XCTAssertGreaterThan(first.frame.height, 170)
        XCTAssertEqual(first.frame.width, second.frame.width, accuracy: 1)
        XCTAssertEqual(first.frame.height, second.frame.height, accuracy: 1)
        capture(app, "23-compare-wallpapers")
        app.buttons["compare.swap"].tap()
        XCTAssertTrue(app.buttons["compare.second.choose"].label.contains("Moths"))
        app.buttons["compare.second.choose"].tap()
        app.buttons["compare.second.option.blanca"].tap()
        XCTAssertTrue(app.buttons["compare.second.choose"].label.contains("White"))
        capture(app, "24-compare-chosen-theme")
        app.buttons["compare.second.open"].tap()
        XCTAssertTrue(app.navigationBars["White"].waitForExistence(timeout: 5))
        app.buttons["detail.close"].tap()
        app.buttons["compare.close"].tap()
        XCTAssertTrue(app.tabBars.buttons["Explore"].isHittable)
    }

    @MainActor
    func testDiscoverySuggestionsRecentSearchAndSavedFilter() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-Coconut.language", "en", "-Coconut.appearance", "light", "-Coconut.catalogSort", "curated"]
        launch(app)
        XCTAssertTrue(app.buttons["catalog.featured.polillas"].waitForExistence(timeout: 15))
        app.buttons["catalog.featured.polillas"].tap()
        if app.buttons["detail.save"].isEnabled { app.buttons["detail.save"].tap() }
        expectation(for: NSPredicate(format: "label CONTAINS[c] %@", "Saved"), evaluatedWith: app.buttons["detail.save"])
        waitForExpectations(timeout: 15)
        app.buttons["detail.close"].tap()
        app.buttons["Search wallpapers"].tap()
        XCTAssertTrue(app.buttons["search.collection.nature"].waitForExistence(timeout: 5))
        if app.buttons["search.clearHistory"].exists { app.buttons["search.clearHistory"].tap() }
        capture(app, "25-search-suggestions")
        app.buttons["search.collection.nature"].tap()
        XCTAssertTrue(app.buttons["search.preview.blanca"].waitForExistence(timeout: 5))
        app.buttons["search.preview.blanca"].tap()
        XCTAssertTrue(app.buttons["detail.close"].waitForExistence(timeout: 5))
        app.buttons["detail.close"].tap()
        if app.buttons["Close search"].exists { app.buttons["Close search"].tap() }
        else {
            app.buttons["Close"].tap()
            if app.buttons["Close search"].waitForExistence(timeout: 3) { app.buttons["Close search"].tap() }
        }
        app.buttons["Search wallpapers"].tap()
        XCTAssertTrue(app.buttons["search.recent.Nature"].waitForExistence(timeout: 5))
        capture(app, "26-recent-search")
        app.buttons["Close search"].tap()
        app.swipeUp()
        let filters = app.buttons["catalog.filters"]
        // A fast scroll can leave this section header underneath the translucent navigation bar.
        if filters.frame.minY < app.navigationBars.firstMatch.frame.maxY + 12 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)))
        }
        XCTAssertTrue(filters.isHittable)
        XCTAssertGreaterThan(filters.frame.minY, app.navigationBars.firstMatch.frame.maxY)
        filters.tap()
        let hideSaved = app.buttons["catalog.hideSaved"]
        XCTAssertTrue(hideSaved.waitForExistence(timeout: 5))
        hideSaved.tap()
        XCTAssertTrue(app.buttons["catalog.resetFilters"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["catalog.preview.polillas"].exists)
        capture(app, "27-filter-unsaved")
        app.buttons["catalog.resetFilters"].tap()
        XCTAssertTrue(app.buttons["catalog.preview.polillas"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testComparisonWithLargeTextInSpanishKeepsActionsAvailable() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-Coconut.language", "es", "-Coconut.appearance", "light", "-Coconut.catalogSort", "curated",
                                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launch(app)
        XCTAssertTrue(app.buttons["catalog.compare"].waitForExistence(timeout: 15))
        app.buttons["catalog.compare"].tap()
        XCTAssertTrue(app.buttons["compare.first.choose"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["compare.first.choose"].isHittable)
        XCTAssertTrue(app.buttons["compare.close"].isHittable)
        capture(app, "28-compare-accessible-spanish")
        if !app.buttons["compare.first.open"].isHittable { app.swipeUp() }
        app.buttons["compare.first.open"].tap()
        XCTAssertTrue(app.buttons["detail.use"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["detail.use"].isHittable)
        XCTAssertEqual(app.buttons["detail.use"].label, "Usar fondo")
        app.buttons["detail.close"].tap()
        app.buttons["compare.close"].tap()
    }

    @MainActor
    func testFailedVideoKeepsArtworkRetryAndUseAvailable() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchEnvironment["COCONUT_PREVIEW_VIDEO_URL"] = "file:///Coconut-QA-missing-reference.mp4"
        app.launchArguments += ["-Coconut.language", "en", "-Coconut.appearance", "light", "-Coconut.previewAutoplay", "YES"]
        launch(app)
        XCTAssertTrue(app.buttons["catalog.featured.polillas"].waitForExistence(timeout: 15))
        app.buttons["catalog.featured.polillas"].tap()
        app.segmentedControls["detail.previewMode"].buttons["Motion"].tap()
        let retry = app.buttons["preview.video.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 12))
        XCTAssertTrue(retry.isHittable)
        XCTAssertTrue(app.staticTexts["Video unavailable"].firstMatch.exists)
        XCTAssertEqual(app.buttons["detail.playback"].label, "Video unavailable")
        XCTAssertFalse(app.buttons["detail.playback"].isEnabled)
        XCTAssertTrue(app.buttons["detail.use"].isHittable)
        capture(app, "29-video-unavailable")
        retry.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["detail.expand"].isHittable)
        app.buttons["detail.expand"].tap()
        XCTAssertTrue(app.buttons["Close full screen"].waitForExistence(timeout: 5))
        let candidates = app.buttons.matching(identifier: "preview.video.retry")
        for candidate in candidates.allElementsBoundByIndex {
            print("Coconut fullscreen retry: frame=\(candidate.frame), hittable=\(candidate.isHittable), label=\(candidate.label)")
        }
        let visibleRetry = NSPredicate { _, _ in candidates.allElementsBoundByIndex.contains { $0.isHittable } }
        expectation(for: visibleRetry, evaluatedWith: app)
        waitForExpectations(timeout: 12)
        capture(app, "30-video-fallback-fullscreen")
        let fullScreenRetry = try XCTUnwrap(candidates.allElementsBoundByIndex.first { $0.isHittable }, app.debugDescription)
        fullScreenRetry.tap()
        expectation(for: visibleRetry, evaluatedWith: app)
        waitForExpectations(timeout: 12)
        app.buttons["Close full screen"].tap()
        app.segmentedControls["detail.previewMode"].buttons["Image"].tap()
        XCTAssertFalse(retry.exists)
        capture(app, "31-artwork-after-video-failure")
        app.buttons["detail.use"].tap()
        XCTAssertTrue(app.buttons["apply.confirm"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["apply.confirm"].isEnabled)
        XCTAssertTrue(app.buttons["apply.close"].isHittable)
    }

    @MainActor
    func testPlaybackIntentSurvivesBackgroundReturn() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-Coconut.language", "en", "-Coconut.appearance", "light", "-Coconut.previewAutoplay", "NO"]
        launch(app)
        XCTAssertTrue(app.buttons["catalog.featured.polillas"].waitForExistence(timeout: 15))
        app.buttons["catalog.featured.polillas"].tap()
        app.segmentedControls["detail.previewMode"].buttons["Motion"].tap()
        let video = app.descendants(matching: .any).matching(identifier: "preview.video").firstMatch
        XCTAssertTrue(video.waitForExistence(timeout: 8))
        expectation(for: NSPredicate(format: "value == %@", "Paused"), evaluatedWith: video)
        waitForExpectations(timeout: 10)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["detail.playback"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["detail.playback"].label, "Play video")
        expectation(for: NSPredicate(format: "value == %@", "Paused"), evaluatedWith: video)
        waitForExpectations(timeout: 10)
        app.buttons["detail.playback"].tap()
        expectation(for: NSPredicate(format: "value == %@", "Playing"), evaluatedWith: video)
        waitForExpectations(timeout: 10)
        XCUIDevice.shared.press(.home)
        app.activate()
        expectation(for: NSPredicate(format: "value == %@", "Playing"), evaluatedWith: video)
        waitForExpectations(timeout: 10)
        app.buttons["detail.playback"].tap()
        expectation(for: NSPredicate(format: "value == %@", "Paused"), evaluatedWith: video)
        waitForExpectations(timeout: 10)
        capture(app, "32-paused-after-background-return")
    }

    @MainActor
    func testSavedFileReviewAndFavoriteSummary() throws {
        try reviewSavedFile(spanish: false)
    }

    @MainActor
    func testSavedFileWithLargeSpanishText() throws {
        try reviewSavedFile(spanish: true)
    }

    @MainActor
    private func reviewSavedFile(spanish: Bool) throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-Coconut.language", spanish ? "es" : "en", "-Coconut.appearance", spanish ? "dark" : "light"]
        if spanish { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        launch(app)
        XCTAssertTrue(app.buttons["catalog.featured.polillas"].waitForExistence(timeout: 15))
        app.buttons["catalog.featured.polillas"].tap()
        if app.buttons["detail.save"].isEnabled { app.buttons["detail.save"].tap() }
        expectation(for: NSPredicate(format: "enabled == NO"), evaluatedWith: app.buttons["detail.save"])
        waitForExpectations(timeout: 15)
        let favorite = app.buttons["favorite.polillas"]
        if favorite.label == (spanish ? "Añadir a favoritos" : "Add to favorites") { favorite.tap() }
        app.buttons["detail.close"].tap()
        app.tabBars.buttons[spanish ? "Mi colección" : "My collection"].tap()
        app.segmentedControls["library.filter"].buttons[spanish ? "Favoritos" : "Favorites"].tap()
        XCTAssertTrue(app.staticTexts["library.summary"].label.contains(spanish ? "favorito" : "favorite"))
        let card = app.buttons["catalog.preview.polillas"]
        if !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.press(forDuration: 1)
        app.buttons["library.file"].tap()
        XCTAssertTrue(app.buttons["package.use"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["package.use"].isHittable)
        capture(app, spanish ? "34-saved-file-large-spanish" : "33-saved-file")
        if !spanish {
            XCTAssertTrue(app.staticTexts["package.filename"].label.hasSuffix(".tendies"))
            app.swipeUp()
            app.buttons["package.details"].tap()
            XCTAssertTrue(app.navigationBars["Diagnostics"].waitForExistence(timeout: 5))
            app.navigationBars["Diagnostics"].buttons["BackButton"].tap()
        }
        app.buttons["package.use"].tap()
        XCTAssertTrue(app.buttons["apply.close"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["apply.confirm"].isEnabled)
        app.buttons["apply.close"].tap()
        XCTAssertTrue(app.buttons["package.close"].waitForExistence(timeout: 5))
        app.buttons["package.close"].tap()
        XCTAssertTrue(app.tabBars.buttons[spanish ? "Mi colección" : "My collection"].isHittable)
    }

    @MainActor
    func testFavoriteFromSearchUpdatesLibraryWithoutOpeningPreview() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-Coconut.language", "en", "-Coconut.appearance", "light"]
        launch(app)
        XCTAssertTrue(app.buttons["Search wallpapers"].waitForExistence(timeout: 15))
        app.buttons["Search wallpapers"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Moths\n")
        let favorite = app.buttons["search.favorite.polillas"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        if favorite.label == "Remove Moths from favorites" { favorite.tap() }
        favorite.tap()
        XCTAssertEqual(favorite.label, "Remove Moths from favorites")
        XCTAssertTrue(app.buttons["search.preview.polillas"].exists)
        XCTAssertFalse(app.buttons["detail.close"].exists)
        capture(app, "35-quick-favorite-search")
        if app.buttons["Close search"].exists { app.buttons["Close search"].tap() }
        else {
            app.buttons["Close"].tap()
            if app.buttons["Close search"].waitForExistence(timeout: 3) { app.buttons["Close search"].tap() }
        }
        app.tabBars.buttons["My collection"].tap()
        app.segmentedControls["library.filter"].buttons["Favorites"].tap()
        let libraryFavorite = app.buttons["catalog.favorite.polillas"]
        if !libraryFavorite.isHittable { app.swipeUp() }
        XCTAssertTrue(libraryFavorite.waitForExistence(timeout: 5))
        XCTAssertEqual(libraryFavorite.label, "Remove Moths from favorites")
        libraryFavorite.tap()
        XCTAssertFalse(app.buttons["catalog.preview.polillas"].exists)
    }

    @MainActor
    func testActiveFiltersCanBeRemovedIndependently() throws {
        try reviewFilterControls(spanish: false)
    }

    @MainActor
    func testActiveFiltersWithLargeSpanishText() throws {
        try reviewFilterControls(spanish: true)
    }

    @MainActor
    private func reviewFilterControls(spanish: Bool) throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-Coconut.language", spanish ? "es" : "en", "-Coconut.appearance", spanish ? "dark" : "light", "-Coconut.catalogSort", "name"]
        if spanish { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        launch(app)
        let filters = app.buttons["catalog.filters"]
        XCTAssertTrue(filters.waitForExistence(timeout: 15))
        if !filters.isHittable { app.swipeUp() }
        filters.tap()
        app.buttons["catalog.onlyMotion"].tap()
        filters.tap()
        app.buttons["catalog.hideSaved"].tap()
        let motion = app.buttons["catalog.removeMotion"]
        let saved = app.buttons["catalog.removeHiddenSaved"]
        XCTAssertTrue(motion.waitForExistence(timeout: 5))
        XCTAssertTrue(saved.exists)
        if !motion.isHittable { app.swipeUp() }
        capture(app, spanish ? "37-filters-large-spanish" : "36-active-filters")
        motion.tap()
        XCTAssertFalse(motion.exists)
        XCTAssertTrue(saved.exists)
        if !saved.isHittable { app.swipeUp() }
        saved.tap()
        XCTAssertFalse(saved.exists)
        XCTAssertFalse(app.buttons["catalog.resetFilters"].exists)
        XCTAssertTrue(app.staticTexts["catalog.resultCount"].exists)
    }

    @MainActor
    private func launch(_ app: XCUIApplication) {
        if !app.launchArguments.contains("-Coconut.catalogSort") {
            app.launchArguments += ["-Coconut.catalogSort", "curated"]
        }
        app.launch()
    }

    @MainActor
    func testCollectionUpdateFailureCanRetryWithoutLosingGallery() throws {
        try reviewCollectionUpdates(spanish: false)
    }

    @MainActor
    func testCollectionUpdatesWithLargeSpanishText() throws {
        try reviewCollectionUpdates(spanish: true)
    }

    @MainActor
    private func reviewCollectionUpdates(spanish: Bool) throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchArguments += ["-Coconut.language", spanish ? "es" : "en", "-Coconut.appearance", spanish ? "dark" : "light"]
        if spanish { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        launch(app)
        XCTAssertTrue(app.buttons["catalog.featured.polillas"].waitForExistence(timeout: 15))
        app.buttons["catalog.settings"].tap()
        let refresh = app.buttons["settings.refreshCollection"]
        for _ in 0..<6 {
            if refresh.exists && refresh.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(refresh.isHittable)
        expectation(for: NSPredicate(format: "enabled == YES"), evaluatedWith: refresh)
        waitForExpectations(timeout: 12)
        refresh.tap()
        expectation(for: NSPredicate(format: "enabled == YES"), evaluatedWith: refresh)
        waitForExpectations(timeout: 12)
        let status = app.descendants(matching: .any).matching(identifier: "settings.collectionStatus").firstMatch
        expectation(for: NSPredicate(format: "label CONTAINS %@", spanish ? "No se pudieron" : "Could not check"), evaluatedWith: status)
        waitForExpectations(timeout: 12)
        capture(app, spanish ? "42-collection-updates-large-spanish" : "41-collection-updates")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["catalog.featured.polillas"].waitForExistence(timeout: 5))
        app.buttons["catalog.featured.polillas"].tap()
        XCTAssertTrue(app.buttons["detail.use"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["detail.use"].isEnabled)
    }

    @MainActor
    func testMissingArtworkCanRetryWithoutBlockingWallpaperActions() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchEnvironment["COCONUT_PREVIEW_ARTWORK_URL"] = "file:///Coconut-QA-missing-artwork.jpg"
        app.launchArguments += ["-Coconut.language", "en", "-Coconut.appearance", "light"]
        launch(app)
        XCTAssertTrue(app.buttons["catalog.featured.polillas"].waitForExistence(timeout: 15))
        app.buttons["catalog.featured.polillas"].tap()
        let retry = app.buttons["preview.artwork.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 8))
        XCTAssertTrue(retry.isHittable)
        XCTAssertTrue(app.buttons["detail.use"].isEnabled)
        retry.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 8))
        capture(app, "38-missing-artwork-retry")
        app.buttons["detail.expand"].tap()
        let candidates = app.buttons.matching(identifier: "preview.artwork.retry")
        expectation(for: NSPredicate { _, _ in candidates.allElementsBoundByIndex.contains { $0.isHittable } }, evaluatedWith: app)
        waitForExpectations(timeout: 8)
        try XCTUnwrap(candidates.allElementsBoundByIndex.first { $0.isHittable }).tap()
        capture(app, "39-missing-artwork-fullscreen")
        app.buttons["Close full screen"].tap()
        XCTAssertTrue(app.buttons["detail.use"].isHittable)
        app.buttons["detail.close"].tap()
        XCTAssertTrue(app.buttons["catalog.featured.polillas"].isHittable)
    }

    @MainActor
    func testArtworkRetryWithLargeSpanishTextFitsSmallPreview() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["COCONUT_CATALOG_URL"] = "https://127.0.0.1:1/catalog.json"
        app.launchEnvironment["COCONUT_PREVIEW_ARTWORK_URL"] = "file:///Coconut-QA-missing-artwork.jpg"
        app.launchArguments += ["-Coconut.language", "es", "-Coconut.appearance", "dark",
                                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launch(app)
        XCTAssertTrue(app.buttons["catalog.featured.polillas"].waitForExistence(timeout: 15))
        app.buttons["catalog.featured.polillas"].tap()
        let retry = app.buttons["preview.artwork.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 8))
        XCTAssertTrue(retry.isHittable)
        XCTAssertEqual(retry.label, "Volver a intentar")
        XCTAssertGreaterThanOrEqual(retry.frame.width, 44)
        XCTAssertGreaterThanOrEqual(retry.frame.height, 44)
        XCTAssertFalse(retry.frame.intersects(app.buttons["detail.expand"].frame), "Retry and expand must not overlap")
        retry.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["detail.use"].isHittable)
        capture(app, "40-artwork-retry-large-spanish")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
