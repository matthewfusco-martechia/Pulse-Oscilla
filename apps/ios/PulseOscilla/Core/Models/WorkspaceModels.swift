import Foundation

struct WorkspaceDescriptor: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let root: String
    let gitBranch: String?
}

struct EmptyPayload: Codable {}

struct PathPayload: Codable {
    let path: String
}

struct FileWritePayload: Codable {
    let path: String
    let content: String
    let expectedSha256: String?
}

struct FileEntry: Codable, Hashable, Identifiable {
    let name: String
    let path: String
    let kind: FileKind
    let size: Int?
    let modifiedAt: String?

    var id: String { path }
}

enum FileKind: String, Codable {
    case file
    case directory
    case symlink
    case unknown

    var symbol: String {
        switch self {
        case .file:
            "doc.text"
        case .directory:
            "folder"
        case .symlink:
            "link"
        case .unknown:
            "questionmark.square"
        }
    }
}

struct RemoteFile: Codable, Hashable {
    let path: String
    let name: String
    let content: String
    let sha256: String
}

struct FileWriteResult: Codable, Hashable {
    let path: String
    let sha256: String
}

struct TerminalCreatePayload: Codable {
    let shell: String?
    let cwd: String?
    let cols: Int
    let rows: Int
}

struct TerminalInputPayload: Codable {
    let data: String
}

struct TerminalCreateResult: Codable, Hashable {
    let streamId: String
    let pid: Int
}

struct TerminalOutputPayload: Codable, Hashable {
    let fd: String
    let data: String
}

struct TerminalResizePayload: Codable {
    let cols: Int
    let rows: Int
}

struct SignalPayload: Codable {
    let signal: String
}

struct GitCommitPayload: Codable {
    let message: String
}

struct CommandResult: Codable, Hashable {
    let exitCode: Int?
    let stdout: String
    let stderr: String
}

struct AgentRunPayload: Codable {
    let provider: AgentProviderKind
    let prompt: String
    let mode: String
    let allowedTools: [String]?
    let requireApprovalForWrites: Bool
    let customCommand: String?
}

struct AgentInputPayload: Codable {
    let provider: AgentProviderKind
    let data: String
}

struct AgentRunResult: Codable, Hashable {
    let streamId: String
}

struct AgentProvidersResult: Codable, Hashable {
    let providers: [AgentAvailabilityPayload]
}

struct AgentAvailabilityPayload: Codable, Hashable, Identifiable {
    let provider: AgentProviderKind
    let displayName: String
    let available: Bool
    let reason: String?
    let command: String?
    let resolvedPath: String?
    let version: String?

    var id: AgentProviderKind { provider }
}

struct AgentEventPayload: Codable, Hashable {
    let kind: String
    let text: String?
    let path: String?
    let data: JSONValue?
}

enum AgentChatRole: String, Hashable, Codable {
    case user
    case assistant
    case system
}

enum AgentChatStatus: String, Hashable, Codable {
    case ready
    case streaming
    case needsApproval
    case completed
    case failed
}

enum AgentMessageKind: String, Hashable, Codable {
    case chat
    case thinking
    case toolActivity
    case fileChange
    case commandExecution
    case userInputPrompt
}

enum AgentMessageDeliveryState: String, Hashable, Codable {
    case pending
    case confirmed
    case failed
}

enum AgentWorkItemState: String, Hashable, Codable {
    case running
    case completed
    case blocked
    case failed
}

struct AgentWorkItem: Identifiable, Hashable, Codable {
    let id: UUID
    var kind: String
    var title: String
    var detail: String
    var path: String?
    var state: AgentWorkItemState

    init(
        id: UUID = UUID(),
        kind: String,
        title: String,
        detail: String = "",
        path: String? = nil,
        state: AgentWorkItemState = .running
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.path = path
        self.state = state
    }
}

struct AgentChatMessage: Identifiable, Hashable, Codable {
    let id: UUID
    let role: AgentChatRole
    var kind: AgentMessageKind
    var title: String?
    var body: String
    var provider: AgentProviderKind?
    var streamId: String?
    var turnId: String?
    var itemId: String?
    var isStreaming: Bool
    var deliveryState: AgentMessageDeliveryState
    var status: AgentChatStatus
    var workItems: [AgentWorkItem]
    let createdAt: Date
    var orderIndex: Int

    init(
        id: UUID = UUID(),
        role: AgentChatRole,
        kind: AgentMessageKind = .chat,
        title: String? = nil,
        body: String,
        provider: AgentProviderKind? = nil,
        streamId: String? = nil,
        turnId: String? = nil,
        itemId: String? = nil,
        isStreaming: Bool = false,
        deliveryState: AgentMessageDeliveryState = .confirmed,
        status: AgentChatStatus = .ready,
        workItems: [AgentWorkItem] = [],
        createdAt: Date = Date(),
        orderIndex: Int = AgentMessageOrderCounter.next()
    ) {
        self.id = id
        self.role = role
        self.kind = kind
        self.title = title
        self.body = body
        self.provider = provider
        self.streamId = streamId
        self.turnId = turnId
        self.itemId = itemId
        self.isStreaming = isStreaming
        self.deliveryState = deliveryState
        self.status = status
        self.workItems = workItems
        self.createdAt = createdAt
        self.orderIndex = orderIndex
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case role
        case kind
        case title
        case body
        case provider
        case streamId
        case turnId
        case itemId
        case isStreaming
        case deliveryState
        case status
        case workItems
        case createdAt
        case orderIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        role = try container.decode(AgentChatRole.self, forKey: .role)
        kind = try container.decodeIfPresent(AgentMessageKind.self, forKey: .kind) ?? .chat
        title = try container.decodeIfPresent(String.self, forKey: .title)
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        provider = try container.decodeIfPresent(AgentProviderKind.self, forKey: .provider)
        streamId = try container.decodeIfPresent(String.self, forKey: .streamId)
        turnId = try container.decodeIfPresent(String.self, forKey: .turnId)
        itemId = try container.decodeIfPresent(String.self, forKey: .itemId)
        status = try container.decodeIfPresent(AgentChatStatus.self, forKey: .status) ?? .ready
        isStreaming = try container.decodeIfPresent(Bool.self, forKey: .isStreaming) ?? (status == .streaming)
        deliveryState = try container.decodeIfPresent(AgentMessageDeliveryState.self, forKey: .deliveryState)
            ?? (status == .failed ? .failed : .confirmed)
        workItems = try container.decodeIfPresent([AgentWorkItem].self, forKey: .workItems) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        orderIndex = try container.decodeIfPresent(Int.self, forKey: .orderIndex) ?? AgentMessageOrderCounter.next()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encodeIfPresent(provider, forKey: .provider)
        try container.encodeIfPresent(streamId, forKey: .streamId)
        try container.encodeIfPresent(turnId, forKey: .turnId)
        try container.encodeIfPresent(itemId, forKey: .itemId)
        try container.encode(isStreaming, forKey: .isStreaming)
        try container.encode(deliveryState, forKey: .deliveryState)
        try container.encode(status, forKey: .status)
        try container.encode(workItems, forKey: .workItems)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(orderIndex, forKey: .orderIndex)
    }
}

enum AgentMessageOrderCounter {
    static func next() -> Int {
        Int(Date().timeIntervalSince1970 * 1_000_000)
    }
}

struct WorkspaceConversation: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var workspaceRoot: String
    var provider: AgentProviderKind
    var messages: [AgentChatMessage]
    var turns: [WorkspaceTurn]
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        workspaceRoot: String,
        provider: AgentProviderKind = .codex,
        messages: [AgentChatMessage] = [],
        turns: [WorkspaceTurn] = [],
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.workspaceRoot = workspaceRoot
        self.provider = provider
        self.messages = messages
        self.turns = turns
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case workspaceRoot
        case provider
        case messages
        case turns
        case isPinned
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "New chat"
        workspaceRoot = try container.decode(String.self, forKey: .workspaceRoot)
        provider = try container.decodeIfPresent(AgentProviderKind.self, forKey: .provider) ?? .codex
        messages = try container.decodeIfPresent([AgentChatMessage].self, forKey: .messages) ?? []
        turns = try container.decodeIfPresent([WorkspaceTurn].self, forKey: .turns)
            ?? WorkspaceTurnProjector.project(messages: messages)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    var preview: String {
        messages
            .reversed()
            .first { !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
            .body
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "No messages yet"
    }
}

enum WorkspaceTurnStatus: String, Hashable, Codable {
    case ready
    case running
    case needsApproval
    case completed
    case failed
}

enum WorkspaceTurnEventKind: String, Hashable, Codable {
    case userPrompt
    case assistantText
    case command
    case thinking
    case fileChange
    case approval
    case status
}

struct WorkspaceTurnEvent: Identifiable, Hashable, Codable {
    let id: UUID
    var kind: WorkspaceTurnEventKind
    var messageId: UUID
    var title: String?
    var body: String
    var status: AgentChatStatus
    var orderIndex: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        kind: WorkspaceTurnEventKind,
        messageId: UUID,
        title: String? = nil,
        body: String,
        status: AgentChatStatus,
        orderIndex: Int,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.messageId = messageId
        self.title = title
        self.body = body
        self.status = status
        self.orderIndex = orderIndex
        self.createdAt = createdAt
    }
}

struct WorkspaceTurn: Identifiable, Hashable, Codable {
    let id: String
    var provider: AgentProviderKind?
    var prompt: String
    var status: WorkspaceTurnStatus
    var events: [WorkspaceTurnEvent]
    var createdAt: Date
    var updatedAt: Date

    var isRunning: Bool {
        status == .running || status == .needsApproval
    }
}

enum WorkspaceTurnProjector {
    static func project(messages: [AgentChatMessage]) -> [WorkspaceTurn] {
        let sortedMessages = messages.sorted {
            if $0.orderIndex != $1.orderIndex {
                return $0.orderIndex < $1.orderIndex
            }
            return $0.createdAt < $1.createdAt
        }

        var turnsById: [String: WorkspaceTurn] = [:]
        var turnOrder: [String] = []

        for message in sortedMessages {
            let turnId = resolvedTurnId(for: message)
            if turnsById[turnId] == nil {
                turnsById[turnId] = WorkspaceTurn(
                    id: turnId,
                    provider: message.provider,
                    prompt: message.role == .user ? message.body : "",
                    status: turnStatus(from: message),
                    events: [],
                    createdAt: message.createdAt,
                    updatedAt: message.createdAt
                )
                turnOrder.append(turnId)
            }

            guard var turn = turnsById[turnId] else { continue }
            if turn.provider == nil {
                turn.provider = message.provider
            }
            if message.role == .user, turn.prompt.isEmpty {
                turn.prompt = message.body
            }
            turn.events.append(event(from: message))
            turn.status = mergedStatus(current: turn.status, incoming: turnStatus(from: message))
            turn.updatedAt = max(turn.updatedAt, message.createdAt)
            turnsById[turnId] = turn
        }

        return turnOrder.compactMap { turnId in
            guard var turn = turnsById[turnId] else { return nil }
            turn.events.sort {
                if $0.orderIndex != $1.orderIndex {
                    return $0.orderIndex < $1.orderIndex
                }
                return $0.createdAt < $1.createdAt
            }
            return turn
        }
    }

    private static func resolvedTurnId(for message: AgentChatMessage) -> String {
        if let turnId = message.turnId, !turnId.isEmpty { return turnId }
        if let streamId = message.streamId, !streamId.isEmpty { return streamId }
        return "message-\(message.id.uuidString)"
    }

    private static func event(from message: AgentChatMessage) -> WorkspaceTurnEvent {
        WorkspaceTurnEvent(
            kind: eventKind(from: message),
            messageId: message.id,
            title: message.title,
            body: message.body,
            status: message.status,
            orderIndex: message.orderIndex,
            createdAt: message.createdAt
        )
    }

    private static func eventKind(from message: AgentChatMessage) -> WorkspaceTurnEventKind {
        if message.role == .user { return .userPrompt }
        if message.role == .assistant { return .assistantText }

        switch message.kind {
        case .chat:
            return .status
        case .thinking:
            return .thinking
        case .toolActivity:
            return .status
        case .fileChange:
            return .fileChange
        case .commandExecution:
            return .command
        case .userInputPrompt:
            return .approval
        }
    }

    private static func turnStatus(from message: AgentChatMessage) -> WorkspaceTurnStatus {
        if message.isStreaming { return .running }
        switch message.status {
        case .ready:
            return .ready
        case .streaming:
            return .running
        case .needsApproval:
            return .needsApproval
        case .completed:
            return .completed
        case .failed:
            return .failed
        }
    }

    private static func mergedStatus(
        current: WorkspaceTurnStatus,
        incoming: WorkspaceTurnStatus
    ) -> WorkspaceTurnStatus {
        if incoming == .failed || current == .failed { return .failed }
        if incoming == .needsApproval || current == .needsApproval { return .needsApproval }
        if incoming == .running || current == .running { return .running }
        if incoming == .completed || current == .completed { return .completed }
        return incoming
    }
}

enum AgentProviderKind: String, Codable, CaseIterable, Identifiable {
    case claudeCode = "claude-code"
    case codex
    case opencode
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claudeCode:
            "Claude Code"
        case .codex:
            "OpenAI Codex"
        case .opencode:
            "OpenCode"
        case .custom:
            "Custom"
        }
    }

    var shortTitle: String {
        switch self {
        case .claudeCode:
            "Claude"
        case .codex:
            "Codex"
        case .opencode:
            "OpenCode"
        case .custom:
            "Custom"
        }
    }

    var symbol: String {
        switch self {
        case .claudeCode:
            "sparkles"
        case .codex:
            "hexagon"
        case .opencode:
            "chevron.left.forwardslash.chevron.right"
        case .custom:
            "terminal"
        }
    }
}

struct ProcessKillPayload: Codable {
    let pid: Int
}

struct ProcessListResult: Codable, Hashable {
    let raw: String
}

struct ProcessKillResult: Codable, Hashable {
    let pid: Int
    let signal: String
}

struct PortDescriptor: Codable, Hashable, Identifiable {
    let port: Int
    let `protocol`: String
    let process: String?
    let url: String

    var id: Int { port }
}
