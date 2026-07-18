import SwiftUI
import UIKit
import SwiftData

/// Shared handle so the page's "Aa" format button (outside the represented
/// UIView) can tell the editor to restyle whatever paragraph the cursor is
/// currently in.
@MainActor
final class RichTextEditorController: ObservableObject {
    fileprivate weak var coordinator: RichTextEditor.Coordinator?

    // Selection changes happen purely on the UIKit side and never touch the
    // SwiftData model, so nothing else would tell SwiftUI to re-render
    // PageView and refresh the "Aa" menu's disabled state. This has to be
    // @Published and pushed from textViewDidChangeSelection, or the
    // Bold/Italic/Underline buttons get stuck showing whatever hasSelection
    // was at first render (usually permanently disabled).
    @Published var hasSelection: Bool = false

    func apply(kind: ParagraphKind, style: ParagraphStyle) {
        coordinator?.applyFormat(kind: kind, style: style)
    }

    func currentKind() -> ParagraphKind {
        coordinator?.currentParagraphKind() ?? .text
    }

    func currentStyle() -> ParagraphStyle {
        coordinator?.currentParagraphStyle() ?? .body
    }

    func toggleCurrentChecklistItem() {
        coordinator?.toggleCurrentChecklistItem()
    }

    func toggleBold() {
        coordinator?.applyCharacterStyle(bold: true)
    }

    func toggleItalic() {
        coordinator?.applyCharacterStyle(italic: true)
    }

    func toggleUnderline() {
        coordinator?.applyCharacterStyle(underline: true)
    }

    func currentBold() -> Bool {
        coordinator?.currentCharacterTraits().bold ?? false
    }

    func currentItalic() -> Bool {
        coordinator?.currentCharacterTraits().italic ?? false
    }

    func currentUnderline() -> Bool {
        coordinator?.currentCharacterTraits().underline ?? false
    }
}

/// A single continuous rich-text surface for a page's content. Bullets,
/// checklists, and heading/subheading/body are paragraph-level formatting
/// within one UITextView — not separate SwiftUI controls — so Return and
/// Backspace behave with normal, reliable native text-editing semantics
/// instead of fighting SwiftUI's per-field TextField quirks.
struct RichTextEditor: UIViewRepresentable {
    @Bindable var page: Page
    var controller: RichTextEditorController

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(page: page)
        coordinator.controller = controller
        controller.coordinator = coordinator
        return coordinator
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.attributedText = ParagraphAttributedText.build(from: page.paragraphs)
        textView.tintColor = UIColor(Color.ink)

        context.coordinator.textView = textView

        // A non-scrolling UITextView sitting inside a SwiftUI ScrollView
        // fights the ScrollView's own pan gesture for every touch-and-drag —
        // without this, the outer ScrollView usually wins, so a user's
        // attempt to drag out a text selection just scrolls the page
        // instead. Deferred a tick since the view isn't in the hierarchy
        // (no superview to walk up from) at this exact point yet.
        DispatchQueue.main.async {
            guard let scrollView = Self.findAncestorScrollView(of: textView) else { return }
            for recognizer in textView.gestureRecognizers ?? [] {
                scrollView.panGestureRecognizer.require(toFail: recognizer)
            }
        }

        return textView
    }

    private static func findAncestorScrollView(of view: UIView) -> UIScrollView? {
        var current = view.superview
        while let candidate = current {
            if let scrollView = candidate as? UIScrollView {
                return scrollView
            }
            current = candidate.superview
        }
        return nil
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.page = page
        // Only rebuild the whole document from the model when it changed for
        // a reason other than this view's own typing (e.g. color/tag sheet
        // edits elsewhere) — otherwise we'd fight the user's cursor. Also
        // skip while a sync is still in flight (deferred to the next run
        // loop tick) — rebuilding from the model in that window would
        // clobber the edit with stale data that hasn't landed yet.
        if !uiView.isFirstResponder, !context.coordinator.isSyncPending,
           context.coordinator.lastSyncedUpdatedAt != page.updatedAt {
            uiView.attributedText = ParagraphAttributedText.build(from: page.paragraphs)
            context.coordinator.lastSyncedUpdatedAt = page.updatedAt
            uiView.invalidateIntrinsicContentSize()
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var page: Page
        weak var textView: UITextView?
        weak var controller: RichTextEditorController?
        var lastSyncedUpdatedAt: Date
        var isSyncPending = false

        init(page: Page) {
            self.page = page
            self.lastSyncedUpdatedAt = page.updatedAt
        }

        func textViewDidChange(_ textView: UITextView) {
            syncParagraphs(from: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            controller?.hasSelection = textView.selectedRange.length > 0
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let nsString = textView.attributedText.string as NSString

            if text == "\n" {
                return handleReturn(textView: textView, range: range, nsString: nsString)
            }
            if text.isEmpty && range.length > 0 {
                return handleDeletion(textView: textView, range: range, nsString: nsString)
            }
            return true
        }

        // MARK: - Return key: continue or exit a bullet/checklist line

        private func handleReturn(textView: UITextView, range: NSRange, nsString: NSString) -> Bool {
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: range.location, length: 0))
            let lineText = nsString.substring(with: paragraphRange)
            let stripped = ParagraphMarker.stripMarker(from: lineText)

            guard stripped.kind != .text else { return true }
            guard let mutable = textView.attributedText.mutableCopy() as? NSMutableAttributedString else { return true }

            if stripped.text.trimmingCharacters(in: .whitespaces).isEmpty {
                // Return on an empty bullet/checklist line exits list mode.
                let attrs = ParagraphAttributedText.baseAttributes(kind: .text, style: .body)
                mutable.replaceCharacters(in: paragraphRange, with: NSAttributedString(string: "", attributes: attrs))
                textView.attributedText = mutable
                textView.selectedRange = NSRange(location: paragraphRange.location, length: 0)
                syncParagraphs(from: textView)
                return false
            }

            // Continue the list on the next line.
            let newLine = ParagraphAttributedText.buildLine(kind: stripped.kind, style: .body, isChecked: false, text: "")
            let insertion = NSMutableAttributedString(string: "\n")
            insertion.append(newLine)
            mutable.replaceCharacters(in: range, with: insertion)
            textView.attributedText = mutable
            let newLocation = range.location + insertion.length
            textView.selectedRange = NSRange(location: newLocation, length: 0)
            syncParagraphs(from: textView)
            return false
        }

        // MARK: - Backspace at the start of a marker: strip formatting first

        private func handleDeletion(textView: UITextView, range: NSRange, nsString: NSString) -> Bool {
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: range.location, length: 0))
            let lineText = nsString.substring(with: paragraphRange)
            let stripped = ParagraphMarker.stripMarker(from: lineText)
            guard stripped.kind != .text else { return true }

            let markerLength = ParagraphMarker.markerLength(for: stripped.kind, isChecked: stripped.isChecked)
            let deletionEndInLine = (range.location - paragraphRange.location) + range.length
            guard deletionEndInLine <= markerLength else { return true }

            guard let mutable = textView.attributedText.mutableCopy() as? NSMutableAttributedString else { return true }
            let attrs = ParagraphAttributedText.baseAttributes(kind: .text, style: .body)
            mutable.replaceCharacters(in: paragraphRange, with: NSAttributedString(string: stripped.text, attributes: attrs))
            textView.attributedText = mutable
            textView.selectedRange = NSRange(location: paragraphRange.location, length: 0)
            syncParagraphs(from: textView)
            return false
        }

        // MARK: - "Aa" format menu

        func currentParagraphKind() -> ParagraphKind {
            guard let textView else { return .text }
            let nsString = textView.attributedText.string as NSString
            let paragraphRange = nsString.paragraphRange(for: textView.selectedRange)
            let lineText = nsString.substring(with: paragraphRange)
            return ParagraphMarker.stripMarker(from: lineText).kind
        }

        func currentParagraphStyle() -> ParagraphStyle {
            guard let textView else { return .body }
            let nsString = textView.attributedText.string as NSString
            let paragraphRange = nsString.paragraphRange(for: textView.selectedRange)
            guard paragraphRange.length > 0,
                  let font = textView.attributedText.attribute(.font, at: paragraphRange.location, effectiveRange: nil) as? UIFont else {
                return .body
            }
            return ParagraphStyle.allCases.first { abs($0.fontSize - font.pointSize) < 0.5 } ?? .body
        }

        func toggleCurrentChecklistItem() {
            guard let textView else { return }
            let nsString = textView.attributedText.string as NSString
            let paragraphRange = nsString.paragraphRange(for: textView.selectedRange)
            let lineText = nsString.substring(with: paragraphRange)
            let stripped = ParagraphMarker.stripMarker(from: lineText)
            guard stripped.kind == .checklist else { return }

            let newChecked = !stripped.isChecked
            let replacement = ParagraphAttributedText.buildLine(kind: .checklist, style: .body, isChecked: newChecked, text: stripped.text)

            guard let mutable = textView.attributedText.mutableCopy() as? NSMutableAttributedString else { return }
            mutable.replaceCharacters(in: paragraphRange, with: replacement)
            textView.attributedText = mutable
            syncParagraphs(from: textView)
        }

        func applyFormat(kind: ParagraphKind, style: ParagraphStyle) {
            guard let textView else { return }
            let nsString = textView.attributedText.string as NSString
            let paragraphRange = nsString.paragraphRange(for: textView.selectedRange)

            // Figure out which paragraph (by index) the cursor is in, then
            // rebuild the *entire* document from parsed line data with that
            // one paragraph's kind/style changed — this is the same
            // full-rebuild path already confirmed to render mixed sizes
            // correctly at initial load, instead of an in-place
            // NSMutableAttributedString edit that wasn't visually updating.
            var lines = ParagraphAttributedText.parseLines(from: textView.attributedText)
            let paragraphStarts = paragraphStartOffsets(in: nsString)
            guard let targetIndex = paragraphStarts.lastIndex(where: { $0 <= paragraphRange.location }),
                  targetIndex < lines.count else { return }

            let existingLine = lines[targetIndex]
            let newChecked = kind == .checklist ? existingLine.isChecked : false
            lines[targetIndex] = ParagraphAttributedText.ParsedLine(
                kind: kind,
                style: style,
                isChecked: newChecked,
                text: existingLine.text,
                formattingRanges: existingLine.formattingRanges
            )

            let rebuilt = ParagraphAttributedText.build(fromLines: lines)
            textView.attributedText = rebuilt

            let markerLength = ParagraphMarker.markerLength(for: kind, isChecked: newChecked)
            let newCursor = paragraphStarts[targetIndex] + markerLength + (existingLine.text as NSString).length
            textView.selectedRange = NSRange(location: min(newCursor, rebuilt.length), length: 0)

            syncParagraphs(from: textView)
        }

        /// Toggles bold/italic/underline. With an active selection, restyles
        /// the selected text directly. With no selection (just a cursor),
        /// toggles textView.typingAttributes instead, so subsequently typed
        /// characters come out styled — Word/Notes-style "turn on Bold, then
        /// keep typing." This is safe here because typing itself never
        /// touches textView.attributedText directly (only the deferred
        /// SwiftData sync does, and only via typingAttributes-respecting
        /// user input), so the toggle survives normal typing.
        func applyCharacterStyle(bold: Bool? = nil, italic: Bool? = nil, underline: Bool? = nil) {
            guard let textView else { return }
            if textView.selectedRange.length > 0 {
                applyCharacterStyleToSelection(bold: bold, italic: italic, underline: underline)
            } else {
                applyCharacterStyleToTypingAttributes(bold: bold, italic: italic, underline: underline)
            }
        }

        private func applyCharacterStyleToSelection(bold: Bool?, italic: Bool?, underline: Bool?) {
            guard let textView else { return }
            let selectedRange = textView.selectedRange

            guard let mutable = textView.attributedText.mutableCopy() as? NSMutableAttributedString else { return }

            // Toggle based on the trait's state at the start of the
            // selection, so selecting mixed text consistently turns the
            // style ON rather than flickering between states.
            let currentFont = mutable.attribute(.font, at: selectedRange.location, effectiveRange: nil) as? UIFont
            let currentTraits = currentFont?.fontDescriptor.symbolicTraits ?? []
            let currentUnderline = (mutable.attribute(.underlineStyle, at: selectedRange.location, effectiveRange: nil) as? Int ?? 0) != 0

            let newBold = bold != nil ? !currentTraits.contains(.traitBold) : currentTraits.contains(.traitBold)
            let newItalic = italic != nil ? !currentTraits.contains(.traitItalic) : currentTraits.contains(.traitItalic)
            let newUnderline = underline != nil ? !currentUnderline : currentUnderline

            mutable.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, _ in
                let existingFont = value as? UIFont
                let size = existingFont?.pointSize ?? ParagraphStyle.body.fontSize
                let resolved = Self.resolvedFont(size: size, bold: newBold, italic: newItalic)
                mutable.addAttribute(.font, value: resolved, range: range)
            }

            if newUnderline {
                mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
            } else {
                mutable.removeAttribute(.underlineStyle, range: selectedRange)
            }

            textView.attributedText = mutable
            textView.selectedRange = selectedRange
            syncParagraphs(from: textView)
        }

        private func applyCharacterStyleToTypingAttributes(bold: Bool?, italic: Bool?, underline: Bool?) {
            guard let textView else { return }
            var attrs = textView.typingAttributes

            let currentFont = attrs[.font] as? UIFont
            let currentTraits = currentFont?.fontDescriptor.symbolicTraits ?? []
            let currentUnderline = (attrs[.underlineStyle] as? Int ?? 0) != 0

            let newBold = bold != nil ? !currentTraits.contains(.traitBold) : currentTraits.contains(.traitBold)
            let newItalic = italic != nil ? !currentTraits.contains(.traitItalic) : currentTraits.contains(.traitItalic)
            let newUnderline = underline != nil ? !currentUnderline : currentUnderline

            let size = currentFont?.pointSize ?? ParagraphStyle.body.fontSize
            attrs[.font] = Self.resolvedFont(size: size, bold: newBold, italic: newItalic)
            if newUnderline {
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            } else {
                attrs.removeValue(forKey: .underlineStyle)
            }
            textView.typingAttributes = attrs
        }

        private static func resolvedFont(size: CGFloat, bold: Bool, italic: Bool) -> UIFont {
            let baseName = italic ? "EBGaramond-Italic" : "EBGaramond-Regular"
            var resolved = UIFont(name: baseName, size: size) ?? .systemFont(ofSize: size)
            if bold {
                let traits = resolved.fontDescriptor.symbolicTraits.union(.traitBold)
                if let descriptor = resolved.fontDescriptor.withSymbolicTraits(traits) {
                    resolved = UIFont(descriptor: descriptor, size: size)
                }
            }
            return resolved
        }

        /// Current bold/italic/underline state for the "Aa" menu's
        /// checkmarks — reads the selection's start (if any) or, with just
        /// a cursor, the pending typingAttributes.
        func currentCharacterTraits() -> (bold: Bool, italic: Bool, underline: Bool) {
            guard let textView else { return (false, false, false) }
            let attrs: [NSAttributedString.Key: Any]
            if textView.selectedRange.length > 0 {
                attrs = textView.attributedText.attributes(at: textView.selectedRange.location, effectiveRange: nil)
            } else {
                attrs = textView.typingAttributes
            }
            let traits = (attrs[.font] as? UIFont)?.fontDescriptor.symbolicTraits ?? []
            let underline = (attrs[.underlineStyle] as? Int ?? 0) != 0
            return (traits.contains(.traitBold), traits.contains(.traitItalic), underline)
        }

        /// Character offset where each paragraph (split by "\n") begins.
        private func paragraphStartOffsets(in nsString: NSString) -> [Int] {
            var offsets: [Int] = [0]
            nsString.enumerateSubstrings(in: NSRange(location: 0, length: nsString.length), options: .byParagraphs) { _, range, _, _ in
                if range.location != 0 { offsets.append(range.location) }
            }
            return offsets
        }

        // MARK: - Sync back to SwiftData

        func syncParagraphs(from textView: UITextView) {
            textView.invalidateIntrinsicContentSize()
            // Parsing the text is pure/safe to do immediately, but the actual
            // SwiftData mutations below are deferred a tick — doing them
            // synchronously from within a UITextView delegate callback can
            // trigger a SwiftUI re-render that touches this same text view
            // again mid-edit, breaking typing entirely.
            let parsed = ParagraphAttributedText.parseLines(from: textView.attributedText)
            isSyncPending = true

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                defer { self.isSyncPending = false }
                let existing = self.page.paragraphs.sorted { $0.sortOrder < $1.sortOrder }

                for (index, line) in parsed.enumerated() {
                    if index < existing.count {
                        let paragraph = existing[index]
                        if paragraph.text != line.text { paragraph.text = line.text }
                        if paragraph.kind != line.kind { paragraph.kind = line.kind }
                        if paragraph.style != line.style { paragraph.style = line.style }
                        if paragraph.isChecked != line.isChecked { paragraph.isChecked = line.isChecked }
                        if paragraph.formattingRanges != line.formattingRanges { paragraph.formattingRanges = line.formattingRanges }
                        paragraph.sortOrder = index
                    } else {
                        let paragraph = Paragraph(text: line.text, kind: line.kind, style: line.style, isChecked: line.isChecked, sortOrder: index)
                        paragraph.formattingRanges = line.formattingRanges
                        paragraph.page = self.page
                        self.page.paragraphs.append(paragraph)
                    }
                }

                if existing.count > parsed.count {
                    for extra in existing[parsed.count...] {
                        self.page.modelContext?.delete(extra)
                    }
                }

                self.page.updatedAt = .now
                self.lastSyncedUpdatedAt = self.page.updatedAt
            }
        }
    }
}
