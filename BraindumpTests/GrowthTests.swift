import XCTest
import SwiftData
@testable import Braindump

@MainActor
final class GrowthTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func moment(_ title: String, at date: Date, kind: GrowthKind = .win) -> Page {
        let page = Page(title: title)
        page.growthKind = kind
        page.occurredAt = date
        return page
    }

    func testRecapUsesOccurrenceMonthAndExcludesNotesGoalsDeletedAndFutureEntries() throws {
        let october = date("2026-10-15T12:00:00Z")
        let edited = moment("Pottery", at: date("2026-10-01T00:00:00Z"), kind: .experience)
        edited.updatedAt = date("2026-11-20T12:00:00Z")
        let last = moment("Dinner", at: date("2026-10-31T23:59:59Z"))
        let previous = moment("September", at: date("2026-09-30T23:59:59Z"))
        let next = moment("November", at: date("2026-11-01T00:00:00Z"))
        let future = moment("Not happened yet", at: date("2026-10-20T12:00:00Z"))
        let deleted = moment("Deleted", at: october)
        deleted.softDelete()
        let goal = moment("An intention", at: october, kind: .goal)
        let note = Page(title: "Existing note")
        note.createdAt = october
        let pages = [edited, last, previous, next, deleted, goal, note]
        let recap = try XCTUnwrap(MonthlyRecap(
            month: october, pages: pages, calendar: calendar, now: date("2026-11-23T12:00:00Z")
        ))
        XCTAssertEqual(recap.moments.map(\.title), ["Dinner", "Pottery"])
        XCTAssertEqual(recap.wins, 1)
        XCTAssertEqual(recap.experiences, 1)
        let inProgress = try XCTUnwrap(MonthlyRecap(month: october, pages: [edited, future], calendar: calendar, now: october))
        XCTAssertEqual(inProgress.moments.map(\.title), ["Pottery"])
    }

    func testExperienceDaysRespectLocalCalendarAndRestoringChangesRecap() throws {
        var local = calendar
        local.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let a = moment("Morning", at: date("2026-10-05T18:00:00Z"), kind: .experience)
        let b = moment("Evening", at: date("2026-10-06T02:00:00Z"), kind: .experience)
        let c = moment("Next morning", at: date("2026-10-06T18:00:00Z"), kind: .experience)
        let now = date("2026-11-23T12:00:00Z")
        b.softDelete()
        var recap = try XCTUnwrap(MonthlyRecap(month: a.eventDate, pages: [a, b, c], calendar: local, now: now))
        XCTAssertEqual(recap.experiences, 2)
        XCTAssertEqual(recap.experienceDays, 2)
        b.restore()
        recap = try XCTUnwrap(MonthlyRecap(month: a.eventDate, pages: [a, b, c], calendar: local, now: now))
        XCTAssertEqual(recap.experiences, 3)
        XCTAssertEqual(recap.experienceDays, 2)
    }

    func testGoalLinkPhotoAndOccurrenceDateSurviveStoreReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LittleWins-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(url: directory.appendingPathComponent("store.sqlite"))
        let goalID: UUID
        let eventDate = date("2026-10-04T12:00:00Z")
        do {
            let container = try ModelContainer(for: Page.self, Paragraph.self, configurations: configuration)
            let goal = Page(title: "Make room for art")
            goal.growthKind = .goal
            goalID = goal.uuid
            container.mainContext.insert(goal)
            let win = moment("Tried pottery", at: eventDate, kind: .experience)
            win.growthCategory = .creativity
            win.linkedGoalID = goalID
            win.photoData = Data([1, 2, 3])
            let paragraph = Paragraph(text: "I made a tiny bowl.")
            paragraph.page = win
            win.paragraphs.append(paragraph)
            container.mainContext.insert(win)
            try container.mainContext.save()
        }
        let reopened = try ModelContainer(for: Page.self, Paragraph.self, configurations: configuration)
        let pages = try reopened.mainContext.fetch(FetchDescriptor<Page>())
        let win = try XCTUnwrap(pages.first(where: { $0.isMoment }))
        XCTAssertEqual(win.linkedGoalID, goalID)
        XCTAssertEqual(win.growthCategory, .creativity)
        XCTAssertEqual(win.eventDate, eventDate)
        XCTAssertEqual(win.photoData, Data([1, 2, 3]))
        XCTAssertEqual(win.paragraphs.first?.text, "I made a tiny bowl.")
    }

    func testExistingBraindumpStoreMigratesWithoutTurningNotesIntoWins() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LegacyNotes-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("store.sqlite")
        let noteID: UUID
        do {
            let schema = Schema([LegacyNotes.Page.self, LegacyNotes.Paragraph.self])
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let note = LegacyNotes.Page(title: "A note before Little Wins")
            noteID = note.uuid
            let line = LegacyNotes.Paragraph(text: "Keep this checklist and its formatting.")
            line.kindRaw = "checklist"
            line.isChecked = true
            line.formattingRangesData = try JSONEncoder().encode([
                CharacterFormat(location: 0, length: 4, bold: true, italic: false, underline: false)
            ])
            line.page = note
            note.paragraphs.append(line)
            container.mainContext.insert(note)
            try container.mainContext.save()
        }
        let container = try ModelContainer(for: Page.self, Paragraph.self, configurations: ModelConfiguration(url: url))
        let note = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Page>()).first)
        XCTAssertEqual(note.uuid, noteID)
        XCTAssertEqual(note.title, "A note before Little Wins")
        XCTAssertNil(note.growthKind)
        XCTAssertFalse(note.isMoment)
        XCTAssertEqual(note.paragraphs.first?.isChecked, true)
        XCTAssertEqual(note.paragraphs.first?.formattingRanges.first?.bold, true)
        XCTAssertNil(note.photoData)
    }

    func testReflectionEvidenceIsBoundedAndIncludesBothEndsOfTheMonth() throws {
        let start = date("2026-10-01T12:00:00Z")
        let pages = (0..<24).map { index in
            moment("Moment \(index)", at: start.addingTimeInterval(Double(index) * 86400))
        }
        let recap = try XCTUnwrap(MonthlyRecap(month: start, pages: pages, calendar: calendar, now: date("2026-11-23T12:00:00Z")))
        XCTAssertTrue(recap.reflectionEvidence.contains("Moment 0\n"))
        XCTAssertTrue(recap.reflectionEvidence.contains("Moment 23\n"))
        XCTAssertEqual(recap.reflectionEvidence.components(separatedBy: "\n\n").count, 16)
        XCTAssertLessThan(recap.reflectionEvidence.count, 8000)
    }
}

private enum LegacyNotes {
    @Model
    final class Page {
        var uuid: UUID = UUID()
        var title: String
        var colorName: String = "butter"
        var sortOrder: Int = 0
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var tags: [String] = []
        var isTrashed: Bool = false
        var deletedAt: Date?
        @Relationship(deleteRule: .cascade, inverse: \Paragraph.page)
        var paragraphs: [Paragraph] = []

        init(title: String) { self.title = title }
    }

    @Model
    final class Paragraph {
        var text: String
        var kindRaw: String = "text"
        var styleRaw: String = "body"
        var isChecked: Bool = false
        var sortOrder: Int = 0
        var formattingRangesData: Data?
        var page: Page?

        init(text: String) { self.text = text }
    }
}
