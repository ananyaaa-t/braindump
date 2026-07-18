import Foundation
import SwiftData

enum SharedModelContainer {
    static let appGroupID = "group.com.athapar.braindump"

    static func make() -> ModelContainer {
        let schema = Schema([Page.self, Paragraph.self])
        let configuration = ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupID))
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create shared ModelContainer: \(error)")
        }
    }
}
