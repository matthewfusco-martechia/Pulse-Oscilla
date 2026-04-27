import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case terminal
    case files
    case agents
    case git
    case processes
    case preview
    case settings

    var id: String { rawValue }

    @MainActor
    @ViewBuilder
    func makeContentView(selectedTab: Binding<AppTab>) -> some View {
        switch self {
        case .dashboard:
            DashboardView(selectedTab: selectedTab)
        case .terminal:
            TerminalView()
        case .files:
            FileBrowserView()
        case .agents:
            AgentLauncherView()
        case .git:
            GitStatusView()
        case .processes:
            ProcessListView()
        case .preview:
            PortListView()
        case .settings:
            SecuritySettingsView()
        }
    }

    @ViewBuilder
    var label: some View {
        switch self {
        case .dashboard:
            Label("Bridge", systemImage: "dot.radiowaves.left.and.right")
        case .terminal:
            Label("Terminal", systemImage: "terminal")
        case .files:
            Label("Files", systemImage: "folder")
        case .agents:
            Label("Agents", systemImage: "sparkles")
        case .git:
            Label("Git", systemImage: "point.3.connected.trianglepath.dotted")
        case .processes:
            Label("Processes", systemImage: "cpu")
        case .preview:
            Label("Preview", systemImage: "safari")
        case .settings:
            Label("Security", systemImage: "lock.shield")
        }
    }
}

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
