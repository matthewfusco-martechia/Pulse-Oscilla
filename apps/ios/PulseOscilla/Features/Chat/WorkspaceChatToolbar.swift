import SwiftUI

struct WorkspaceChatToolbar: ToolbarContent {
    @Environment(AppEnvironment.self) private var environment

    let workspace: WorkspaceDescriptor?
    let conversationTitle: String?
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
        Group {
            if conversationTitle == nil {
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
                    providerPill(showsChevron: true)
                }
                .accessibilityLabel("Choose code agent")
            } else {
                providerPill(showsChevron: false)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(conversationTitle ?? selectedProvider.shortTitle), \(selectedProvider.shortTitle)")
            }
        }
    }

    private func providerPill(showsChevron: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(spacing: 1) {
                if let conversationTitle {
                    Text(conversationTitle)
                        .font(AppFont.headline())
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(selectedProvider.shortTitle)
                        .font(AppFont.caption(weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(selectedProvider.shortTitle)
                        .font(AppFont.headline())
                        .lineLimit(1)
                }
            }

            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(AppFont.caption(weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .frame(minWidth: 96, maxWidth: 220)
        .padding(.horizontal, 14)
        .padding(.vertical, conversationTitle == nil ? 10 : 8)
        .adaptiveGlass(.regular, in: Capsule())
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
