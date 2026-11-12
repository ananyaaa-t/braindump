import XCTest
import UIKit
@testable import Braindump

@MainActor
final class EditorTests: XCTestCase {
    func testHeadingStyleSurvivesDynamicTypeScaling() {
        let text = ParagraphAttributedText.buildLine(
            kind: .text, style: .heading, isChecked: false, text: "A heading"
        )
        text.addAttribute(.font, value: UIFont.systemFont(ofSize: 52), range: NSRange(location: 0, length: text.length))

        let textView = UITextView()
        textView.attributedText = text
        let coordinator = RichTextEditor.Coordinator(page: Page())
        coordinator.textView = textView

        XCTAssertEqual(ParagraphAttributedText.parseLines(from: text).first?.style, .heading)
        XCTAssertEqual(coordinator.currentParagraphStyle(), .heading)
    }

    func testTogglingChecklistPreservesNextParagraphAndFormatting() {
        let text = ParagraphAttributedText.buildLine(
            kind: .checklist, style: .body, isChecked: false, text: "Pack lunch",
            formattingRanges: [CharacterFormat(location: 0, length: 4, bold: false, italic: false, underline: true)]
        )
        text.append(NSAttributedString(string: "\n"))
        text.append(ParagraphAttributedText.buildLine(
            kind: .text, style: .subheading, isChecked: false, text: "Before you leave"
        ))
        let textView = UITextView()
        textView.attributedText = text
        textView.selectedRange = NSRange(location: 3, length: 0)
        let coordinator = RichTextEditor.Coordinator(page: Page())
        coordinator.textView = textView

        coordinator.toggleCurrentChecklistItem()

        let lines = ParagraphAttributedText.parseLines(from: textView.attributedText)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines.first?.text, "Pack lunch")
        XCTAssertEqual(lines.first?.isChecked, true)
        XCTAssertEqual(lines.first?.formattingRanges.first?.underline, true)
        XCTAssertEqual(lines.last?.text, "Before you leave")
        XCTAssertEqual(lines.last?.style, .subheading)
    }
}
