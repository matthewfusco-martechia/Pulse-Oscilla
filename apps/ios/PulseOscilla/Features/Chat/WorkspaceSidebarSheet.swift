import SwiftUI

struct WorkspaceSidebarSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedProvider: AgentProviderKind
    let openTools: () -> Void
    let openTool: (WorkspaceTool) -> Void

    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var conversationPendingDeletion: WorkspaceConversation?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 4)

                WorkspaceSidebarSearchField(text: $searchText, isActive: $isSearchActive)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                Button {
                    environment.connection.startNewConversation(provider: selectedProvider)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(AppFont.system(size: 13, weight: .semibold))
                        Text("New chat")
                            .font(AppFont.body(weight: .medium))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.tertiarySystemFill).opacity(0.80), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        conversationSection(title: "Pinned", conversations: pinnedConversations)
                        conversationSection(title: "Recent", conversations: recentConversations)
                        toolsSection
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .alert(
                "Delete chat?",
                isPresented: Binding(
                    get: { conversationPendingDeletion != nil },
                    set: { if !$0 { conversationPendingDeletion = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let conversationPendingDeletion {
                        environment.connection.deleteConversation(conversationPendingDeletion.id)
                    }
                    conversationPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    conversationPendingDeletion = nil
                }
            } message: {
                Text("This removes the local chat history on this iPhone. It does not delete files on the Mac.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("Pulse Oscilla")
                    .font(AppFont.title3(weight: .medium))
                Text(environment.connection.activeWorkspace?.root ?? "Connected workspace")
                    .font(AppFont.mono(.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(AppFont.system(size: 17, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .workspaceGlass(
                        cornerRadius: 22,
                        tint: Color(.secondarySystemFill).opacity(0.72),
                        stroke: Color(.separator).opacity(0.08),
                        interactive: true
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close menu")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func conversationSection(title: String, conversations: [WorkspaceConversation]) -> some View {
        if !conversations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(AppFont.caption(weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                VStack(spacing: 6) {
                    ForEach(conversations) { conversation in
                        WorkspaceConversationRow(
                            conversation: conversation,
                            isSelected: environment.connection.activeConversationId == conversation.id,
                            select: {
                                selectedProvider = conversation.provider
                                environment.connection.selectConversation(conversation.id)
                                dismiss()
                            },
                            togglePinned: {
                                environment.connection.toggleConversationPinned(conversation.id)
                            },
                            delete: {
                                conversationPendingDeletion = conversation
                            }
                        )
                    }
                }
            }
        }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tools")
                .font(AppFont.caption(weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(WorkspaceTool.allCases) { tool in
                    Button {
                        openTool(tool)
                    } label: {
                        Label(tool.title, systemImage: tool.symbol)
                            .font(AppFont.subheadline(weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.tertiarySystemFill).opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                openTools()
            } label: {
                Label("All workspace actions", systemImage: "square.grid.2x2")
                    .font(AppFont.subheadline(weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.tertiarySystemFill).opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    private var filteredConversations: [WorkspaceConversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return environment.connection.conversations }
        return environment.connection.conversations.filter { conversation in
            conversation.title.lowercased().contains(query)
                || conversation.preview.lowercased().contains(query)
                || conversation.workspaceRoot.lowercased().contains(query)
        }
    }

    private var pinnedConversations: [WorkspaceConversation] {
        filteredConversations.filter(\.isPinned)
    }

    private var recentConversations: [WorkspaceConversation] {
        filteredConversations.filter { !$0.isPinned }
    }
}

private struct WorkspaceSidebarSearchField: View {
    @Binding var text: String
    @Binding var isActive: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(AppFont.subheadline())
                    .foregroundStyle(.secondary)

                TextField("Search conversations", text: $text)
                    .font(AppFont.subheadline())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(AppFont.subheadline())
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemFill).opacity(0.80), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if isFocused {
                Button("Cancel") {
                    text = ""
                    isFocused = false
                }
                .font(AppFont.subheadline())
                .foregroundStyle(.primary)
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .onChange(of: isFocused) { _, newValue in
            isActive = newValue
        }
    }
}

private struct WorkspaceConversationRow: View {
    let conversation: WorkspaceConversation
    let isSelected: Bool
    let select: () -> Void
    let togglePinned: () -> Void
    let delete: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(alignment: .top, spacing: 10) {
                Color.clear
                    .frame(width: 16, height: 10)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(conversation.title)
                            .font(AppFont.body())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if conversation.isPinned {
                            Image(systemName: "pin.fill")
                                .font(AppFont.caption2())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(conversation.preview)
                        .font(AppFont.footnote())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Text(relativeDate)
                        .font(AppFont.caption2())
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background {
                if isSelected {
                    Color(.tertiarySystemFill).opacity(0.80)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                togglePinned()
            } label: {
                Label(conversation.isPinned ? "Unpin" : "Pin", systemImage: "pin")
            }

            Button(role: .destructive) {
                delete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: conversation.updatedAt, relativeTo: Date())
    }
}
