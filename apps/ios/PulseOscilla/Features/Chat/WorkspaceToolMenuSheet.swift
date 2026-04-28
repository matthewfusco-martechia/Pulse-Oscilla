import SwiftUI

struct WorkspaceToolMenuSheet: View {
    @Environment(AppEnvironment.self) private var environment

    @Binding var selectedProvider: AgentProviderKind
    @Binding var requireApprovalForWrites: Bool

    let openTool: (WorkspaceTool) -> Void
    let runAction: (WorkspaceQuickAction) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    agentCard
                    toolGrid
                    quickActions
                }
                .padding(18)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("Workspace")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Control the Mac")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
            Text("Use chat for natural-language work, or jump straight into files, git, previews, processes, and terminal output.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var agentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Code agent", systemImage: selectedProvider.symbol)
                .font(.headline)
                .foregroundStyle(.primary)

            Picker("Agent", selection: $selectedProvider) {
                ForEach(AgentProviderKind.allCases) { provider in
                    Text(provider.shortTitle).tag(provider)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Ask before writing files", isOn: $requireApprovalForWrites)
                .font(.subheadline)
                .foregroundStyle(.primary)

            VStack(spacing: 6) {
                ForEach(AgentProviderKind.allCases) { provider in
                    let availability = availability(for: provider)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(availability?.available == false ? .red : .green)
                            .frame(width: 8, height: 8)
                        Text(provider.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                        Text(availability?.available == false ? "Missing" : availability?.version ?? "Ready")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .workspaceGlass(cornerRadius: 24)
    }

    private func availability(for provider: AgentProviderKind) -> AgentAvailabilityPayload? {
        environment.connection.agentProviders.first { $0.provider == provider }
    }

    private var toolGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(WorkspaceTool.allCases) { tool in
                Button {
                    openTool(tool)
                } label: {
                    WorkspaceToolTile(tool: tool)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("One-tap actions")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(WorkspaceQuickAction.allCases) { action in
                Button {
                    runAction(action)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: action.symbol)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.blue)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(action.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .workspaceGlass(cornerRadius: 18, interactive: true)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .workspaceGlass(cornerRadius: 24)
    }
}

private struct WorkspaceToolTile: View {
    let tool: WorkspaceTool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: tool.symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(tool.tint)
                .frame(width: 42, height: 42)
                .workspaceGlass(
                    tint: tool.tint.opacity(0.10),
                    stroke: tool.tint.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )

            Text(tool.title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(tool.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
        .padding(14)
        .workspaceGlass(cornerRadius: 22, interactive: true)
    }
}
