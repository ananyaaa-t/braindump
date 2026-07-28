import Foundation
import NaturalLanguage
import FoundationModels

enum NoteTag: String, CaseIterable, Identifiable {
    case toDo = "to-do"
    case idea
    case project
    case journal
    case goal

    var id: String { rawValue }
}

/// Structured output schema for `NoteAnalyzer.generativeTags`. Constrains the
/// model to 1-2 tags drawn from the same vocabulary as `NoteTag`, so callers
/// can treat generated and keyword-heuristic tags interchangeably.
@available(iOS 26.0, *)
@Generable
struct GeneratedTags {
    @Guide(
        description: "The 1-2 tags that best classify this note.",
        .count(1...2),
        .element(.anyOf(["to-do", "idea", "project", "journal", "goal"]))
    )
    var tags: [String]
}

enum NoteAnalyzer {
    private static let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)

    static func suggestedTags(for page: Page, limit: Int = 2) -> [String] {
        let paragraphs = page.paragraphs.sorted { $0.sortOrder < $1.sortOrder }
        let text = ([page.title] + paragraphs.map(\.text)).joined(separator: " ").lowercased()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        var matched: [NoteTag] = []

        if paragraphs.contains(where: { $0.kind == .checklist }) {
            matched.append(.toDo)
        }
        if ["idea", "what if", "concept", "brainstorm", "thought:"].contains(where: text.contains) {
            matched.append(.idea)
        }
        if ["deadline", "launch", "milestone", "roadmap", "ship", "build the"].contains(where: text.contains) {
            matched.append(.project)
        }
        if ["today", "woke up", "felt", "grateful", "dear diary"].contains(where: text.contains) {
            matched.append(.journal)
        }
        if ["goal", "intention", "trying to", "resolution"].contains(where: text.contains) {
            matched.append(.goal)
        }

        return Array(matched.prefix(limit)).map(\.rawValue)
    }

    /// Extractive 1-2 sentence summary: scores each paragraph by how many of
    /// its words recur elsewhere on the page (a simple frequency-based
    /// extractive summarization heuristic), then returns the top 1-2 in their
    /// original reading order. This surfaces the page's actual topic instead
    /// of just concatenating the first couple of lines.
    static func summary(for page: Page) -> String? {
        let lines = page.paragraphs
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }
        guard lines.count > 2 else {
            return lines.joined(separator: ". ")
        }

        let ranked = Set(rankedByRelevance(lines).prefix(2))
        let ordered = lines.filter { ranked.contains($0) }
        return ordered.joined(separator: ". ")
    }

    private static let summaryStopwords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "to", "of", "in", "on", "for", "is", "it",
        "this", "that", "with", "as", "at", "i", "i'm", "im", "my", "me", "be", "are", "was"
    ]

    private static func rankedByRelevance(_ lines: [String]) -> [String] {
        var frequency: [String: Int] = [:]
        for line in lines {
            for word in words(in: line) where !summaryStopwords.contains(word) {
                frequency[word, default: 0] += 1
            }
        }

        let scored = lines.map { line -> (String, Double) in
            let lineWords = words(in: line).filter { !summaryStopwords.contains($0) }
            guard !lineWords.isEmpty else { return (line, 0) }
            let score = lineWords.reduce(0.0) { $0 + Double(frequency[$1] ?? 0) } / Double(lineWords.count)
            return (line, score)
        }
        return scored.sorted { $0.1 > $1.1 }.map(\.0)
    }

    private static func words(in text: String) -> [String] {
        // Lemmatize so word forms like "run"/"running"/"runs" count toward the
        // same topic instead of splitting the frequency signal between them.
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        var result: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma) { tag, range in
            let word = tag?.rawValue.lowercased() ?? String(text[range]).lowercased()
            result.append(word)
            return true
        }
        return result
    }

    static func previewLine(for page: Page) -> String {
        let lines = page.paragraphs
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = lines.first else { return "Empty page" }
        if lines.count > 1, first.count < 18 {
            return lines[1]
        }
        return first
    }

    /// Cosine distance (lower = more similar) between a page's content and a
    /// search query, using an on-device sentence embedding. Returns nil if
    /// the embedding model or its assets aren't available — callers should
    /// fall back to plain substring search in that case.
    static func searchDistance(page: Page, query: String) -> Double? {
        guard let sentenceEmbedding else { return nil }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return nil }

        let combined = ([page.title] + page.paragraphs.map(\.text)).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !combined.isEmpty else { return nil }

        let distance = sentenceEmbedding.distance(between: combined, and: trimmedQuery, distanceType: .cosine)
        return distance.isFinite ? distance : nil
    }

    /// Generates a real 1-2 sentence overview using Apple's on-device
    /// Foundation Models (Apple Intelligence), when available. Returns nil on
    /// unsupported OS versions, ineligible devices, or if generation fails for
    /// any reason — callers should fall back to `summary(for:)` in that case.
    @available(iOS 26.0, *)
    static func generativeOverview(for page: Page) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let content = ([page.title] + page.paragraphs
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.text))
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }

        let session = LanguageModelSession(
            instructions: """
            You summarize short personal notes in 1-2 plain, factual sentences. \
            No preamble, no restating that it's a summary, no markdown.
            """
        )

        do {
            let response = try await session.respond(to: "Summarize this note:\n\n\(content)")
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    /// Generates 1-2 structured tags using Apple's on-device Foundation
    /// Models, constrained to the same vocabulary as the keyword-based
    /// `suggestedTags(for:)`. Returns nil on unsupported OS versions,
    /// ineligible devices, or if generation fails for any reason — callers
    /// should fall back to `suggestedTags(for:)` in that case.
    @available(iOS 26.0, *)
    static func generativeTags(for page: Page) async -> [String]? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let content = ([page.title] + page.paragraphs
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.text))
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }

        let session = LanguageModelSession(
            instructions: """
            You classify short personal notes into 1-2 tags from a fixed set: \
            to-do, idea, project, journal, goal. Pick only tags that clearly \
            apply; don't force a fit.
            """
        )

        do {
            let response = try await session.respond(
                to: "Classify this note:\n\n\(content)",
                generating: GeneratedTags.self
            )
            let tags = response.content.tags
            return tags.isEmpty ? nil : tags
        } catch {
            return nil
        }
    }
}
