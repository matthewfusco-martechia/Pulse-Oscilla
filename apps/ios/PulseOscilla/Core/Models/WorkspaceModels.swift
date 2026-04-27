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

struct AgentRunResult: Codable, Hashable {
    let streamId: String
}

struct AgentEventPayload: Codable, Hashable {
    let kind: String
    let text: String?
    let path: String?
    let data: JSONValue?
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
