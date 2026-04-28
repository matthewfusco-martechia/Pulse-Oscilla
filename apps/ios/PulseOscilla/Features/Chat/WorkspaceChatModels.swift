import SwiftUI

struct QueuedWorkspacePrompt: Identifiable, Hashable {
    let id: UUID
    var prompt: String
    var provider: AgentProviderKind
    var requireApprovalForWrites: Bool
    var customCommand: String

    init(
        id: UUID = UUID(),
        prompt: String,
        provider: AgentProviderKind,
        requireApprovalForWrites: Bool,
        customCommand: String
    ) {
        self.id = id
        self.prompt = prompt
        self.provider = provider
        self.requireApprovalForWrites = requireApprovalForWrites
        self.customCommand = customCommand
    }
}

enum WorkspaceComposerMode: String, CaseIterable, Identifiable, Hashable {
    case ask
    case plan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ask:
            "Ask"
        case .plan:
            "Plan"
        }
    }

    var symbol: String {
        switch self {
        case .ask:
            "lock"
        case .plan:
            "checklist"
        }
    }
}

struct WorkspaceSkillReference: Identifiable, Hashable {
    let id: String
    var title: String
    var promptPrefix: String
    var subtitle: String
    var symbol: String

    static let defaults: [WorkspaceSkillReference] = [
        WorkspaceSkillReference(
            id: "review",
            title: "Code Review",
            promptPrefix: "$review",
            subtitle: "Find bugs, regressions, and missing tests.",
            symbol: "text.badge.checkmark"
        ),
        WorkspaceSkillReference(
            id: "plan",
            title: "Plan Mode",
            promptPrefix: "$plan",
            subtitle: "Create a safe implementation plan first.",
            symbol: "checklist"
        ),
        WorkspaceSkillReference(
            id: "diff",
            title: "Diff Review",
            promptPrefix: "$diff",
            subtitle: "Inspect current changes and summarize risk.",
            symbol: "plus.forwardslash.minus"
        ),
        WorkspaceSkillReference(
            id: "tests",
            title: "Test Runner",
            promptPrefix: "$tests",
            subtitle: "Run relevant checks and explain failures.",
            symbol: "testtube.2"
        ),
        WorkspaceSkillReference(
            id: "explain",
            title: "Explain Codebase",
            promptPrefix: "$explain",
            subtitle: "Explain architecture in plain English.",
            symbol: "book"
        )
    ]
}

enum WorkspaceChatSheet: Identifiable {
    case conversations
    case tools
    case tool(WorkspaceTool)

    var id: String {
        switch self {
        case .conversations:
            "conversations"
        case .tools:
            "tools"
        case .tool(let tool):
            "tool-\(tool.rawValue)"
        }
    }
}

enum WorkspaceTool: String, CaseIterable, Identifiable {
    case terminal
    case files
    case git
    case previews
    case processes
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terminal:
            "Terminal"
        case .files:
            "Files"
        case .git:
            "Git"
        case .previews:
            "Previews"
        case .processes:
            "Processes"
        case .settings:
            "Security"
        }
    }

    var subtitle: String {
        switch self {
        case .terminal:
            "Run a command on the Mac"
        case .files:
            "Browse and edit the repo"
        case .git:
            "Diff, commit, push, pull"
        case .previews:
            "Open localhost previews"
        case .processes:
            "Inspect running services"
        case .settings:
            "Pairing and trust details"
        }
    }

    var symbol: String {
        switch self {
        case .terminal:
            "terminal"
        case .files:
            "folder"
        case .git:
            "point.3.connected.trianglepath.dotted"
        case .previews:
            "safari"
        case .processes:
            "cpu"
        case .settings:
            "lock.shield"
        }
    }

    var tint: Color {
        switch self {
        case .terminal:
            .primary
        case .files:
            .blue
        case .git:
            .orange
        case .previews:
            .teal
        case .processes:
            .indigo
        case .settings:
            .secondary
        }
    }

    @MainActor
    @ViewBuilder
    func makeView() -> some View {
        switch self {
        case .terminal:
            TerminalView()
        case .files:
            FileBrowserView()
        case .git:
            GitStatusView()
        case .previews:
            PortListView()
        case .processes:
            ProcessListView()
        case .settings:
            SecuritySettingsView()
        }
    }
}

enum WorkspaceQuickAction: String, CaseIterable, Identifiable {
    case gitStatus
    case gitDiff
    case findPreviews
    case buildIOS
    case typecheck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gitStatus:
            "Check Git Status"
        case .gitDiff:
            "Review Code Changes"
        case .findPreviews:
            "Find Local Previews"
        case .buildIOS:
            "Build iOS App"
        case .typecheck:
            "Run Typecheck"
        }
    }

    var subtitle: String {
        switch self {
        case .gitStatus:
            "Current branch and changes"
        case .gitDiff:
            "Ask the Mac for the diff"
        case .findPreviews:
            "Detect running ports"
        case .buildIOS:
            "Compile the app"
        case .typecheck:
            "Run package checks"
        }
    }

    var symbol: String {
        switch self {
        case .gitStatus:
            "checklist"
        case .gitDiff:
            "plus.forwardslash.minus"
        case .findPreviews:
            "safari"
        case .buildIOS:
            "hammer"
        case .typecheck:
            "checkmark.seal"
        }
    }
}
