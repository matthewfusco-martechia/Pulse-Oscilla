import SwiftUI

struct WorkspaceChatToolbar: ToolbarContent {
    @Environment(AppEnvironment.self) private var environment

    let workspace: WorkspaceDescriptor?
    @Binding var selectedProvider: AgentProviderKind
    let openMenu: () -> Void
    let openSettings: () -> Void
    let runAction: (WorkspaceQuickAction) -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: openMenu) {
                Image(systemName: "line.3.horizontal")
                    .font(AppFont.system(size: 17, weight: .regular))
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .adaptiveToolbarItem(in: Circle())
            .accessibilityLabel("Open workspace menu")
        }

        ToolbarItem(placement: .principal) {
            providerMenu
        }

        ToolbarItem(placement: .topBarTrailing) {
            quickActionMenu
        }
    }

    private var providerMenu: some View {
        Menu {
            Section("Code agent") {
                ForEach(AgentProviderKind.allCases) { provider in
                    let availability = availability(for: provider)
                    Button {
                        selectedProvider = provider
                    } label: {
                        if selectedProvider == provider {
                            Label(provider.title, systemImage: "checkmark")
                        } else {
                            Label(provider.title, systemImage: provider.symbol)
                        }
                    }
                    .disabled(availability?.available == false)

                    if availability?.available == false {
                        Text(availability?.reason ?? "\(provider.title) is not installed")
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selectedProvider.symbol)
                    .font(AppFont.system(size: 16, weight: .medium))
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(selectedProvider.shortTitle)
                        .font(AppFont.headline())
                        .lineLimit(1)
                    Text(providerSubtitle)
                        .font(AppFont.caption(weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down")
                    .font(AppFont.caption(weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .adaptiveGlass(.regular, in: Capsule())
        }
        .accessibilityLabel("Choose code agent")
    }

    private var quickActionMenu: some View {
        Menu {
            Section("Run on Mac") {
                ForEach(WorkspaceQuickAction.allCases) { action in
                    Button {
                        runAction(action)
                    } label: {
                        Label(action.title, systemImage: action.symbol)
                    }
                }
            }

            Section {
                Button(action: openSettings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(AppFont.system(size: 17, weight: .bold))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .adaptiveToolbarItem(in: Circle())
        .accessibilityLabel("Open quick actions")
    }

    private var providerSubtitle: String {
        if availability(for: selectedProvider)?.available == false {
            return "Not installed"
        }
        return "Code agent"
    }

    private func availability(for provider: AgentProviderKind) -> AgentAvailabilityPayload? {
        environment.connection.agentProviders.first { $0.provider == provider }
    }
}
