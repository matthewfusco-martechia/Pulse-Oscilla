import SwiftUI

struct WorkspaceChatView: View {
    @Environment(AppEnvironment.self) private var environment
    @FocusState private var isComposerFocused: Bool

    @State private var selectedProvider: AgentProviderKind = .codex
    @State private var draftPrompt = ""
    @State private var customAgentCommand = ""
    @State private var requireApprovalForWrites = true
    @State private var activeSheet: WorkspaceChatSheet?

    var body: some View {
        NavigationStack {
            ZStack {
                WorkspaceChatBackground()

                WorkspaceConversationContainer(
                    messages: environment.connection.chatMessages,
                    revision: environment.connection.chatRevision,
                    isAgentRunning: environment.connection.isAgentRunning,
                    workspace: environment.connection.activeWorkspace,
                    sendSuggestion: sendSuggestion,
                    onTapOutsideComposer: {
                        isComposerFocused = false
                    }
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                WorkspaceChatToolbar(
                    workspace: environment.connection.activeWorkspace,
                    selectedProvider: $selectedProvider,
                    openMenu: { activeSheet = .conversations },
                    openSettings: { activeSheet = .tool(.settings) },
                    runAction: runQuickAction
                )
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                WorkspaceComposerView(
                    draftPrompt: $draftPrompt,
                    customAgentCommand: $customAgentCommand,
                    requireApprovalForWrites: $requireApprovalForWrites,
                    selectedProvider: $selectedProvider,
                    isFocused: $isComposerFocused,
                    isAgentRunning: environment.connection.isAgentRunning,
                    onOpenTools: { activeSheet = .tools },
                    onRunAction: runQuickAction,
                    onSend: sendDraftPrompt,
                    onStop: {
                        Task { await environment.connection.cancelActiveAgentRun() }
                    }
                )
            }
            .sheet(item: $activeSheet) { sheet in
                sheetView(sheet)
            }
        }
    }

    private func sendDraftPrompt() {
        let prompt = draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        if environment.connection.agentProviders.first(where: { $0.provider == selectedProvider })?.available == false {
            environment.connection.addChatSystemNote(
                title: "\(selectedProvider.title) is not available",
                body: "Install \(selectedProvider.title) on the Mac or choose another agent from the top menu.",
                status: .failed
            )
            return
        }

        draftPrompt = ""
        isComposerFocused = false

        Task {
            await environment.connection.runAgentChat(
                prompt: prompt,
                provider: selectedProvider,
                requireApprovalForWrites: requireApprovalForWrites,
                customCommand: customAgentCommand
            )
        }
    }

    private func sendSuggestion(_ prompt: String) {
        draftPrompt = prompt
        sendDraftPrompt()
    }

    private func runQuickAction(_ action: WorkspaceQuickAction) {
        Task {
            do {
                switch action {
                case .gitStatus:
                    environment.connection.addChatSystemNote(
                        title: "Checking git status",
                        body: "Asking the Mac for the current branch and local changes.",
                        status: .streaming
                    )
                    try await environment.connection.send(capability: .gitStatus, payload: EmptyPayload())
                case .gitDiff:
                    environment.connection.addChatSystemNote(
                        title: "Reviewing code changes",
                        body: "Loading the current diff from the repo.",
                        status: .streaming
                    )
                    try await environment.connection.send(capability: .gitDiff, payload: EmptyPayload())
                case .findPreviews:
                    environment.connection.addChatSystemNote(
                        title: "Finding local previews",
                        body: "Scanning the Mac for running dev servers.",
                        status: .streaming
                    )
                    try await environment.connection.send(capability: .previewPorts, payload: EmptyPayload())
                case .buildIOS:
                    await environment.connection.runTerminalQuickCommand(
                        title: "Building iOS app",
                        command: "xcodebuild -quiet -project apps/ios/PulseOscilla.xcodeproj -scheme PulseOscilla -destination generic/platform=iOS build"
                    )
                case .typecheck:
                    await environment.connection.runTerminalQuickCommand(
                        title: "Running typecheck",
                        command: "npm run typecheck"
                    )
                }
            } catch {
                environment.connection.addChatSystemNote(
                    title: "Action failed",
                    body: error.localizedDescription,
                    status: .failed
                )
            }
        }
    }

    @ViewBuilder
    private func sheetView(_ sheet: WorkspaceChatSheet) -> some View {
        switch sheet {
        case .conversations:
            WorkspaceSidebarSheet(
                selectedProvider: $selectedProvider,
                openTools: { activeSheet = .tools },
                openTool: { tool in activeSheet = .tool(tool) }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        case .tools:
            WorkspaceToolMenuSheet(
                selectedProvider: $selectedProvider,
                requireApprovalForWrites: $requireApprovalForWrites,
                openTool: { tool in activeSheet = .tool(tool) },
                runAction: runQuickAction
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        case .tool(let tool):
            NavigationStack {
                tool.makeView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                activeSheet = nil
                            }
                        }
                    }
            }
        }
    }
}
