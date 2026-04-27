import SwiftUI

@main
struct PulseOscillaApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(environment)
        }
    }
}

