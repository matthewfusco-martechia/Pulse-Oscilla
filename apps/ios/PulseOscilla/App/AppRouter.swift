import SwiftUI

@MainActor
struct AppView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        Group {
            if environment.connection.activeWorkspace == nil {
                PairingView()
            } else {
                WorkspaceDetailView()
            }
        }
    }
}
