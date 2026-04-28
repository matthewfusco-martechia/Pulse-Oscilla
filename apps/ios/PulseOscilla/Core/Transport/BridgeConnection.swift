import Foundation
import Observation

@MainActor
@Observable
final class BridgeConnection {
    enum State: Equatable {
        case idle
        case pairing
        case connected
        case failed(String)
    }

    var state: State = .idle
    var activeWorkspace: WorkspaceDescriptor?
    var acceptedSession: PairingAcceptedPayload?
    var eventLog: [String] = []
    var terminalLines: [String] = []
    var agentLines: [String] = []
    var fileEntries: [FileEntry] = []
    var openedFile: RemoteFile?
    var gitStatusText = ""
    var gitDiffText = ""
    var gitBranchesText = ""
    var processListText = ""
    var ports: [PortDescriptor] = []
    var agentProviders: [AgentAvailabilityPayload] = []
    var conversations: [WorkspaceConversation] = []
    var activeConversation: WorkspaceConversation? {
        guard let activeConversationId else { return nil }
        return conversations.first { $0.id == activeConversationId }
    }
    var activeConversationTurns: [WorkspaceTurn] {
        if let activeConversationId,
           let conversation = conversations.first(where: { $0.id == activeConversationId }) {
            return conversation.turns
        }
        return WorkspaceTurnProjector.project(messages: chatMessages)
    }
    var activeConversationId: UUID?
    var chatMessages: [AgentChatMessage] = []
    var chatRevision = 0
    var isAgentRunning = false
    var activeAgentProvider: AgentProviderKind?
    var lastErrorMessage: String?
    var lastEndpoint: String?
    var lastHostFingerprint: String?
    var lastPairingExpiresAt: String?

    @ObservationIgnored private let pairingManager = PairingManager()
    @ObservationIgnored private let transport = WebSocketTransport()
    @ObservationIgnored private var secureSession: SecureSession?
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()
    @ObservationIgnored private let storageEncoder = JSONEncoder()
    @ObservationIgnored private let storageDecoder = JSONDecoder()
    @ObservationIgnored private var activeAgentMessageId: UUID?
    @ObservationIgnored private var activeAgentStreamId: String?
    @ObservationIgnored private var quickCommandMessageIds: [String: UUID] = [:]
    @ObservationIgnored private var commandMessageIdsByStreamId: [String: UUID] = [:]
    @ObservationIgnored private var pendingAssistantDeltaByStreamId: [String: String] = [:]
    @ObservationIgnored private var responseHapticStreamIds = Set<String>()
    @ObservationIgnored private var assistantDeltaFlushTask: Task<Void, Never>?
    @ObservationIgnored private var conversationPersistTask: Task<Void, Never>?

    func pair(rawPayload: String) async {
        state = .pairing
        do {
            let result = try await pairingManager.pair(rawPayload: rawPayload, transport: transport)
            lastEndpoint = result.payload.endpoint.absoluteString
            lastHostFingerprint = result.payload.fingerprint
            lastPairingExpiresAt = result.payload.expiresAt
            secureSession = result.secureSession
            acceptedSession = result.accepted
            activeWorkspace = WorkspaceDescriptor(
                id: result.accepted.workspaceId,
                name: result.payload.workspaceHint ?? "Workspace",
                root: result.accepted.workspaceRoot,
                gitBranch: nil
            )
            state = .connected
            eventLog.append("Connected to \(result.accepted.workspaceRoot)")
            loadConversations(workspaceRoot: result.accepted.workspaceRoot)
            ensureActiveConversation(workspaceName: result.payload.workspaceHint ?? "Workspace")
            Task { await receiveLoop() }
            Task { await refreshAgentProviders() }
        } catch {
            lastErrorMessage = error.localizedDescription
            state = .failed(error.localizedDescription)
            appendEvent("Pairing failed: \(error.localizedDescription)")
        }
    }

    func send<Payload: Encodable>(
        capability: Capability,
        streamId: String? = nil,
        payload: Payload
    ) async throws {
        guard let secureSession, let workspaceId = activeWorkspace?.id else {
            throw BridgeConnectionError.notConnected
        }
        let request = BridgeRequest(
            capability: capability,
            workspaceId: workspaceId,
            streamId: streamId,
            payload: payload
        )
        let requestData = try encoder.encode(request)
        let frame = try await secureSession.encrypt(requestData)
        let frameData = try encoder.encode(frame)
        try await transport.send(String(decoding: frameData, as: UTF8.self))
    }

    func disconnect() {
        flushPendingConversationPersist()
        Task { await transport.close() }
        secureSession = nil
        acceptedSession = nil
        activeWorkspace = nil
        state = .idle
        terminalLines.removeAll()
        agentLines.removeAll()
        fileEntries.removeAll()
        openedFile = nil
        gitStatusText = ""
        gitDiffText = ""
        gitBranchesText = ""
        processListText = ""
        ports.removeAll()
        agentProviders.removeAll()
        conversations.removeAll()
        activeConversationId = nil
        chatMessages.removeAll()
        chatRevision += 1
        isAgentRunning = false
        activeAgentProvider = nil
        activeAgentMessageId = nil
        activeAgentStreamId = nil
        quickCommandMessageIds.removeAll()
        clearStreamTracking()
    }

    func runAgentChat(
        prompt: String,
        provider: AgentProviderKind,
        requireApprovalForWrites: Bool = true,
        customCommand: String = ""
    ) async {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }
        ensureActiveConversation(workspaceName: activeWorkspace?.name ?? "Workspace", provider: provider)

        let streamId = "agent_\(UUID().uuidString)"
        chatMessages.append(AgentChatMessage(
            role: .user,
            kind: .chat,
            body: trimmedPrompt,
            provider: provider,
            streamId: streamId,
            turnId: streamId
        ))
        updateActiveConversationTitleIfNeeded(from: trimmedPrompt, provider: provider)
        activeAgentMessageId = nil
        activeAgentStreamId = streamId
        activeAgentProvider = provider
        responseHapticStreamIds.remove(streamId)
        isAgentRunning = true
        bumpChat()

        do {
            try await send(
                capability: .agentRun,
                streamId: streamId,
                payload: AgentRunPayload(
                    provider: provider,
                    prompt: trimmedPrompt,
                    mode: "interactive",
                    allowedTools: nil,
                    requireApprovalForWrites: requireApprovalForWrites,
                    customCommand: provider == .custom ? customCommand : nil
                )
            )
        } catch {
            if !markConnectionFailedIfNeeded(error) {
                markAgentFailed(error.localizedDescription)
                appendEvent("Agent run failed: \(error.localizedDescription)")
            }
        }
    }

    func cancelActiveAgentRun() async {
        guard let streamId = activeAgentStreamId, let provider = activeAgentProvider else { return }
        do {
            try await send(
                capability: .agentCancel,
                streamId: streamId,
                payload: AgentCancelPayload(provider: provider)
            )
            appendAgentWorkItem(
                streamId: streamId,
                AgentWorkItem(
                    kind: "run.completed",
                    title: "Cancel requested",
                    detail: "The host was asked to stop this run.",
                    state: .completed
                )
            )
        } catch {
            if !markConnectionFailedIfNeeded(error) {
                markAgentFailed(error.localizedDescription)
            }
        }
    }

    func respondToAgentApproval(messageId: UUID, approved: Bool) async {
        guard let index = chatMessages.firstIndex(where: { $0.id == messageId }) else { return }
        guard let streamId = chatMessages[index].streamId else {
            chatMessages[index].status = .failed
            chatMessages[index].body += "\n\nUnable to respond: this approval is missing a running stream."
            bumpChat()
            return
        }

        let provider = chatMessages[index].provider ?? activeAgentProvider ?? .codex
        chatMessages[index].status = .completed
        chatMessages[index].isStreaming = false
        chatMessages[index].deliveryState = .confirmed
        chatMessages[index].body += approved ? "\n\nApproved from iPhone." : "\n\nDenied from iPhone."
        bumpChat()

        do {
            try await send(
                capability: .agentStdin,
                streamId: streamId,
                payload: AgentInputPayload(provider: provider, data: approved ? "y\n" : "n\n")
            )
            appendTimelineMessage(
                streamId: streamId,
                role: .system,
                kind: .toolActivity,
                title: approved ? "Approval sent" : "Denied",
                body: approved ? "The Mac agent can continue." : "The Mac agent was told not to continue.",
                status: .completed
            )
        } catch {
            if !markConnectionFailedIfNeeded(error) {
                if let failedIndex = chatMessages.firstIndex(where: { $0.id == messageId }) {
                    chatMessages[failedIndex].status = .failed
                    chatMessages[failedIndex].deliveryState = .failed
                    chatMessages[failedIndex].body += "\n\nCould not send response: \(error.localizedDescription)"
                }
                bumpChat()
            }
        }
    }

    func addChatSystemNote(title: String, body: String, status: AgentChatStatus = .ready) {
        ensureActiveConversation(workspaceName: activeWorkspace?.name ?? "Workspace")
        chatMessages.append(AgentChatMessage(role: .system, title: title, body: body, status: status))
        bumpChat()
    }

    func runTerminalQuickCommand(title: String, command: String) async {
        ensureActiveConversation(workspaceName: activeWorkspace?.name ?? "Workspace")
        let streamId = "quick_\(UUID().uuidString)"
        let messageId = UUID()
        quickCommandMessageIds[streamId] = messageId
        chatMessages.append(AgentChatMessage(
            id: messageId,
            role: .system,
            title: title,
            body: "Running on the Mac:\n\(command)",
            streamId: streamId,
            status: .streaming,
            workItems: [
                AgentWorkItem(kind: "shell.output", title: "Shell command queued", detail: command)
            ]
        ))
        bumpChat()

        do {
            try await send(
                capability: .terminalCreate,
                streamId: streamId,
                payload: TerminalCreatePayload(shell: nil, cwd: ".", cols: 96, rows: 28)
            )
            try await send(
                capability: .terminalStdin,
                streamId: streamId,
                payload: TerminalInputPayload(data: "\(command)\nexit\n")
            )
        } catch {
            if !markConnectionFailedIfNeeded(error) {
                updateQuickCommand(streamId: streamId, bodyAppend: "\n\nFailed: \(error.localizedDescription)", status: .failed)
            }
        }
    }

    func refreshAgentProviders() async {
        do {
            try await send(capability: .agentProviders, payload: EmptyPayload())
        } catch {
            appendEvent("Agent provider refresh failed: \(error.localizedDescription)")
        }
    }

    func startNewConversation(provider: AgentProviderKind = .codex) {
        guard let workspace = activeWorkspace else { return }
        let conversation = WorkspaceConversation(
            title: "New chat",
            workspaceRoot: workspace.root,
            provider: provider,
            messages: welcomeMessages(workspaceName: workspace.name)
        )
        conversations.insert(conversation, at: 0)
        activeConversationId = conversation.id
        chatMessages = conversation.messages
        activeAgentMessageId = nil
        activeAgentStreamId = nil
        activeAgentProvider = nil
        isAgentRunning = false
        quickCommandMessageIds.removeAll()
        clearStreamTracking()
        persistConversations()
        bumpChatWithoutPersist()
    }

    func selectConversation(_ id: UUID) {
        guard let conversation = conversations.first(where: { $0.id == id }) else { return }
        activeConversationId = conversation.id
        chatMessages = conversation.messages
        activeAgentMessageId = nil
        activeAgentStreamId = nil
        activeAgentProvider = nil
        isAgentRunning = conversation.messages.contains { $0.status == .streaming || $0.status == .needsApproval }
        quickCommandMessageIds.removeAll()
        clearStreamTracking()
        bumpChatWithoutPersist()
    }

    func deleteConversation(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        if activeConversationId == id {
            activeConversationId = nil
            chatMessages.removeAll()
            ensureActiveConversation(workspaceName: activeWorkspace?.name ?? "Workspace")
        }
        persistConversations()
        bumpChatWithoutPersist()
    }

    func toggleConversationPinned(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].isPinned.toggle()
        conversations[index].updatedAt = Date()
        sortConversations()
        persistConversations()
    }

    func renameConversation(_ id: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].title = trimmed
        conversations[index].updatedAt = Date()
        sortConversations()
        persistConversations()
    }

    private func receiveLoop() async {
        while secureSession != nil {
            do {
                guard let secureSession else { return }
                let text = try await transport.receiveString()
                let frame = try decoder.decode(EncryptedFrame.self, from: Data(text.utf8))
                let data = try await secureSession.decrypt(frame)
                routeIncomingEnvelope(data)
            } catch {
                markConnectionFailed(
                    "Host disconnected. Start the host again, then pair with a fresh QR code."
                )
                return
            }
        }
    }

    private func routeIncomingEnvelope(_ data: Data) {
        do {
            let envelope = try decoder.decode(BridgeEnvelopeRaw.self, from: data)
            switch envelope.type {
            case "response":
                try routeResponse(envelope)
            case "event":
                try routeEvent(envelope)
            case "error":
                routeError(envelope)
            default:
                appendRawEvent(data)
            }
        } catch {
            appendRawEvent(data)
        }
    }

    private func routeResponse(_ envelope: BridgeEnvelopeRaw) throws {
        guard let capability = envelope.capability else {
            appendEvent("Response \(envelope.id)")
            return
        }

        switch capability {
        case .filesList:
            fileEntries = try decodePayload([FileEntry].self, from: envelope)
            appendEvent("Listed \(fileEntries.count) files")
        case .filesRead:
            openedFile = try decodePayload(RemoteFile.self, from: envelope)
            appendEvent("Opened \(openedFile?.path ?? "file")")
        case .filesWrite:
            let result = try decodePayload(FileWriteResult.self, from: envelope)
            openedFile = openedFile.map {
                RemoteFile(path: $0.path, name: $0.name, content: $0.content, sha256: result.sha256)
            }
            appendEvent("Wrote \(result.path)")
        case .gitStatus:
            gitStatusText = commandText(try decodePayload(CommandResult.self, from: envelope))
            appendEvent("Git status updated")
            appendToolResult(title: "Git status", body: gitStatusText.isEmpty ? "No status output." : gitStatusText)
        case .gitDiff:
            gitDiffText = commandText(try decodePayload(CommandResult.self, from: envelope))
            appendEvent("Git diff updated")
            appendToolResult(title: "Git diff", body: gitDiffText.isEmpty ? "No diff output." : gitDiffText)
        case .gitStage:
            let output = commandText(try decodePayload(CommandResult.self, from: envelope))
            appendEvent("Git stage completed")
            appendToolResult(title: "Staged changes", body: output)
        case .gitRestore:
            let output = commandText(try decodePayload(CommandResult.self, from: envelope))
            appendEvent("Git restore completed")
            appendToolResult(title: "Reverted changes", body: output)
        case .gitBranch:
            gitBranchesText = commandText(try decodePayload(CommandResult.self, from: envelope))
            appendEvent("Git branches updated")
            appendToolResult(title: "Branches", body: gitBranchesText.isEmpty ? "No branch output." : gitBranchesText)
        case .gitCommit, .gitPush, .gitPull:
            appendEvent(commandText(try decodePayload(CommandResult.self, from: envelope)))
        case .agentProviders:
            agentProviders = try decodePayload(AgentProvidersResult.self, from: envelope).providers
            appendEvent("Agent providers updated")
        case .previewPorts:
            ports = try decodePayload([PortDescriptor].self, from: envelope)
            appendEvent("Detected \(ports.count) listening ports")
            let body = ports.isEmpty
                ? "No local dev servers were detected."
                : ports.map { "\($0.url) \($0.process.map { "(\($0))" } ?? "")" }.joined(separator: "\n")
            appendToolResult(title: "Local previews", body: body)
        case .processList:
            processListText = try decodePayload(ProcessListResult.self, from: envelope).raw
            appendEvent("Process list updated")
            appendToolResult(title: "Running processes", body: processListText)
        case .processKill:
            let result = try decodePayload(ProcessKillResult.self, from: envelope)
            appendEvent("Sent \(result.signal) to pid \(result.pid)")
        case .terminalCreate:
            let result = try decodePayload(TerminalCreateResult.self, from: envelope)
            terminalLines.append("PTY attached: \(result.streamId) pid=\(result.pid)")
            if quickCommandMessageIds[result.streamId] != nil {
                updateQuickCommand(
                    streamId: result.streamId,
                    workItem: AgentWorkItem(
                        kind: "tool.started",
                        title: "Shell attached",
                        detail: "PTY pid \(result.pid)",
                        state: .completed
                    )
                )
            }
        case .agentRun:
            let result = try decodePayload(AgentRunResult.self, from: envelope)
            agentLines.append("Agent run completed: \(result.streamId)")
            finishAgentRun(streamId: result.streamId, status: .completed)
        case .workspaceList, .workspaceOpen:
            appendEvent("Workspace response received")
        default:
            appendEvent("\(capability.rawValue) completed")
        }
    }

    private func routeEvent(_ envelope: BridgeEnvelopeRaw) throws {
        guard let capability = envelope.capability else {
            appendEvent("Event \(envelope.id)")
            return
        }

        switch capability {
        case .terminalCreate:
            if let output = try? decodePayload(TerminalOutputPayload.self, from: envelope) {
                terminalLines.append(output.data)
                if let streamId = envelope.streamId, quickCommandMessageIds[streamId] != nil {
                    updateQuickCommand(streamId: streamId, bodyAppend: output.data)
                }
            } else {
                appendEvent("Terminal event")
            }
        case .agentRun:
            let event = try decodePayload(AgentEventPayload.self, from: envelope)
            let text = event.text ?? event.path ?? event.kind
            agentLines.append("[\(event.kind)] \(text)")
            applyAgentEvent(event, streamId: envelope.streamId)
            appendEvent("Agent: \(event.kind)")
        default:
            appendEvent("\(capability.rawValue) event")
        }
    }

    private func routeError(_ envelope: BridgeEnvelopeRaw) {
        if case .object(let payload) = envelope.payload {
            let message = payload["message"]?.stringValue ?? "Bridge request failed"
            lastErrorMessage = message
            appendEvent("Error: \(message)")
            if envelope.capability == .agentRun {
                markAgentFailed(message)
            } else {
                markLatestStreamingSystemFailed(for: envelope.capability, message: message)
            }
            return
        }
        appendEvent("Bridge error")
    }

    private func decodePayload<Value: Decodable>(_ type: Value.Type, from envelope: BridgeEnvelopeRaw) throws -> Value {
        let data = try encoder.encode(envelope.payload)
        return try decoder.decode(type, from: data)
    }

    private func commandText(_ result: CommandResult) -> String {
        let output = [result.stdout, result.stderr]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
        if output.isEmpty {
            return "Command exited \(result.exitCode.map(String.init) ?? "unknown")"
        }
        return output
    }

    private func appendRawEvent(_ data: Data) {
        if let raw = String(data: data, encoding: .utf8) {
            appendEvent(raw)
        }
    }

    private func appendEvent(_ event: String) {
        eventLog.append(event)
        if eventLog.count > 300 {
            eventLog.removeFirst(eventLog.count - 300)
        }
    }

    private func ensureActiveConversation(workspaceName: String, provider: AgentProviderKind = .codex) {
        if let activeConversationId,
           let conversation = conversations.first(where: { $0.id == activeConversationId }) {
            chatMessages = conversation.messages
            return
        }

        if let existing = conversations.first {
            activeConversationId = existing.id
            chatMessages = existing.messages
            bumpChatWithoutPersist()
            return
        }

        startNewConversation(provider: provider)
    }

    private func welcomeMessages(workspaceName: String) -> [AgentChatMessage] {
        [
            AgentChatMessage(
            role: .assistant,
            title: "Workspace connected",
            body: "\(workspaceName) is connected. Ask for a code change, a review, an explanation, a test run, or use the menus for files, git, previews, and processes.",
            status: .completed,
            workItems: [
                AgentWorkItem(
                    kind: "session.hello",
                    title: "Secure bridge ready",
                    detail: "Commands and agents execute on the Mac, not on the phone.",
                    state: .completed
                )
            ]
            )
        ]
    }

    private func applyAgentEvent(_ event: AgentEventPayload, streamId: String?) {
        let resolvedStreamId = streamId ?? activeAgentStreamId
        switch event.kind {
        case "assistant.text":
            triggerResponseStartedHapticIfNeeded(streamId: resolvedStreamId)
            appendAssistantText(event.text ?? "", streamId: resolvedStreamId)
        case "tool.started":
            let text = event.text ?? event.path ?? "Command started"
            if isProviderStartEvent(text) {
                return
            } else {
                triggerResponseStartedHapticIfNeeded(streamId: resolvedStreamId)
                appendCommandExecutionMessage(
                    streamId: resolvedStreamId,
                    title: "Command",
                    body: text,
                    status: .streaming
                )
            }
        case "tool.completed":
            triggerResponseStartedHapticIfNeeded(streamId: resolvedStreamId)
            markLatestCommandCompleted(streamId: resolvedStreamId, detail: event.text ?? "", status: .completed)
        case "run.completed":
            flushPendingAssistantDeltas(for: resolvedStreamId)
            if let resolvedStreamId {
                finishAgentRun(streamId: resolvedStreamId, status: .completed)
            }
        case "run.failed":
            flushPendingAssistantDeltas(for: resolvedStreamId)
            triggerResponseStartedHapticIfNeeded(streamId: resolvedStreamId)
            appendTimelineMessage(
                streamId: resolvedStreamId,
                role: .system,
                kind: .toolActivity,
                title: "Agent failed",
                body: event.text ?? "The agent stopped before finishing.",
                status: .failed
            )
            if let resolvedStreamId {
                finishAgentRun(streamId: resolvedStreamId, status: .failed)
            } else {
                markAgentFailed(event.text ?? "Agent run failed")
            }
        case "run.cancelled":
            flushPendingAssistantDeltas(for: resolvedStreamId)
            triggerResponseStartedHapticIfNeeded(streamId: resolvedStreamId)
            appendTimelineMessage(
                streamId: resolvedStreamId,
                role: .system,
                kind: .toolActivity,
                title: "Agent stopped",
                body: event.text ?? "The run was cancelled.",
                status: .completed
            )
            if let resolvedStreamId {
                finishAgentRun(streamId: resolvedStreamId, status: .completed)
            }
        case "approval.requested":
            triggerResponseStartedHapticIfNeeded(streamId: resolvedStreamId)
            appendTimelineMessage(
                streamId: resolvedStreamId,
                role: .system,
                kind: .userInputPrompt,
                title: "Approval needed",
                body: event.text ?? "The agent is asking before making a sensitive change.",
                path: event.path,
                status: .needsApproval
            )
            setAgentStatus(streamId: resolvedStreamId, status: .needsApproval)
        case "shell.output":
            triggerResponseStartedHapticIfNeeded(streamId: resolvedStreamId)
            if let assistantText = assistantTextFromShellOutput(event.text) {
                appendAssistantText(assistantText, streamId: resolvedStreamId)
            } else {
                appendShellOutput(event.text ?? "", streamId: resolvedStreamId)
            }
        case "file.changed", "diff.available":
            triggerResponseStartedHapticIfNeeded(streamId: resolvedStreamId)
            appendTimelineMessage(
                streamId: resolvedStreamId,
                role: .system,
                kind: .fileChange,
                title: event.kind == "file.changed" ? "File changed" : "Diff available",
                body: event.text ?? event.path ?? "",
                path: event.path,
                status: .completed
            )
        default:
            triggerResponseStartedHapticIfNeeded(streamId: resolvedStreamId)
            appendTimelineMessage(
                streamId: resolvedStreamId,
                role: .system,
                kind: .toolActivity,
                title: eventTitle(event.kind),
                body: event.text ?? event.path ?? "",
                path: event.path,
                status: event.kind.contains("completed") ? .completed : .streaming
            )
        }
    }

    private func triggerResponseStartedHapticIfNeeded(streamId: String?) {
        let key = streamId ?? activeAgentStreamId ?? "unscoped-agent-response"
        guard !responseHapticStreamIds.contains(key) else { return }
        responseHapticStreamIds.insert(key)
        HapticFeedback.shared.triggerResponseStartedFeedback()
    }

    private func appendAssistantText(_ text: String, streamId: String?) {
        guard !text.isEmpty else { return }
        guard let streamId else {
            appendAssistantDelta(text, streamId: nil)
            return
        }
        pendingAssistantDeltaByStreamId[streamId, default: ""] += text
        scheduleAssistantDeltaFlush()
    }

    private func appendAssistantDelta(_ text: String, streamId: String?) {
        guard !text.isEmpty else { return }
        let index = assistantMessageIndexForAppending(streamId: streamId)
        let currentBody = chatMessages[index].body
        let incoming = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !incoming.isEmpty {
            let currentTrimmed = currentBody.trimmingCharacters(in: .whitespacesAndNewlines)
            if currentTrimmed == incoming || currentTrimmed.hasSuffix(incoming) {
                return
            }
        }
        chatMessages[index].body += text
        chatMessages[index].status = .streaming
        chatMessages[index].isStreaming = true
        activeAgentMessageId = chatMessages[index].id
        bumpChat()
    }

    private func assistantMessageIndexForAppending(streamId: String?) -> Array<AgentChatMessage>.Index {
        let scopedMessages = chatMessages.enumerated().filter { _, message in
            message.streamId == streamId
        }

        if let latest = scopedMessages.last,
           latest.element.role == .assistant {
            return latest.offset
        }

        let message = AgentChatMessage(
            role: .assistant,
            kind: .chat,
            title: activeAgentProvider?.title,
            body: "",
            provider: activeAgentProvider,
            streamId: streamId,
            turnId: streamId,
            itemId: "assistant-\(streamId ?? UUID().uuidString)-\(AgentMessageOrderCounter.next())",
            isStreaming: true,
            status: .streaming,
            workItems: []
        )
        chatMessages.append(message)
        activeAgentMessageId = message.id
        return chatMessages.index(before: chatMessages.endIndex)
    }

    private func scheduleAssistantDeltaFlush() {
        guard assistantDeltaFlushTask == nil else { return }
        assistantDeltaFlushTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            flushPendingAssistantDeltas()
        }
    }

    private func flushPendingAssistantDeltas(for streamId: String? = nil) {
        assistantDeltaFlushTask?.cancel()
        assistantDeltaFlushTask = nil

        if let streamId {
            let delta = pendingAssistantDeltaByStreamId.removeValue(forKey: streamId) ?? ""
            appendAssistantDelta(delta, streamId: streamId)
            return
        }

        let deltas = pendingAssistantDeltaByStreamId
        pendingAssistantDeltaByStreamId.removeAll()
        for (streamId, delta) in deltas {
            appendAssistantDelta(delta, streamId: streamId)
        }
    }

    private func appendTimelineMessage(
        streamId: String?,
        role: AgentChatRole,
        kind: AgentMessageKind,
        title: String?,
        body: String,
        path: String? = nil,
        status: AgentChatStatus
    ) {
        let message = AgentChatMessage(
            role: role,
            kind: kind,
            title: title,
            body: body,
            provider: activeAgentProvider,
            streamId: streamId,
            turnId: streamId,
            itemId: stableItemId(kind: kind, streamId: streamId, path: path, body: body),
            isStreaming: status == .streaming || status == .needsApproval,
            deliveryState: status == .failed ? .failed : .confirmed,
            status: status
        )
        chatMessages.append(message)
        bumpChat()
    }

    private func appendCommandExecutionMessage(
        streamId: String?,
        title: String,
        body: String,
        status: AgentChatStatus
    ) {
        let message = AgentChatMessage(
            role: .system,
            kind: .commandExecution,
            title: title,
            body: body,
            provider: activeAgentProvider,
            streamId: streamId,
            turnId: streamId,
            itemId: stableItemId(kind: .commandExecution, streamId: streamId, path: nil, body: body),
            isStreaming: status == .streaming,
            status: status
        )
        chatMessages.append(message)
        if let streamId {
            commandMessageIdsByStreamId[streamId] = message.id
        }
        bumpChat()
    }

    private func appendShellOutput(_ text: String, streamId: String?) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let commandIndex = latestCommandMessageIndex(streamId: streamId) {
            let separator = chatMessages[commandIndex].body.isEmpty ? "" : "\n"
            chatMessages[commandIndex].body += "\(separator)\(text)"
            chatMessages[commandIndex].isStreaming = true
            chatMessages[commandIndex].status = .streaming
            bumpChat()
            return
        }

        appendTimelineMessage(
            streamId: streamId,
            role: .system,
            kind: .toolActivity,
            title: "Shell output",
            body: text,
            status: .streaming
        )
    }

    private func markLatestCommandCompleted(streamId: String?, detail: String, status: AgentChatStatus) {
        guard let index = latestCommandMessageIndex(streamId: streamId) else {
            appendTimelineMessage(
                streamId: streamId,
                role: .system,
                kind: .toolActivity,
                title: status == .failed ? "Command failed" : "Command completed",
                body: detail,
                status: status
            )
            return
        }

        if !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !chatMessages[index].body.contains(detail) {
            chatMessages[index].body += "\n\(detail)"
        }
        chatMessages[index].status = status
        chatMessages[index].isStreaming = false
        chatMessages[index].deliveryState = status == .failed ? .failed : .confirmed
        bumpChat()
    }

    private func latestCommandMessageIndex(streamId: String?) -> Array<AgentChatMessage>.Index? {
        if let streamId,
           let id = commandMessageIdsByStreamId[streamId],
           let index = chatMessages.firstIndex(where: { $0.id == id }) {
            return index
        }
        return chatMessages.lastIndex { $0.streamId == streamId && $0.kind == .commandExecution }
    }

    private func appendAgentWorkItem(streamId: String?, _ item: AgentWorkItem) {
        guard let index = agentMessageIndex(streamId: streamId) else { return }
        chatMessages[index].workItems.append(item)
        bumpChat()
    }

    private func markLatestMatchingToolCompleted(streamId: String?, detail: String) {
        guard let index = agentMessageIndex(streamId: streamId) else { return }
        if let itemIndex = chatMessages[index].workItems.lastIndex(where: { $0.kind == "tool.started" && $0.state == .running }) {
            chatMessages[index].workItems[itemIndex].kind = "tool.completed"
            chatMessages[index].workItems[itemIndex].state = .completed
            if !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                chatMessages[index].workItems[itemIndex].detail = detail
            }
        } else {
            chatMessages[index].workItems.append(AgentWorkItem(
                kind: "tool.completed",
                title: "Tool completed",
                detail: detail,
                state: .completed
            ))
        }
        bumpChat()
    }

    private func setAgentStatus(streamId: String?, status: AgentChatStatus) {
        guard let index = agentMessageIndex(streamId: streamId) else { return }
        chatMessages[index].status = status
        chatMessages[index].isStreaming = status == .streaming || status == .needsApproval
        chatMessages[index].deliveryState = status == .failed ? .failed : .confirmed
        bumpChat()
    }

    private func finishAgentRun(streamId: String, status: AgentChatStatus) {
        flushPendingAssistantDeltas(for: streamId)
        guard activeAgentStreamId == streamId || agentMessageIndex(streamId: streamId) != nil else { return }
        setAgentStatus(streamId: streamId, status: status)
        markStreamMessagesFinished(streamId: streamId, status: status)
        if activeAgentStreamId == streamId {
            isAgentRunning = false
            activeAgentProvider = nil
            activeAgentStreamId = nil
            activeAgentMessageId = nil
        }
    }

    private func markAgentFailed(_ message: String) {
        flushPendingAssistantDeltas(for: activeAgentStreamId)
        if let index = agentMessageIndex(streamId: activeAgentStreamId) {
            chatMessages[index].status = .failed
            chatMessages[index].isStreaming = false
            chatMessages[index].deliveryState = .failed
            if chatMessages[index].body.isEmpty {
                chatMessages[index].body = message
            } else {
                chatMessages[index].body += "\n\n\(message)"
            }
        } else {
            chatMessages.append(AgentChatMessage(role: .system, title: "Agent failed", body: message, status: .failed))
        }
        isAgentRunning = false
        activeAgentProvider = nil
        activeAgentStreamId = nil
        activeAgentMessageId = nil
        bumpChat()
    }

    private func markStreamMessagesFinished(streamId: String, status: AgentChatStatus) {
        for index in chatMessages.indices where chatMessages[index].streamId == streamId {
            if chatMessages[index].status == .streaming || chatMessages[index].isStreaming {
                chatMessages[index].status = status == .failed ? .failed : .completed
            }
            chatMessages[index].isStreaming = false
            if status == .failed {
                chatMessages[index].deliveryState = .failed
            }
        }
        commandMessageIdsByStreamId.removeValue(forKey: streamId)
        bumpChat()
    }

    @discardableResult
    private func markConnectionFailedIfNeeded(_ error: Error) -> Bool {
        let message = error.localizedDescription
        let lowercased = message.lowercased()
        guard lowercased.contains("connection abort")
            || lowercased.contains("network connection was lost")
            || lowercased.contains("not connected")
            || lowercased.contains("socket is not connected")
        else {
            return false
        }

        markConnectionFailed("Host disconnected. Start the host again, then pair with a fresh QR code.")
        return true
    }

    private func markConnectionFailed(_ message: String) {
        flushPendingConversationPersist()
        Task { await transport.close() }
        secureSession = nil
        acceptedSession = nil
        activeWorkspace = nil
        isAgentRunning = false
        activeAgentProvider = nil
        activeAgentStreamId = nil
        activeAgentMessageId = nil
        quickCommandMessageIds.removeAll()
        clearStreamTracking()
        lastErrorMessage = message
        state = .failed(message)
        appendEvent(message)
        bumpChat()
    }

    private func agentMessageIndex(streamId: String?) -> Array<AgentChatMessage>.Index? {
        if let streamId, let index = chatMessages.lastIndex(where: { $0.streamId == streamId && $0.role == .assistant }) {
            return index
        }
        if let activeAgentMessageId {
            return chatMessages.lastIndex(where: { $0.id == activeAgentMessageId })
        }
        return chatMessages.lastIndex(where: { $0.role == .assistant })
    }

    private func appendToolResult(title: String, body: String) {
        if let index = latestStreamingSystemNoteIndex(for: title) {
            chatMessages[index].title = title
            chatMessages[index].body = body
            chatMessages[index].status = .completed
            bumpChat()
            return
        }

        chatMessages.append(AgentChatMessage(role: .system, title: title, body: body, status: .completed))
        bumpChat()
    }

    private func markLatestStreamingSystemFailed(for capability: Capability?, message: String) {
        guard let index = latestStreamingSystemNoteIndex(for: capability) else {
            chatMessages.append(AgentChatMessage(role: .system, title: "Action failed", body: message, status: .failed))
            bumpChat()
            return
        }

        chatMessages[index].title = "Action failed"
        chatMessages[index].body = message
        chatMessages[index].status = .failed
        bumpChat()
    }

    private func latestStreamingSystemNoteIndex(for capability: Capability?) -> Array<AgentChatMessage>.Index? {
        guard let capability else { return nil }
        return latestStreamingSystemNoteIndex(matching: streamingNoteAliases(for: capability))
    }

    private func latestStreamingSystemNoteIndex(for resultTitle: String) -> Array<AgentChatMessage>.Index? {
        latestStreamingSystemNoteIndex(matching: streamingNoteAliases(forResultTitle: resultTitle))
    }

    private func latestStreamingSystemNoteIndex(matching titles: Set<String>) -> Array<AgentChatMessage>.Index? {
        chatMessages.lastIndex {
            $0.role == .system
                && $0.status == .streaming
                && $0.title.map(titles.contains) == true
        }
    }

    private func streamingNoteAliases(for capability: Capability) -> Set<String> {
        switch capability {
        case .gitStatus:
            ["Checking git status"]
        case .gitDiff:
            ["Reviewing code changes"]
        case .previewPorts:
            ["Finding local previews"]
        case .processList:
            ["Loading processes"]
        default:
            []
        }
    }

    private func streamingNoteAliases(forResultTitle title: String) -> Set<String> {
        switch title {
        case "Git status":
            ["Checking git status"]
        case "Git diff":
            ["Reviewing code changes"]
        case "Local previews":
            ["Finding local previews"]
        case "Running processes":
            ["Loading processes"]
        default:
            []
        }
    }

    private func updateQuickCommand(
        streamId: String,
        bodyAppend: String? = nil,
        workItem: AgentWorkItem? = nil,
        status: AgentChatStatus? = nil
    ) {
        guard
            let messageId = quickCommandMessageIds[streamId],
            let index = chatMessages.firstIndex(where: { $0.id == messageId })
        else { return }

        if let bodyAppend, !bodyAppend.isEmpty {
            chatMessages[index].body += bodyAppend
        }
        if let workItem {
            chatMessages[index].workItems.append(workItem)
        }
        if let status {
            chatMessages[index].status = status
        }
        bumpChat()
    }

    private func eventTitle(_ kind: String) -> String {
        switch kind {
        case "tool.started":
            "Tool started"
        case "tool.completed":
            "Tool completed"
        default:
            kind
                .replacingOccurrences(of: ".", with: " ")
                .capitalized
        }
    }

    private func stableItemId(kind: AgentMessageKind, streamId: String?, path: String?, body: String) -> String {
        let source = [
            streamId ?? "local",
            kind.rawValue,
            path ?? "",
            body.prefix(80).description
        ].joined(separator: "|")
        return "\(kind.rawValue)-\(stableIdentifierHash(source))"
    }

    private func stableIdentifierHash(_ source: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in source.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private func clearStreamTracking() {
        commandMessageIdsByStreamId.removeAll()
        pendingAssistantDeltaByStreamId.removeAll()
        assistantDeltaFlushTask?.cancel()
        assistantDeltaFlushTask = nil
    }

    private func exitCodeDescription(from data: JSONValue?) -> String {
        guard
            case .object(let payload)? = data,
            case .number(let exitCode)? = payload["exitCode"]
        else {
            return "Run completed."
        }
        return "Exit code \(Int(exitCode))"
    }

    private func assistantTextFromShellOutput(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lines = text.components(separatedBy: .newlines)
        if lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "codex" {
            let response = sanitizedCodexAssistantText(from: Array(lines.dropFirst()))
            return response.isEmpty ? nil : "\(response)\n"
        }

        if trimmed.hasPrefix("exec\n")
            || trimmed.hasPrefix("succeeded")
            || trimmed.hasPrefix("failed")
            || trimmed.hasPrefix("tokens used")
            || trimmed.contains(" ERROR ") {
            return nil
        }

        return nil
    }

    private func sanitizedCodexAssistantText(from lines: [String]) -> String {
        var output: [String] = []
        var isDroppingToolTranscript = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if shouldStartDroppingCodexToolTranscript(trimmed) {
                isDroppingToolTranscript = true
                continue
            }

            if isDroppingToolTranscript {
                if isLikelyNaturalLanguageCodexLine(trimmed) {
                    isDroppingToolTranscript = false
                } else {
                    continue
                }
            }

            guard !isLikelyRawCodeTranscriptLine(trimmed) else {
                isDroppingToolTranscript = true
                continue
            }

            output.append(line)
        }

        return output
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shouldStartDroppingCodexToolTranscript(_ line: String) -> Bool {
        line.hasPrefix("/bin/")
            || line.hasPrefix("exec")
            || line.hasPrefix("succeeded in ")
            || line.hasPrefix("failed in ")
            || line.hasPrefix("tokens used")
            || line.contains(" in /Users/")
    }

    private func isLikelyRawCodeTranscriptLine(_ line: String) -> Bool {
        guard !line.isEmpty else { return false }
        let rawPrefixes = [
            "{",
            "}",
            "\"",
            "import ",
            "export ",
            "interface ",
            "const ",
            "let ",
            "var ",
            "async function ",
            "function ",
            "return ",
            "if ",
            "}",
            "#!/usr/bin/env "
        ]
        if rawPrefixes.contains(where: { line.hasPrefix($0) }) {
            return true
        }

        return line.range(of: #"^\d+\s+\S"#, options: .regularExpression) != nil
    }

    private func isLikelyNaturalLanguageCodexLine(_ line: String) -> Bool {
        guard !line.isEmpty else { return false }
        let naturalPrefixes = [
            "I ",
            "I'",
            "I’",
            "The ",
            "This ",
            "That ",
            "It ",
            "There ",
            "Here ",
            "You ",
            "Your ",
            "Findings",
            "Issues",
            "Recommendations",
            "Summary",
            "Next "
        ]
        return naturalPrefixes.contains(where: { line.hasPrefix($0) })
    }

    private func isProviderStartEvent(_ text: String) -> Bool {
        guard text.contains(" started: ") else { return false }
        if let activeAgentProvider {
            return text.hasPrefix(activeAgentProvider.title) || text.hasPrefix(activeAgentProvider.shortTitle)
        }
        return text.contains("Codex started:")
            || text.contains("Claude Code started:")
            || text.contains("OpenCode started:")
    }

    private func bumpChat() {
        chatRevision += 1
        syncActiveConversationFromMessages()
    }

    private func bumpChatWithoutPersist() {
        chatRevision += 1
    }

    private func syncActiveConversationFromMessages() {
        guard let activeConversationId,
              let index = conversations.firstIndex(where: { $0.id == activeConversationId })
        else { return }

        conversations[index].messages = chatMessages
        conversations[index].turns = WorkspaceTurnProjector.project(messages: chatMessages)
        conversations[index].updatedAt = Date()
        conversations[index].provider = chatMessages.last(where: { $0.provider != nil })?.provider ?? conversations[index].provider
        sortConversations()
        schedulePersistConversations()
    }

    private func updateActiveConversationTitleIfNeeded(from prompt: String, provider: AgentProviderKind) {
        guard let activeConversationId,
              let index = conversations.firstIndex(where: { $0.id == activeConversationId }),
              conversations[index].title == "New chat"
        else { return }

        conversations[index].title = promptTitle(from: prompt)
        conversations[index].provider = provider
        conversations[index].updatedAt = Date()
        sortConversations()
        schedulePersistConversations()
    }

    private func promptTitle(from prompt: String) -> String {
        let normalized = prompt
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > 42 else { return normalized.isEmpty ? "New chat" : normalized }
        return "\(normalized.prefix(42))..."
    }

    private func sortConversations() {
        conversations.sort {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func loadConversations(workspaceRoot: String) {
        do {
            let url = try conversationsURL(for: workspaceRoot)
            guard FileManager.default.fileExists(atPath: url.path) else {
                conversations = []
                activeConversationId = nil
                chatMessages = []
                return
            }
            let data = try Data(contentsOf: url)
            conversations = try storageDecoder.decode([WorkspaceConversation].self, from: data)
                .filter { $0.workspaceRoot == workspaceRoot }
                .map { conversation in
                    var normalized = conversation
                    normalized.turns = WorkspaceTurnProjector.project(messages: conversation.messages)
                    return normalized
                }
            sortConversations()
            activeConversationId = conversations.first?.id
            chatMessages = conversations.first?.messages ?? []
        } catch {
            conversations = []
            activeConversationId = nil
            chatMessages = []
            appendEvent("Conversation history reset: \(error.localizedDescription)")
        }
    }

    private func persistConversations() {
        guard let workspaceRoot = activeWorkspace?.root else { return }
        do {
            let url = try conversationsURL(for: workspaceRoot)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try storageEncoder.encode(conversations)
            try data.write(to: url, options: [.atomic])
        } catch {
            appendEvent("Failed to save conversation history: \(error.localizedDescription)")
        }
    }

    private func schedulePersistConversations() {
        conversationPersistTask?.cancel()
        conversationPersistTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            conversationPersistTask = nil
            persistConversations()
        }
    }

    private func flushPendingConversationPersist() {
        conversationPersistTask?.cancel()
        conversationPersistTask = nil
        persistConversations()
    }

    private func conversationsURL(for workspaceRoot: String) throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("PulseOscilla", isDirectory: true)
        .appendingPathComponent("Conversations", isDirectory: true)

        return directory.appendingPathComponent("\(storageKey(for: workspaceRoot)).json")
    }

    private func storageKey(for workspaceRoot: String) -> String {
        Data(workspaceRoot.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }
}

enum BridgeConnectionError: Error {
    case notConnected
}

struct AgentCancelPayload: Codable {
    let provider: AgentProviderKind
}

private extension JSONValue {
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }
}
