import XCTest

final class BraindumpUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-SeedDemoData"]
        app.launchEnvironment["UITEST_STORE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["capture-moment"].waitForExistence(timeout: 10))
    }

    func testEditingPersistsAndDeletedPageCanBeRestored() {
        app.tabBars.buttons["Notes"].tap()
        let title = "QA note \(UUID().uuidString.prefix(6))"
        app.buttons["New page"].tap()
        app.staticTexts["Untitled"].firstMatch.tap()
        let titleField = app.descendants(matching: .any)["page-title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)
        let editor = app.textViews["page-body"]
        editor.tap()
        editor.typeText("A useful idea worth keeping.")
        app.buttons["Text style"].tap()
        app.buttons["Checklist"].tap()
        app.buttons["Text style"].tap()
        app.buttons["Toggle Done"].tap()
        XCTAssertTrue((editor.value as? String ?? "").hasPrefix("●"))
        editor.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 8, dy: 14)).tap()
        XCTAssertTrue((editor.value as? String ?? "").hasPrefix("○"))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Change page color'")).firstMatch.tap()
        app.buttons["Lilac color"].tap()
        XCTAssertTrue(app.buttons["Change page color, currently Lilac"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts[title].firstMatch.waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        app.tabBars.buttons["Notes"].tap()
        XCTAssertTrue(app.staticTexts[title].firstMatch.waitForExistence(timeout: 5))
        app.staticTexts[title].firstMatch.tap()
        XCTAssertEqual(app.textViews["page-body"].value as? String, "○  A useful idea worth keeping.")
        XCTAssertTrue(app.buttons["Change page color, currently Lilac"].exists)
        app.buttons["Delete page"].tap()
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.staticTexts[title].firstMatch.exists)
    }

    func testDemoWalkthrough() {
        capture("demo-start")
        captureMomentsWalkthrough()
        app.tabBars.buttons["Notes"].tap()
        capture("home")
        let weekendNote = app.staticTexts["Weekend plans"].firstMatch
        for _ in 0..<6 {
            if weekendNote.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        weekendNote.tap()
        XCTAssertTrue(app.textViews["page-body"].waitForExistence(timeout: 5))
        capture("page-editor")

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Change page color'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Sky color"].waitForExistence(timeout: 5))
        capture("color-picker")
        app.buttons["Sky color"].tap()
        XCTAssertTrue(app.buttons["Change page color, currently Sky"].waitForExistence(timeout: 5))

        app.buttons["Page details"].tap()
        XCTAssertTrue(app.staticTexts["overview"].waitForExistence(timeout: 10))
        capture("ai-tags-overview")
        app.buttons["Done"].tap()
        app.buttons["Back"].tap()

        let search = app.textFields["Search notes…"]
        search.tap()
        search.typeText("Weekend")
        XCTAssertTrue(app.staticTexts["Weekend plans"].firstMatch.waitForExistence(timeout: 5))
        app.staticTexts["Weekend plans"].firstMatch.tap()
        XCTAssertTrue(app.textViews["page-body"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        app.tabBars.buttons["Moments"].tap()
        capture("demo-end")
    }

    func testLittleWinPersistsAppearsInRecapAndCanBeRestored() {
        let title = "Tried something brave \(UUID().uuidString.prefix(6))"
        app.buttons["capture-moment"].tap()
        let text = app.descendants(matching: .any)["moment-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap()
        text.typeText(title)
        app.buttons["save-moment"].tap()
        XCTAssertTrue(app.buttons["capture-moment"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        let card = app.staticTexts[title].firstMatch
        scrollTo(card)
        XCTAssertTrue(card.exists)
        card.tap()
        XCTAssertTrue(app.textViews["page-body"].waitForExistence(timeout: 5))
        app.buttons["Delete page"].tap()
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        scrollTo(card)
        XCTAssertTrue(card.exists)
        app.tabBars.buttons["Recaps"].tap()
        let recapCard = app.staticTexts[title].firstMatch
        scrollTo(recapCard)
        XCTAssertTrue(recapCard.exists)
        capture("little-wins-recap")
        app.tabBars.buttons["Notes"].tap()
        XCTAssertFalse(app.staticTexts[title].exists)
    }

    func testPersonalGoalConnectsMomentsWithoutCompletionChecklist() {
        app.tabBars.buttons["Goals"].tap()
        app.buttons["add-goal"].tap()
        let title = "More creative time \(UUID().uuidString.prefix(6))"
        let text = app.descendants(matching: .any)["moment-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap()
        text.typeText(title)
        app.buttons["save-moment"].tap()
        let goal = app.staticTexts[title].firstMatch
        scrollTo(goal)
        goal.tap()
        app.buttons["add-goal-moment"].tap()
        let momentText = app.descendants(matching: .any)["moment-text"]
        XCTAssertTrue(momentText.waitForExistence(timeout: 5))
        momentText.tap()
        momentText.typeText("Painted a little postcard")
        app.buttons["save-moment"].tap()
        let step = app.staticTexts["Painted a little postcard"].firstMatch
        scrollTo(step)
        XCTAssertTrue(step.exists)
        app.terminate()
        app.launch()
        app.tabBars.buttons["Goals"].tap()
        scrollTo(app.staticTexts[title].firstMatch)
        app.staticTexts[title].firstMatch.tap()
        scrollTo(step)
        XCTAssertTrue(step.exists)
    }

    func testLittleWinsVisualWalkthroughAndOfflineReflection() {
        captureMomentsWalkthrough()
    }

    private func captureMomentsWalkthrough() {
        capture("little-wins-home")
        app.buttons["capture-moment"].tap()
        capture("moment-capture")
        app.buttons["Cancel"].tap()
        app.tabBars.buttons["Goals"].tap()
        capture("little-wins-goals")
        app.tabBars.buttons["Moments"].tap()
        let recapLink = app.buttons["open-recap"]
        scrollTo(recapLink)
        recapLink.tap()
        XCTAssertTrue(app.tabBars.buttons["Recaps"].isSelected)
        capture("little-wins-monthly-recap")
        let reflection = app.buttons["generate-reflection"]
        scrollTo(reflection)
        reflection.tap()
        let result = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'record-based summary, not AI'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 30))
        capture("little-wins-offline-reflection")
    }

    func testPhotoOnlyMomentPersists() {
        app.buttons["capture-moment"].tap()
        app.buttons["Add a photo (optional)"].tap()
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH 'Photo,'")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 20), "Preload a sample image into the simulator photo library.")
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Remove photo"].waitForExistence(timeout: 20))
        app.buttons["save-moment"].tap()
        let card = app.staticTexts["A photo worth keeping"].firstMatch
        scrollTo(card)
        card.tap()
        XCTAssertTrue(app.images["Photo saved with this moment"].waitForExistence(timeout: 5))
        capture("little-wins-photo-moment")
        app.terminate()
        app.launch()
        scrollTo(card)
        card.tap()
        XCTAssertTrue(app.images["Photo saved with this moment"].waitForExistence(timeout: 5))
    }

    func testLastMomentCanBeRecoveredWithoutAnyNotes() {
        app.terminate()
        app.launchArguments = []
        app.launchEnvironment["UITEST_STORE_ID"] = UUID().uuidString
        app.launch()
        app.buttons["capture-moment"].tap()
        let text = app.descendants(matching: .any)["moment-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap()
        text.typeText("A moment I want to keep")
        app.buttons["save-moment"].tap()
        let card = app.staticTexts["A moment I want to keep"].firstMatch
        scrollTo(card)
        card.tap()
        app.buttons["Delete page"].tap()
        app.buttons["Dismiss undo"].tap()
        let recovery = app.buttons["recently-deleted-moments"]
        scrollTo(recovery)
        recovery.tap()
        let deleted = app.staticTexts["A moment I want to keep"].firstMatch
        XCTAssertTrue(deleted.waitForExistence(timeout: 5))
        deleted.swipeLeft()
        app.buttons["Restore"].tap()
        app.buttons["Done"].tap()
        app.terminate()
        app.launch()
        scrollTo(card)
        XCTAssertTrue(card.exists)
    }

    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<14 {
            if element.isHittable { return }
            app.scrollViews.firstMatch.swipeUp()
        }
    }

    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
