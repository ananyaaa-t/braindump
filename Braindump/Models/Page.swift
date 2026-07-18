import Foundation
import SwiftData

enum ParagraphKind: String, Codable {
    case text
    case bullet
    case checklist
}

/// A single character-level formatting run within a paragraph's text —
/// bold/italic/underline are independent toggles, layered on top of the
/// paragraph's kind/style. Stored separately from `Paragraph.text` (which
/// stays a plain string for search/tags/summaries) as JSON-encoded data.
struct CharacterFormat: Codable, Equatable {
    var location: Int
    var length: Int
    var bold: Bool
    var italic: Bool
    var underline: Bool

    var range: NSRange { NSRange(location: location, length: length) }
}

enum ParagraphStyle: String, Codable, CaseIterable {
    case heading
    case subheading
    case body

    var fontSize: CGFloat {
        switch self {
        case .heading: return 26
        case .subheading: return 21
        case .body: return 18
        }
    }

    var label: String {
        switch self {
        case .heading: return "Heading"
        case .subheading: return "Subheading"
        case .body: return "Body"
        }
    }
}

@Model
final class Page {
    var uuid: UUID = UUID()
    var title: String
    var colorName: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var tags: [String] = []
    var isTrashed: Bool = false
    var deletedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Paragraph.page)
    var paragraphs: [Paragraph] = []

    init(
        title: String = "",
        color: PageColor = .butter,
        sortOrder: Int = 0
    ) {
        self.title = title
        self.colorName = color.rawValue
        self.sortOrder = sortOrder
        self.createdAt = .now
        self.updatedAt = .now
    }

    var color: PageColor {
        get { PageColor(rawValue: colorName) ?? .butter }
        set { colorName = newValue.rawValue }
    }

    var previewText: String {
        NoteAnalyzer.previewLine(for: self)
    }

    static let recentlyDeletedRetentionDays = 30

    func softDelete() {
        isTrashed = true
        deletedAt = .now
    }

    func restore() {
        isTrashed = false
        deletedAt = nil
    }

    /// Days left before this page is permanently purged, or nil if not deleted.
    var daysUntilPermanentDelete: Int? {
        guard let deletedAt else { return nil }
        let expiry = Calendar.current.date(byAdding: .day, value: Page.recentlyDeletedRetentionDays, to: deletedAt) ?? deletedAt
        let days = Calendar.current.dateComponents([.day], from: .now, to: expiry).day ?? 0
        return max(days, 0)
    }
}

@Model
final class Paragraph {
    var text: String
    var kindRaw: String
    var styleRaw: String
    var isChecked: Bool
    var sortOrder: Int
    var formattingRangesData: Data?
    var page: Page?

    init(
        text: String = "",
        kind: ParagraphKind = .text,
        style: ParagraphStyle = .body,
        isChecked: Bool = false,
        sortOrder: Int = 0
    ) {
        self.text = text
        self.kindRaw = kind.rawValue
        self.styleRaw = style.rawValue
        self.isChecked = isChecked
        self.sortOrder = sortOrder
    }

    var kind: ParagraphKind {
        get { ParagraphKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    var style: ParagraphStyle {
        get { ParagraphStyle(rawValue: styleRaw) ?? .body }
        set { styleRaw = newValue.rawValue }
    }

    var formattingRanges: [CharacterFormat] {
        get {
            guard let formattingRangesData else { return [] }
            return (try? JSONDecoder().decode([CharacterFormat].self, from: formattingRangesData)) ?? []
        }
        set {
            formattingRangesData = try? JSONEncoder().encode(newValue)
        }
    }
}
