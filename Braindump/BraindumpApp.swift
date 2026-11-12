import SwiftUI
import SwiftData
import UIKit

@main
struct BraindumpApp: App {
    let container = SharedModelContainer.make()

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SeedDemoData") {
            Self.seedDemoDataIfNeeded(into: container.mainContext)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                #if DEBUG
                .background(DemoPageOpener(container: container))
                #endif
        }
        .modelContainer(container)
    }

    #if DEBUG
    private static func seedDemoDataIfNeeded(into context: ModelContext) {
        do {
            guard try context.fetchCount(FetchDescriptor<Page>()) == 0 else { return }
            var order = 0
            func addPage(_ title: String, color: PageColor, lines: [(String, ParagraphKind, ParagraphStyle, Bool)]) {
                let page = Page(title: title, color: color, sortOrder: order)
                for (index, line) in lines.enumerated() {
                    let paragraph = Paragraph(text: line.0, kind: line.1, style: line.2, isChecked: line.3, sortOrder: index)
                    paragraph.page = page
                    page.paragraphs.append(paragraph)
                }
                page.tags = NoteAnalyzer.suggestedTags(for: page)
                page.updatedAt = .now.addingTimeInterval(-Double(order) * 900)
                context.insert(page)
                order += 1
            }
            addPage("Weekend plans", color: .sky, lines: [
                ("Saturday, slowly", .text, .heading, false),
                ("A little fresh air, good food, and no rushing.", .text, .body, false),
                ("Pack a picnic", .checklist, .body, false),
                ("Download the trail map", .checklist, .body, true),
                ("Charge the camera", .checklist, .body, false),
                ("Leave room for a coffee stop on the way home.", .text, .body, false)
            ])
            addPage("Reading list", color: .sage, lines: [
                ("For a quiet afternoon", .text, .subheading, false),
                ("A book of essays, a little fiction, and the recommendations I keep forgetting.", .text, .body, false),
                ("Browse the neighborhood bookshop", .checklist, .body, false)
            ])
            addPage("A little idea", color: .lilac, lines: [
                ("An idea for a shared recipe journal: less scrolling, more cooking together.", .text, .body, false),
                ("Keep the first version simple.", .bullet, .body, false)
            ])
            addPage("Today", color: .blush, lines: [
                ("Journal", .text, .heading, false),
                ("A morning walk, a good conversation, and finally making time to draw.", .text, .body, false)
            ])
            addPage("Launch checklist", color: .butter, lines: [
                ("Project to-do", .text, .subheading, false),
                ("Test editing and checklists", .checklist, .body, true),
                ("Refresh the demo", .checklist, .body, false),
                ("Invite the first testers", .checklist, .body, false)
            ])
            addPage("Things to make", color: .mist, lines: [
                ("A few creative goals for the month.", .text, .body, false),
                ("Print a tiny photo album", .bullet, .body, false),
                ("Try a new dinner recipe", .bullet, .body, false)
            ])
            try context.save()
        } catch {
            fatalError("Could not seed demo notes: \(error)")
        }
    }
    #endif
}

#if DEBUG
private struct DemoPageOpener: View {
    let container: ModelContainer
    @State private var pageToShow: Page?

    var body: some View {
        Color.clear
            .onAppear {
                guard let title = ProcessInfo.processInfo.environment["DEMO_OPEN_PAGE"] else { return }
                let context = container.mainContext
                if let pages = try? context.fetch(FetchDescriptor<Page>()) {
                    pageToShow = pages.first(where: { $0.title == title })
                }
            }
            .sheet(item: $pageToShow) { page in
                PageView(page: page)
            }
    }
}
#endif
