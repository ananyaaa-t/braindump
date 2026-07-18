import WidgetKit
import SwiftUI
import SwiftData

struct PageEntry: TimelineEntry {
    let date: Date
    let title: String
    let preview: String
    let colorName: String
    let isConfigured: Bool
}

struct BraindumpProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PageEntry {
        PageEntry(date: .now, title: "Braindump", preview: "your pages, at a glance", colorName: "butter", isConfigured: true)
    }

    func snapshot(for configuration: SelectPageIntent, in context: Context) async -> PageEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: SelectPageIntent, in context: Context) async -> Timeline<PageEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .after(.now.addingTimeInterval(3600)))
    }

    private func entry(for configuration: SelectPageIntent) -> PageEntry {
        guard let pageID = configuration.page?.id else {
            return PageEntry(
                date: .now,
                title: "choose a page",
                preview: "press and hold to configure",
                colorName: "paper",
                isConfigured: false
            )
        }

        let container = SharedModelContainer.make()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Page>()
        let pages = (try? context.fetch(descriptor)) ?? []

        guard let page = pages.first(where: { $0.uuid.uuidString == pageID }) else {
            return PageEntry(
                date: .now,
                title: "page not found",
                preview: "it may have been deleted",
                colorName: "paper",
                isConfigured: false
            )
        }

        return PageEntry(
            date: .now,
            title: page.title.isEmpty ? "untitled" : page.title,
            preview: NoteAnalyzer.previewLine(for: page),
            colorName: page.colorName,
            isConfigured: true
        )
    }
}

struct BraindumpWidgetEntryView: View {
    var entry: PageEntry

    private var color: Color {
        PageColor(rawValue: entry.colorName)?.color ?? .paper
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title)
                .font(AppFont.display(20))
                .foregroundStyle(.ink)
                .lineLimit(2)

            if entry.isConfigured {
                Text(entry.preview)
                    .font(AppFont.body(13))
                    .foregroundStyle(.dune)
                    .lineLimit(3)
            } else {
                Text(entry.preview)
                    .font(AppFont.body(12))
                    .foregroundStyle(.dune)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(color, for: .widget)
    }
}

struct BraindumpWidget: Widget {
    let kind: String = "BraindumpWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectPageIntent.self, provider: BraindumpProvider()) { entry in
            BraindumpWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Braindump Page")
        .description("Shows a page you choose.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    BraindumpWidget()
} timeline: {
    PageEntry(date: .now, title: "today's intentions", preview: "woke up early, felt clear.", colorName: "butter", isConfigured: true)
}
