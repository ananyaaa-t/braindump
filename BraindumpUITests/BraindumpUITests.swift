import XCTest

final class BraindumpUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-SeedDemoData"]
        app.launch()
        XCTAssertTrue(app.buttons["New page"].waitForExistence(timeout: 10))
    }

    func testEditingPersistsAndDeletedPageCanBeRestored() {
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
    }

    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
