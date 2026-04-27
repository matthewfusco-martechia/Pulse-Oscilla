import SwiftUI

struct DashboardView: View {
    @Environment(AppEnvironment.self) private var environment
    @Binding var selectedTab: AppTab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeroHeader(
                    eyebrow: "Local bridge online",
                    title: "Your dev machine, in your pocket.",
                    subtitle: "Run commands, inspect files, launch agents, and preview local servers without mirroring a desktop.",
                    symbol: "bolt.horizontal.circle.fill"
                )

                if let workspace = environment.connection.activeWorkspace {
                    WorkspaceSummaryCard(workspace: workspace, state: environment.connection.state)
                }

                if let message = environment.connection.lastErrorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Last Connection Error", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.red)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .oscillaCard()
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 14)], spacing: 14) {
                    DashboardTile(title: "Terminal", subtitle: "Shell + streaming output", symbol: "terminal", tint: OscillaPalette.ink) {
                        selectedTab = .terminal
                    }
                    DashboardTile(title: "AI Agents", subtitle: "Run Codex, Claude, OpenCode", symbol: "sparkles", tint: OscillaPalette.ember) {
                        selectedTab = .agents
                    }
                    DashboardTile(title: "Files", subtitle: "Browse, edit, diff", symbol: "folder", tint: OscillaPalette.moss) {
                        selectedTab = .files
                    }
                    DashboardTile(title: "Previews", subtitle: "Localhost awareness", symbol: "safari", tint: .blue) {
                        selectedTab = .preview
                    }
                }

                EventConsoleView(events: environment.connection.eventLog)
            }
            .padding()
            .padding(.top, 8)
        }
        .oscillaBackground()
        .navigationTitle("Bridge")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                WorkspaceStatusPill(
                    workspace: environment.connection.activeWorkspace,
                    state: environment.connection.state
                )
            }
        }
    }
}

private struct WorkspaceSummaryCard: View {
    let workspace: WorkspaceDescriptor
    let state: BridgeConnection.State

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(workspace.name)
                        .font(.title2.bold())
                    Text(workspace.root)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Label("Secure", systemImage: "lock.shield.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
            }

            HStack(spacing: 10) {
                MetricPill(title: "Transport", value: "WebSocket")
                MetricPill(title: "Mode", value: "Local-first")
                MetricPill(title: "State", value: stateLabel)
            }
        }
        .oscillaCard()
    }

    private var stateLabel: String {
        switch state {
        case .connected:
            "Connected"
        case .pairing:
            "Pairing"
        case .idle:
            "Idle"
        case .failed:
            "Error"
        }
    }
}

private struct DashboardTile: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(title)
                    .font(.headline)
                    .foregroundStyle(OscillaPalette.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .oscillaCard()
        }
        .buttonStyle(.plain)
    }
}

private struct MetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white.opacity(0.38), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
