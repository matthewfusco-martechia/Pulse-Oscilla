import SwiftUI

struct WorkspaceComposerView: View {
    @Binding var draftPrompt: String
    @Binding var customAgentCommand: String
    @Binding var requireApprovalForWrites: Bool
    @Binding var selectedProvider: AgentProviderKind
    var isFocused: FocusState<Bool>.Binding

    let isAgentRunning: Bool
    let onOpenTools: () -> Void
    let onRunAction: (WorkspaceQuickAction) -> Void
    let onSend: () -> Void
    let onStop: () -> Void
    @State private var inputHeight: CGFloat = 48

    private var canSend: Bool {
        !draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            if selectedProvider == .custom {
                TextField("Custom agent command, for example: my-agent --json", text: $customAgentCommand)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(AppFont.mono(.caption))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemFill).opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 12)
            }

            VStack(spacing: 0) {
                if showsCommandPanel {
                    WorkspaceComposerCommandPanel(
                        query: commandQuery,
                        select: applyCommand
                    )
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                WorkspaceComposerInputTextView(
                    text: $draftPrompt,
                    measuredHeight: $inputHeight,
                    isFocused: isFocused,
                    placeholder: "Ask anything... @files, $skills, /commands",
                    onSubmit: onSend
                )
                .frame(height: inputHeight, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture {
                    isFocused.wrappedValue = true
                }

                WorkspaceComposerBottomBar(
                    selectedProvider: $selectedProvider,
                    requireApprovalForWrites: $requireApprovalForWrites,
                    isAgentRunning: isAgentRunning,
                    canSend: canSend,
                    onOpenTools: onOpenTools,
                    onSend: onSend,
                    onStop: onStop
                )
            }
            .adaptiveGlass(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 12)
        }
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var showsCommandPanel: Bool {
        draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/")
    }

    private var commandQuery: String {
        draftPrompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .dropFirst()
            .lowercased()
            .description
    }

    private func applyCommand(_ command: WorkspaceComposerCommand) {
        if let action = command.quickAction {
            HapticFeedback.shared.triggerImpactFeedback(style: .light)
            draftPrompt = ""
            isFocused.wrappedValue = false
            onRunAction(action)
            return
        }

        HapticFeedback.shared.triggerImpactFeedback(style: .light)
        draftPrompt = command.prompt
        isFocused.wrappedValue = true
    }
}

private struct WorkspaceComposerCommandPanel: View {
    let query: String
    let select: (WorkspaceComposerCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(filteredCommands) { command in
                Button {
                    select(command)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: command.symbol)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.blue)
                            .frame(width: 22, height: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(command.title)
                                .font(AppFont.caption(weight: .bold))
                                .foregroundStyle(.primary)
                            Text(command.subtitle)
                                .font(AppFont.caption2())
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemFill).opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .workspaceGlass(cornerRadius: 18)
    }

    private var filteredCommands: [WorkspaceComposerCommand] {
        guard !query.isEmpty else {
            return WorkspaceComposerCommand.allCases
        }

        return WorkspaceComposerCommand.allCases.filter {
            $0.title.lowercased().contains(query)
                || $0.subtitle.lowercased().contains(query)
                || $0.name.contains(query)
        }
    }
}

private enum WorkspaceComposerCommand: String, CaseIterable, Identifiable {
    case review
    case plan
    case explain
    case status
    case diff
    case build
    case preview

    var id: String { rawValue }
    var name: String { rawValue }

    var title: String {
        switch self {
        case .review:
            "/review"
        case .plan:
            "/plan"
        case .explain:
            "/explain"
        case .status:
            "/status"
        case .diff:
            "/diff"
        case .build:
            "/build"
        case .preview:
            "/preview"
        }
    }

    var subtitle: String {
        switch self {
        case .review:
            "Ask the agent to inspect current changes."
        case .plan:
            "Ask for a safe implementation plan before edits."
        case .explain:
            "Get a plain-English repo walkthrough."
        case .status:
            "Check the current git status."
        case .diff:
            "Load the current code diff."
        case .build:
            "Run the iOS build from the Mac."
        case .preview:
            "Find running localhost previews."
        }
    }

    var symbol: String {
        switch self {
        case .review:
            "text.badge.checkmark"
        case .plan:
            "checklist"
        case .explain:
            "book"
        case .status:
            "point.3.connected.trianglepath.dotted"
        case .diff:
            "plus.forwardslash.minus"
        case .build:
            "hammer"
        case .preview:
            "safari"
        }
    }

    var prompt: String {
        switch self {
        case .review:
            "Review the current git diff. Call out bugs, risky changes, missing tests, and the smallest safe fixes."
        case .plan:
            "Create a concise implementation plan before editing. Include the files you expect to touch, risks, verification steps, and wait for my approval before making code changes."
        case .explain:
            "Explain this repository in plain English. Focus on what the app does, how the host bridge works, and what I should try next."
        case .status, .diff, .build, .preview:
            ""
        }
    }

    var quickAction: WorkspaceQuickAction? {
        switch self {
        case .status:
            .gitStatus
        case .diff:
            .gitDiff
        case .build:
            .buildIOS
        case .preview:
            .findPreviews
        case .review, .plan, .explain:
            nil
        }
    }
}

private struct WorkspaceComposerBottomBar: View {
    @Environment(AppEnvironment.self) private var environment

    @Binding var selectedProvider: AgentProviderKind
    @Binding var requireApprovalForWrites: Bool

    let isAgentRunning: Bool
    let canSend: Bool
    let onOpenTools: () -> Void
    let onSend: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpenTools) {
                Image(systemName: "plus")
                    .font(AppFont.subheadline())
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Open tools")

            providerMenu
            approvalMenu

            Spacer(minLength: 0)

            Button {
            } label: {
                    Image(systemName: "mic")
                    .font(AppFont.subheadline())
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(true)
            .accessibilityLabel("Voice input coming soon")

            if isAgentRunning {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(AppFont.caption(weight: .bold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(width: 32, height: 32)
                        .background(Color(.label), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop agent")
            } else {
                Button {
                    HapticFeedback.shared.triggerImpactFeedback(style: .light)
                    onSend()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(AppFont.caption(weight: .bold))
                        .foregroundStyle(sendIconColor)
                        .frame(width: 32, height: 32)
                        .background(sendBackgroundColor, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend || selectedProviderUnavailable)
                .accessibilityLabel("Send message")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    private var providerMenu: some View {
        Menu {
            ForEach(AgentProviderKind.allCases) { provider in
                let availability = availability(for: provider)
                Button {
                    HapticFeedback.shared.triggerImpactFeedback(style: .light)
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
        } label: {
            HStack(spacing: 5) {
                Image(systemName: selectedProvider.symbol)
                    .font(.caption2.weight(.bold))
                Text(selectedProvider.shortTitle)
                    .font(AppFont.caption(weight: .semibold))
                    .strikethrough(selectedProviderUnavailable)
                Image(systemName: "chevron.down")
                    .font(AppFont.system(size: 8, weight: .bold))
            }
            .foregroundStyle(selectedProviderUnavailable ? .red : .secondary)
            .contentShape(Capsule())
        }
    }

    private var approvalMenu: some View {
        Menu {
            Toggle("Ask before writing files", isOn: $requireApprovalForWrites)
            Text(requireApprovalForWrites ? "The agent asks before sensitive changes." : "The agent may write files directly.")
        } label: {
            HStack(spacing: 5) {
                Image(systemName: requireApprovalForWrites ? "lock" : "lock.open")
                    .font(.caption2.weight(.bold))
                Text(requireApprovalForWrites ? "Ask" : "Auto")
                    .font(AppFont.caption(weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(AppFont.system(size: 8, weight: .bold))
            }
            .foregroundStyle(.secondary)
            .contentShape(Capsule())
        }
    }

    private var sendIconColor: Color {
        canSend ? Color(.systemBackground) : Color(.systemGray2)
    }

    private var sendBackgroundColor: Color {
        canSend && !selectedProviderUnavailable ? Color(.label) : Color(.systemGray5)
    }

    private var selectedProviderUnavailable: Bool {
        availability(for: selectedProvider)?.available == false
    }

    private func availability(for provider: AgentProviderKind) -> AgentAvailabilityPayload? {
        environment.connection.agentProviders.first { $0.provider == provider }
    }
}
