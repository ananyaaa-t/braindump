import Foundation
import UIKit

/// Literal marker characters prefixed onto a paragraph's line so bullets and
/// checklists are plain text content (not separate UI controls) inside one
/// continuous UITextView. Kept out of `Paragraph.text` itself — stripped on
/// the way in/out so the rest of the app (tags, search, summaries) never
/// sees them.
enum ParagraphMarker {
    static let bullet = "•  "
    static let checklistUnchecked = "○  "
    static let checklistChecked = "●  "

    static func marker(for kind: ParagraphKind, isChecked: Bool) -> String {
        switch kind {
        case .text: return ""
        case .bullet: return bullet
        case .checklist: return isChecked ? checklistChecked : checklistUnchecked
        }
    }

    static func markerLength(for kind: ParagraphKind, isChecked: Bool) -> Int {
        (marker(for: kind, isChecked: isChecked) as NSString).length
    }

    static func stripMarker(from line: String) -> (kind: ParagraphKind, isChecked: Bool, text: String) {
        if line.hasPrefix(bullet) {
            return (.bullet, false, String(line.dropFirst(bullet.count)))
        }
        if line.hasPrefix(checklistChecked) {
            return (.checklist, true, String(line.dropFirst(checklistChecked.count)))
        }
        if line.hasPrefix(checklistUnchecked) {
            return (.checklist, false, String(line.dropFirst(checklistUnchecked.count)))
        }
        return (.text, false, line)
    }
}

enum ParagraphAttributedText {
    static let hangingIndent: CGFloat = 22
    static let checklistMarkerFontSize: CGFloat = 20

    /// A custom attribute recording which logical `ParagraphStyle` a run of
    /// text was built with, independent of the actual rendered font point
    /// size. `parseLines(from:)` (here) and `RichTextEditor`'s
    /// `currentParagraphStyle()` both used to infer style by comparing the
    /// live UIFont's `pointSize` back against `ParagraphStyle.fontSize` --
    /// that only worked because point size was otherwise a fixed, 1:1 stand-
    /// in for style. Once `font(kind:style:bold:italic:)` started scaling
    /// sizes for Dynamic Type (see below), the *rendered* point size varies
    /// with the user's system Text Size setting, so comparing it against a
    /// fixed reference would misclassify headings/subheadings as body text
    /// at any non-default text size. Tagging the style explicitly sidesteps
    /// that fragility entirely rather than trying to replicate the scaling
    /// math in two places to keep them in sync.
    static let styleAttributeKey = NSAttributedString.Key("com.athapar.braindump.paragraphStyle")

    /// Dynamic Type reference text style used to scale each `ParagraphStyle`
    /// — chosen for roughly matching visual prominence, not an exact size
    /// match, since `UIFontMetrics` scales relative to the base size passed
    /// in rather than snapping to the system's own default point sizes.
    private static func textStyle(for style: ParagraphStyle) -> UIFont.TextStyle {
        switch style {
        case .heading: return .title2
        case .subheading: return .title3
        case .body: return .body
        }
    }

    static func font(kind: ParagraphKind, style: ParagraphStyle, bold: Bool = false, italic: Bool = false) -> UIFont {
        let effectiveStyle = kind == .text ? style : .body
        let size = effectiveStyle.fontSize
        let baseName = italic ? "EBGaramond-Italic" : "EBGaramond-Regular"
        var resolved = UIFont(name: baseName, size: size) ?? .systemFont(ofSize: size)
        if bold {
            // Both bundled EB Garamond files are variable fonts with a full
            // weight range, so a heavier weight can be derived without
            // needing a separate bold font file.
            let traits = resolved.fontDescriptor.symbolicTraits.union(.traitBold)
            if let descriptor = resolved.fontDescriptor.withSymbolicTraits(traits) {
                resolved = UIFont(descriptor: descriptor, size: size)
            }
        }
        return UIFontMetrics(forTextStyle: textStyle(for: effectiveStyle)).scaledFont(for: resolved)
    }

    static func paragraphStyle(kind: ParagraphKind) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = 6
        style.paragraphSpacing = 6
        if kind != .text {
            style.headIndent = hangingIndent
            style.firstLineHeadIndent = 0
        }
        return style
    }

    static func baseAttributes(kind: ParagraphKind, style: ParagraphStyle) -> [NSAttributedString.Key: Any] {
        let effectiveStyle = kind == .text ? style : .body
        return [
            .font: font(kind: kind, style: style),
            .foregroundColor: AppUIColor.ink,
            .paragraphStyle: paragraphStyle(kind: kind),
            styleAttributeKey: effectiveStyle.rawValue,
        ]
    }

    /// Builds the full document text from the page's paragraphs.
    static func build(from paragraphs: [Paragraph]) -> NSAttributedString {
        let sorted = paragraphs.sorted { $0.sortOrder < $1.sortOrder }
        guard !sorted.isEmpty else {
            return NSAttributedString(string: "", attributes: baseAttributes(kind: .text, style: .body))
        }

        let result = NSMutableAttributedString()
        for (index, paragraph) in sorted.enumerated() {
            result.append(attributedLine(for: paragraph))
            if index < sorted.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: baseAttributes(kind: .text, style: .body)))
            }
        }
        return result
    }

    /// Same full-document rebuild as `build(from:)`, but from plain parsed
    /// line data rather than SwiftData objects — used when reformatting a
    /// live text view from its own current content.
    static func build(fromLines lines: [ParsedLine]) -> NSAttributedString {
        guard !lines.isEmpty else {
            return NSAttributedString(string: "", attributes: baseAttributes(kind: .text, style: .body))
        }

        let result = NSMutableAttributedString()
        for (index, line) in lines.enumerated() {
            result.append(buildLine(kind: line.kind, style: line.style, isChecked: line.isChecked, text: line.text, formattingRanges: line.formattingRanges))
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: baseAttributes(kind: .text, style: .body)))
            }
        }
        return result
    }

    /// Builds one line's attributed text, including strikethrough for a
    /// checked checklist item, an enlarged checkbox glyph, and any
    /// bold/italic/underline character ranges layered on top.
    static func buildLine(
        kind: ParagraphKind,
        style: ParagraphStyle,
        isChecked: Bool,
        text: String,
        formattingRanges: [CharacterFormat] = []
    ) -> NSMutableAttributedString {
        let marker = ParagraphMarker.marker(for: kind, isChecked: isChecked)
        let attrs = baseAttributes(kind: kind, style: style)
        let line = NSMutableAttributedString(string: marker + text, attributes: attrs)
        let markerLength = (marker as NSString).length
        let textLength = (text as NSString).length

        if kind == .checklist, !marker.isEmpty {
            let baseGlyphFont = UIFont(name: "EBGaramond-Regular", size: checklistMarkerFontSize) ?? .systemFont(ofSize: checklistMarkerFontSize)
            let glyphFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: baseGlyphFont)
            line.addAttribute(.font, value: glyphFont, range: NSRange(location: 0, length: 1))
        }

        if kind == .checklist && isChecked {
            let range = NSRange(location: markerLength, length: textLength)
            if range.length > 0 {
                line.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: AppUIColor.dune,
                ], range: range)
            }
        }

        for format in formattingRanges {
            let clamped = NSRange(
                location: markerLength + max(format.location, 0),
                length: min(format.length, textLength - max(format.location, 0))
            )
            guard clamped.length > 0, clamped.location + clamped.length <= line.length else { continue }

            if format.bold || format.italic {
                let styledFont = font(kind: kind, style: style, bold: format.bold, italic: format.italic)
                line.addAttribute(.font, value: styledFont, range: clamped)
            }
            if format.underline {
                line.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: clamped)
            }
        }

        return line
    }

    static func attributedLine(for paragraph: Paragraph) -> NSAttributedString {
        buildLine(kind: paragraph.kind, style: paragraph.style, isChecked: paragraph.isChecked, text: paragraph.text, formattingRanges: paragraph.formattingRanges)
    }

    struct ParsedLine {
        let kind: ParagraphKind
        let style: ParagraphStyle
        let isChecked: Bool
        let text: String
        let formattingRanges: [CharacterFormat]
    }

    /// Reads the document back into per-paragraph data, inferring style from
    /// the font size actually applied at the start of each line, and
    /// extracting bold/italic/underline runs relative to the paragraph's
    /// own text (marker prefix excluded).
    static func parseLines(from attributedText: NSAttributedString) -> [ParsedLine] {
        let nsString = attributedText.string as NSString
        var lines: [ParsedLine] = []

        guard nsString.length > 0 else {
            return [ParsedLine(kind: .text, style: .body, isChecked: false, text: "", formattingRanges: [])]
        }

        nsString.enumerateSubstrings(in: NSRange(location: 0, length: nsString.length), options: .byParagraphs) { substring, substringRange, _, _ in
            guard let substring else { return }
            let stripped = ParagraphMarker.stripMarker(from: substring)
            var style: ParagraphStyle = .body
            if stripped.kind == .text, substringRange.length > 0 {
                // Prefer the explicit style tag (works regardless of Dynamic
                // Type scaling); fall back to the old point-size comparison
                // only if some run somehow lacks the tag (e.g. text pasted
                // in from outside this attributed-string pipeline).
                if let tag = attributedText.attribute(styleAttributeKey, at: substringRange.location, effectiveRange: nil) as? String,
                   let tagged = ParagraphStyle(rawValue: tag) {
                    style = tagged
                } else if let font = attributedText.attribute(.font, at: substringRange.location, effectiveRange: nil) as? UIFont {
                    style = ParagraphStyle.allCases.first { abs($0.fontSize - font.pointSize) < 0.5 } ?? .body
                }
            }

            let markerLength = ParagraphMarker.markerLength(for: stripped.kind, isChecked: stripped.isChecked)
            let textStart = substringRange.location + markerLength
            let textLength = substringRange.length - markerLength
            var formats: [CharacterFormat] = []
            if textLength > 0 {
                attributedText.enumerateAttributes(in: NSRange(location: textStart, length: textLength), options: []) { attributes, range, _ in
                    let traits = (attributes[.font] as? UIFont)?.fontDescriptor.symbolicTraits ?? []
                    let bold = traits.contains(.traitBold)
                    let italic = traits.contains(.traitItalic)
                    let underline = (attributes[.underlineStyle] as? Int ?? 0) != 0
                    if bold || italic || underline {
                        formats.append(CharacterFormat(
                            location: range.location - textStart,
                            length: range.length,
                            bold: bold,
                            italic: italic,
                            underline: underline
                        ))
                    }
                }
            }

            lines.append(ParsedLine(kind: stripped.kind, style: style, isChecked: stripped.isChecked, text: stripped.text, formattingRanges: formats))
        }

        if lines.isEmpty {
            lines.append(ParsedLine(kind: .text, style: .body, isChecked: false, text: "", formattingRanges: []))
        }
        return lines
    }
}
