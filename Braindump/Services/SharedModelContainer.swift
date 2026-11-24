import Foundation
import SwiftData

enum SharedModelContainer {
    static let appGroupID = "group.com.athapar.braindump"

    static func make() -> ModelContainer {
        let schema = Schema([Page.self, Paragraph.self])
        let configuration: ModelConfiguration
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["UITEST_STORE_ID"],
           let id = UUID(uuidString: value) {
            configuration = ModelConfiguration(
                "UITest-\(id.uuidString)", schema: schema,
                groupContainer: .none, cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupID))
        }
        #else
        configuration = ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupID))
        #endif
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create shared ModelContainer: \(error)")
        }
    }
}
