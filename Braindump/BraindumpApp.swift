import SwiftUI
import SwiftData
import UIKit

@main
struct BraindumpApp: App {
    let container = SharedModelContainer.make()

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(container)
    }
}
