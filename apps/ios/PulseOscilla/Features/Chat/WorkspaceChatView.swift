import SwiftUI
import UIKit

struct WorkspaceChatView: View {
    @Environment(AppEnvironment.self) private var environment
    @FocusState private var isComposerFocused: Bool

    @State private var selectedProvider: AgentProviderKind = .codex
    @State private var composerMode: WorkspaceComposerMode = .ask
    @State private var draftPrompt = ""
    @State private var customAgentCommand = ""
    @State private var requireApprovalForWrites = true
    @State private var activeSheet: WorkspaceChatSheet?
    @State private var queuedPrompts: [QueuedWorkspacePrompt] = []

    var body: some View {
        NavigationStack {
            ZStack {
                WorkspaceChatBackground()

                WorkspaceConversationContainer(
                    conversationId: environment.connection.activeConversationId,
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
                    conversationTitle: toolbarConversationTitle,
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
                    composerMode: $composerMode,
                    isFocused: $isComposerFocused,
                    isAgentRunning: environment.connection.isAgentRunning,
                    queuedPrompts: queuedPrompts,
                    fileEntries: environment.connection.fileEntries,
                    onOpenTools: { activeSheet = .tools },
                    onRemoveQueuedPrompt: removeQueuedPrompt,
                    onEditQueuedPrompt: editQueuedPrompt,
                    onRefreshFiles: refreshComposerFiles,
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
            .onChange(of: environment.connection.isAgentRunning) { _, isRunning in
                guard !isRunning else { return }
                runNextQueuedPromptIfNeeded()
            }
            .task {
                await refreshComposerFiles()
            }
        }
    }

    private var toolbarConversationTitle: String? {
        guard let conversation = environment.connection.activeConversation else { return nil }
        let trimmed = conversation.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "New chat" else { return nil }
        return trimmed
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
        dismissKeyboard()

        let preparedPrompt = preparedPrompt(prompt)

        if environment.connection.isAgentRunning {
            queuedPrompts.append(QueuedWorkspacePrompt(
                prompt: preparedPrompt,
                provider: selectedProvider,
                requireApprovalForWrites: requireApprovalForWrites,
                customCommand: customAgentCommand
            ))
            HapticFeedback.shared.triggerImpactFeedback(style: .medium)
            return
        }

        Task {
            await environment.connection.runAgentChat(
                prompt: preparedPrompt,
                provider: selectedProvider,
                requireApprovalForWrites: requireApprovalForWrites,
                customCommand: customAgentCommand
            )
        }
    }

    private func preparedPrompt(_ prompt: String) -> String {
        guard composerMode == .plan else { return prompt }
        return """
        Create a concise implementation plan before editing. Include files you expect to touch, risks, verification steps, and wait for my approval before making code changes.

        User request:
        \(prompt)
        """
    }

    private func refreshComposerFiles() async {
        do {
            try await environment.connection.send(capability: .filesList, payload: PathPayload(path: "."))
        } catch {
            environment.connection.eventLog.append("file autocomplete refresh failed: \(error.localizedDescription)")
        }
    }

    private func removeQueuedPrompt(_ id: UUID) {
        queuedPrompts.removeAll { $0.id == id }
    }

    private func editQueuedPrompt(_ id: UUID) {
        guard let index = queuedPrompts.firstIndex(where: { $0.id == id }) else { return }
        let queued = queuedPrompts.remove(at: index)
        draftPrompt = queued.prompt
        selectedProvider = queued.provider
        requireApprovalForWrites = queued.requireApprovalForWrites
        customAgentCommand = queued.customCommand
        isComposerFocused = true
        HapticFeedback.shared.triggerImpactFeedback(style: .light)
    }

    private func runNextQueuedPromptIfNeeded() {
        guard !environment.connection.isAgentRunning, !queuedPrompts.isEmpty else { return }
        let next = queuedPrompts.removeFirst()
        Task {
            await environment.connection.runAgentChat(
                prompt: next.prompt,
                provider: next.provider,
                requireApprovalForWrites: next.requireApprovalForWrites,
                customCommand: next.customCommand
            )
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
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
