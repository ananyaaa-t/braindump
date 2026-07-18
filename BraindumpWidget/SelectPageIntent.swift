import AppIntents
import SwiftData

struct PageEntity: AppEntity {
    let id: String
    let title: String
    let colorName: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Page"
    static var defaultQuery = PageEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title.isEmpty ? "untitled" : title)")
    }
}

struct PageEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PageEntity] {
        let pages = fetchPages()
        return pages
            .filter { identifiers.contains($0.uuid.uuidString) }
            .map { PageEntity(id: $0.uuid.uuidString, title: $0.title, colorName: $0.colorName) }
    }

    func suggestedEntities() async throws -> [PageEntity] {
        fetchPages()
            .filter { !$0.isTrashed }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(20)
            .map { PageEntity(id: $0.uuid.uuidString, title: $0.title, colorName: $0.colorName) }
    }

    private func fetchPages() -> [Page] {
        let container = SharedModelContainer.make()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Page>()
        return (try? context.fetch(descriptor)) ?? []
    }
}

struct SelectPageIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Page"
    static var description = IntentDescription("Choose which page to show on the widget.")

    @Parameter(title: "Page")
    var page: PageEntity?
}
