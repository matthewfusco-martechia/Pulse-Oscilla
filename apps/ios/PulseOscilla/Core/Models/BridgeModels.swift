import Foundation

enum Capability: String, Codable, CaseIterable, Identifiable {
    case sessionHello = "session.hello"
    case sessionResume = "session.resume"
    case workspaceList = "workspace.list"
    case workspaceOpen = "workspace.open"
    case terminalCreate = "terminal.create"
    case terminalStdin = "terminal.stdin"
    case terminalResize = "terminal.resize"
    case terminalSignal = "terminal.signal"
    case terminalClose = "terminal.close"
    case filesList = "files.list"
    case filesRead = "files.read"
    case filesWrite = "files.write"
    case filesDiff = "files.diff"
    case filesWatch = "files.watch"
    case gitStatus = "git.status"
    case gitDiff = "git.diff"
    case gitStage = "git.stage"
    case gitRestore = "git.restore"
    case gitCommit = "git.commit"
    case gitPush = "git.push"
    case gitPull = "git.pull"
    case gitBranch = "git.branch"
    case agentProviders = "agent.providers"
    case agentRun = "agent.run"
    case agentStdin = "agent.stdin"
    case agentCancel = "agent.cancel"
    case processList = "process.list"
    case processKill = "process.kill"
    case previewPorts = "preview.ports"
    case previewOpen = "preview.open"

    var id: String { rawValue }
}

struct BridgeRequest<Payload: Encodable>: Encodable {
    let version = 1
    let type = "request"
    let id: String
    let requestId: String
    let streamId: String?
    let workspaceId: String?
    let capability: Capability
    let timestamp: String
    let payload: Payload

    init(
        capability: Capability,
        workspaceId: String?,
        streamId: String? = nil,
        payload: Payload
    ) {
        self.id = "msg_\(UUID().uuidString)"
        self.requestId = "req_\(UUID().uuidString)"
        self.streamId = streamId
        self.workspaceId = workspaceId
        self.capability = capability
        self.timestamp = BridgeTimestamp.now()
        self.payload = payload
    }
}

struct BridgeResponse<Payload: Decodable>: Decodable {
    let version: Int
    let type: String
    let id: String
    let requestId: String
    let streamId: String?
    let workspaceId: String?
    let capability: Capability?
    let timestamp: String
    let payload: Payload
}

struct BridgeEnvelopeRaw: Decodable, Identifiable {
    let version: Int
    let type: String
    let id: String
    let requestId: String?
    let streamId: String?
    let workspaceId: String?
    let capability: Capability?
    let timestamp: String
    let payload: JSONValue
}

enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

enum BridgeTimestamp {
    static func now() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}
