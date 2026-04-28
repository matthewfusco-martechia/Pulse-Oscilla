import SwiftUI

struct WorkspaceComposerView: View {
    @Binding var draftPrompt: String
    @Binding var customAgentCommand: String
    @Binding var requireApprovalForWrites: Bool
    @Binding var selectedProvider: AgentProviderKind
    @Binding var composerMode: WorkspaceComposerMode
    var isFocused: FocusState<Bool>.Binding

    let isAgentRunning: Bool
    let queuedPrompts: [QueuedWorkspacePrompt]
    let fileEntries: [FileEntry]
    let onOpenTools: () -> Void
    let onRemoveQueuedPrompt: (UUID) -> Void
    let onEditQueuedPrompt: (UUID) -> Void
    let onRefreshFiles: () async -> Void
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
                if composerMode == .plan {
                    WorkspacePlanModeAccessory()
                        .padding(.horizontal, 10)
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if !queuedPrompts.isEmpty {
                    QueuedDraftsPanel(
                        prompts: queuedPrompts,
                        edit: onEditQueuedPrompt,
                        remove: onRemoveQueuedPrompt
                    )
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if showsCommandPanel {
                    WorkspaceComposerCommandPanel(
                        query: commandQuery,
                        select: applyCommand
                    )
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if showsFilePanel {
                    WorkspaceComposerFilePanel(
                        query: fileQuery,
                        entries: fileEntries,
                        refresh: onRefreshFiles,
                        select: applyFileMention
                    )
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if showsSkillPanel {
                    WorkspaceComposerSkillPanel(
                        query: skillQuery,
                        select: applySkill
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
                    composerMode: $composerMode,
                    requireApprovalForWrites: $requireApprovalForWrites,
                    isAgentRunning: isAgentRunning,
                    canSend: canSend,
                    hasQueuedPrompts: !queuedPrompts.isEmpty,
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

    private var showsFilePanel: Bool {
        activeMention(prefix: "@") != nil
    }

    private var showsSkillPanel: Bool {
        activeMention(prefix: "$") != nil
    }

    private var commandQuery: String {
        draftPrompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .dropFirst()
            .lowercased()
            .description
    }

    private var fileQuery: String {
        activeMention(prefix: "@") ?? ""
    }

    private var skillQuery: String {
        activeMention(prefix: "$") ?? ""
    }

    private func activeMention(prefix: Character) -> String? {
        guard let lastToken = draftPrompt
            .split(whereSeparator: \.isWhitespace)
            .last
        else { return nil }

        guard lastToken.first == prefix else { return nil }
        return String(lastToken.dropFirst()).lowercased()
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

    private func applyFileMention(_ entry: FileEntry) {
        replaceActiveToken(with: "@\(entry.path)")
    }

    private func applySkill(_ skill: WorkspaceSkillReference) {
        replaceActiveToken(with: skill.promptPrefix)
        if skill.id == "plan" {
            composerMode = .plan
        }
    }

    private func replaceActiveToken(with replacement: String) {
        var parts = draftPrompt.split(whereSeparator: \.isWhitespace).map(String.init)
        if parts.isEmpty {
            draftPrompt = "\(replacement) "
        } else {
            parts[parts.count - 1] = replacement
            draftPrompt = parts.joined(separator: " ") + " "
        }
        HapticFeedback.shared.triggerImpactFeedback(style: .light)
        isFocused.wrappedValue = true
    }
}

private struct WorkspacePlanModeAccessory: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checklist")
                .font(AppFont.caption(weight: .bold))
                .foregroundStyle(.orange)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text("Plan mode")
                    .font(AppFont.caption(weight: .bold))
                    .foregroundStyle(.primary)
                Text("The agent will propose a plan first and wait before making code changes.")
                    .font(AppFont.caption2())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .workspaceGlass(
            tint: Color.orange.opacity(0.08),
            stroke: Color.orange.opacity(0.18),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
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

private struct WorkspaceComposerFilePanel: View {
    let query: String
    let entries: [FileEntry]
    let refresh: () async -> Void
    let select: (FileEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelHeader(title: "Files", symbol: "doc.text.magnifyingglass") {
                Task { await refresh() }
            }

            ForEach(filteredEntries.prefix(6)) { entry in
                Button {
                    select(entry)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: entry.kind.symbol)
                            .font(AppFont.caption(weight: .bold))
                            .foregroundStyle(entry.kind == .directory ? .blue : .secondary)
                            .frame(width: 22, height: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                                .font(AppFont.caption(weight: .bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(entry.path)
                                .font(AppFont.caption2())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemFill).opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if filteredEntries.isEmpty {
                Text("No matching files. Tap refresh to reload the workspace root.")
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }
        }
        .padding(10)
        .workspaceGlass(cornerRadius: 18)
    }

    private var filteredEntries: [FileEntry] {
        let visible = entries.filter { !$0.name.hasPrefix(".") || !$0.name.hasPrefix(".git") }
        guard !query.isEmpty else { return visible }
        return visible.filter {
            $0.name.lowercased().contains(query)
                || $0.path.lowercased().contains(query)
        }
    }
}

private struct WorkspaceComposerSkillPanel: View {
    let query: String
    let select: (WorkspaceSkillReference) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelHeader(title: "Skills", symbol: "sparkles", refresh: nil)

            ForEach(filteredSkills.prefix(6)) { skill in
                Button {
                    select(skill)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: skill.symbol)
                            .font(AppFont.caption(weight: .bold))
                            .foregroundStyle(.blue)
                            .frame(width: 22, height: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(skill.promptPrefix)
                                .font(AppFont.caption(weight: .bold))
                                .foregroundStyle(.primary)
                            Text(skill.subtitle)
                                .font(AppFont.caption2())
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemFill).opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .workspaceGlass(cornerRadius: 18)
    }

    private var filteredSkills: [WorkspaceSkillReference] {
        guard !query.isEmpty else { return WorkspaceSkillReference.defaults }
        return WorkspaceSkillReference.defaults.filter {
            $0.title.lowercased().contains(query)
                || $0.promptPrefix.lowercased().contains(query)
                || $0.subtitle.lowercased().contains(query)
        }
    }
}

@ViewBuilder
@MainActor
private func panelHeader(
    title: String,
    symbol: String,
    refresh: (() -> Void)?
) -> some View {
    HStack(spacing: 8) {
        Image(systemName: symbol)
            .font(AppFont.caption(weight: .bold))
            .foregroundStyle(.blue)
        Text(title)
            .font(AppFont.caption(weight: .bold))
            .foregroundStyle(.secondary)
        Spacer(minLength: 0)
        if let refresh {
            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(AppFont.caption2(weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct QueuedDraftsPanel: View {
    let prompts: [QueuedWorkspacePrompt]
    let edit: (UUID) -> Void
    let remove: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .font(AppFont.caption(weight: .bold))
                    .foregroundStyle(.blue)
                Text("\(prompts.count) queued follow-up\(prompts.count == 1 ? "" : "s")")
                    .font(AppFont.caption(weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            ForEach(prompts.prefix(3)) { prompt in
                Button {
                    edit(prompt.id)
                } label: {
                    HStack(spacing: 10) {
                        Text(prompt.prompt)
                            .font(AppFont.caption())
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        Button {
                            remove(prompt.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(AppFont.caption2(weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, height: 22)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove queued prompt")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemFill).opacity(0.38), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit queued prompt")
            }

            if prompts.count > 3 {
                Text("+\(prompts.count - 3) more")
                    .font(AppFont.caption2(weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .workspaceGlass(cornerRadius: 18)
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
    @Binding var composerMode: WorkspaceComposerMode
    @Binding var requireApprovalForWrites: Bool

    let isAgentRunning: Bool
    let canSend: Bool
    let hasQueuedPrompts: Bool
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

            modeMenu

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
                if canSend {
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
                    .accessibilityLabel("Queue follow-up")
                }

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
                .disabled(!canSend)
                .accessibilityLabel("Send message")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    private var modeMenu: some View {
        Menu {
            ForEach(WorkspaceComposerMode.allCases) { mode in
                Button {
                    HapticFeedback.shared.triggerImpactFeedback(style: .light)
                    composerMode = mode
                } label: {
                    if composerMode == mode {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Label(mode.title, systemImage: mode.symbol)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: composerMode.symbol)
                    .font(.caption2.weight(.bold))
                Text(composerMode.title)
                    .font(AppFont.caption(weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(AppFont.system(size: 8, weight: .bold))
            }
            .foregroundStyle(composerMode == .plan ? .orange : .blue)
            .contentShape(Capsule())
        }
    }

    private var sendIconColor: Color {
        canSend ? Color(.systemBackground) : Color(.systemGray2)
    }

    private var sendBackgroundColor: Color {
        canSend ? Color(.label) : Color(.systemGray5)
    }
}
