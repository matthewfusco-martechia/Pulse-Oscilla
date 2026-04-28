import SwiftUI
import UIKit

struct WorkspaceMessageRow: View {
    let message: AgentChatMessage
    var showsAssistantHeader = true
    var showsAssistantActions = true

    var body: some View {
        HStack(alignment: .bottom) {
            if message.role == .user {
                Spacer(minLength: 52)
                userBubble
            } else {
                messageContent
                    .frame(maxWidth: message.role == .assistant ? .infinity : 430, alignment: .leading)

                Spacer(minLength: 24)
            }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        switch message.kind {
        case .chat:
            if message.role == .assistant {
                assistantBubble
            } else {
                WorkspaceStatusCard(message: message, bodyText: displayBody)
            }
        case .thinking:
            WorkspaceThinkingCard(message: message, bodyText: displayBody)
        case .toolActivity:
            WorkspaceStatusCard(message: message, bodyText: displayBody)
        case .fileChange:
            WorkspaceFileChangeCard(message: message, bodyText: displayBody)
        case .commandExecution:
            WorkspaceCommandExecutionCard(message: message, bodyText: displayBody)
        case .userInputPrompt:
            WorkspaceApprovalCard(message: message, bodyText: displayBody)
        }
    }

    private var userBubble: some View {
        Text(message.body)
            .font(AppFont.body())
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color(.tertiarySystemFill).opacity(0.80),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(.separator).opacity(0.08), lineWidth: 1)
            }
            .frame(maxWidth: 330, alignment: .trailing)
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.body
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsAssistantHeader, let title = message.title, !title.isEmpty {
                WorkspaceMessageHeader(title: title, message: message)
            }

            if !message.workItems.isEmpty {
                WorkspaceWorkItemBurst(items: message.workItems)
            }

            if !displayBody.isEmpty {
                WorkspaceStreamingTextView(text: displayBody, isStreaming: message.isStreaming || message.status == .streaming)
            } else if message.isStreaming || message.status == .streaming {
                WorkspaceRunningIndicator(label: "Streaming from the Mac")
            }

            if message.status == .failed, displayBody.isEmpty {
                Text("The agent stopped before returning a visible answer.")
                    .font(AppFont.body())
                    .foregroundStyle(.red)
            }

            if showsAssistantActions, message.role == .assistant, message.status != .streaming, !displayBody.isEmpty {
                WorkspaceAssistantActionRow(copyText: displayBody)
            }
        }
        .padding(.vertical, 2)
    }

    private var displayBody: String {
        WorkspaceTimelineReducer.timelineDisplayText(for: message)
    }

}

private struct WorkspaceStatusCard: View {
    let message: AgentChatMessage
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WorkspaceMessageHeader(title: title, message: message)

            if !bodyText.isEmpty {
                Text(bodyText)
                    .font(AppFont.mono(.callout))
                    .foregroundStyle(message.status == .failed ? Color.red.opacity(0.95) : .secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if message.isStreaming || message.status == .streaming {
                WorkspaceRunningIndicator(label: "Streaming from the Mac")
            }
        }
        .padding(16)
        .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        }
    }

    private var title: String {
        message.title ?? "Activity"
    }

    private var tint: Color {
        switch message.status {
        case .failed:
            Color.red.opacity(0.08)
        case .needsApproval:
            Color.orange.opacity(0.08)
        case .completed:
            Color(.secondarySystemFill).opacity(0.48)
        case .streaming:
            Color(.secondarySystemFill).opacity(0.48)
        case .ready:
            Color(.secondarySystemFill).opacity(0.48)
        }
    }

    private var stroke: Color {
        switch message.status {
        case .failed:
            Color.red.opacity(0.24)
        case .needsApproval:
            Color.orange.opacity(0.24)
        case .streaming:
            Color(.separator).opacity(0.08)
        case .completed, .ready:
            Color(.separator).opacity(0.08)
        }
    }
}

private struct WorkspaceThinkingCard: View {
    let message: AgentChatMessage
    let bodyText: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(AppFont.caption2(weight: .bold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    WorkspaceMessageHeader(title: message.title ?? "Thinking", message: message)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded, !bodyText.isEmpty {
                Text(bodyText)
                    .font(AppFont.mono(.caption))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if message.isStreaming || message.status == .streaming {
                WorkspaceRunningIndicator(label: "Thinking")
            }
        }
        .padding(14)
        .background(Color(.secondarySystemFill).opacity(0.42), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct WorkspaceFileChangeCard: View {
    let message: AgentChatMessage
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WorkspaceMessageHeader(title: message.title ?? "File changed", message: message)

            if let fileName {
                HStack(spacing: 8) {
                    Text(fileName)
                        .font(AppFont.body(weight: .semibold))
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let counts = diffCounts {
                        Text("+\(counts.additions)")
                            .font(AppFont.mono(.caption))
                            .foregroundStyle(.green)
                        Text("-\(counts.deletions)")
                            .font(AppFont.mono(.caption))
                            .foregroundStyle(.red)
                    }

                    Spacer(minLength: 0)
                }
            }

            if !bodyText.isEmpty, bodyText != fileName {
                Text(bodyText)
                    .font(AppFont.mono(.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
                    .textSelection(.enabled)
            }
        }
        .padding(15)
        .background(Color(.secondarySystemFill).opacity(0.42), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var fileName: String? {
        let candidate = message.workItems.first?.path ?? message.title ?? bodyText
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return (trimmed as NSString).lastPathComponent.isEmpty ? trimmed : (trimmed as NSString).lastPathComponent
    }

    private var diffCounts: (additions: Int, deletions: Int)? {
        let regex = try? NSRegularExpression(pattern: #"(\+|-)(\d+)"#)
        let text = bodyText as NSString
        let matches = regex?.matches(in: bodyText, range: NSRange(location: 0, length: text.length)) ?? []
        var additions = 0
        var deletions = 0
        for match in matches where match.numberOfRanges == 3 {
            let sign = text.substring(with: match.range(at: 1))
            let value = Int(text.substring(with: match.range(at: 2))) ?? 0
            if sign == "+" {
                additions += value
            } else {
                deletions += value
            }
        }
        return additions == 0 && deletions == 0 ? nil : (additions, deletions)
    }
}

private struct WorkspaceApprovalCard: View {
    @Environment(AppEnvironment.self) private var environment

    let message: AgentChatMessage
    let bodyText: String
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WorkspaceMessageHeader(title: message.title ?? "Approval needed", message: message)

            Text(bodyText.isEmpty ? "The agent needs permission before it continues." : bodyText)
                .font(AppFont.body())
                .foregroundStyle(.primary)
                .textSelection(.enabled)

            HStack(spacing: 10) {
                Button {
                    submit(approved: false)
                } label: {
                    Label("Deny", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(isSubmitting || message.status == .completed)

                Button {
                    submit(approved: true)
                } label: {
                    Label("Approve", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isSubmitting || message.status == .completed)
            }
            .font(AppFont.subheadline(weight: .semibold))

            if isSubmitting {
                WorkspaceRunningIndicator(label: "Sending response to the Mac")
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.orange.opacity(0.22), lineWidth: 1)
        }
    }

    private func submit(approved: Bool) {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            await environment.connection.respondToAgentApproval(messageId: message.id, approved: approved)
            await MainActor.run {
                isSubmitting = false
            }
        }
    }
}

private struct WorkspaceCommandExecutionCard: View {
    let message: AgentChatMessage
    let bodyText: String

    @State private var isShowingDetails = false

    private var presentation: WorkspaceCommandPresentation {
        WorkspaceCommandPresentation(message: message, bodyText: bodyText)
    }

    var body: some View {
        Button {
            isShowingDetails = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "terminal")
                    .font(AppFont.caption(weight: .bold))
                    .foregroundStyle(presentation.accentColor)
                    .frame(width: 22, height: 22)

                HStack(spacing: 4) {
                    Text(presentation.display.verb)
                        .font(AppFont.subheadline(weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(presentation.display.target)
                        .font(AppFont.subheadline())
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

                Spacer(minLength: 6)

                Text(presentation.statusLabel)
                    .font(AppFont.mono(.caption))
                    .foregroundStyle(presentation.accentColor.opacity(message.status == .completed ? 0.65 : 1))

                Image(systemName: "chevron.right")
                    .font(AppFont.caption2(weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(presentation.tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isShowingDetails) {
            WorkspaceCommandDetailSheet(presentation: presentation)
                .presentationDetents([.fraction(0.36), .medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct WorkspaceCommandDetailSheet: View {
    let presentation: WorkspaceCommandPresentation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Command", systemImage: "terminal.fill")
                        .font(AppFont.mono(.caption))
                        .foregroundStyle(presentation.accentColor)

                    Text(presentation.command)
                        .font(AppFont.mono(.callout))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                HStack {
                    Text("Status")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(presentation.statusLabel)
                        .font(.caption.monospaced())
                        .foregroundStyle(presentation.accentColor)
                }

                if !presentation.output.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Output")
                            .font(AppFont.mono(.caption))
                            .foregroundStyle(.secondary)

                        Text(presentation.output)
                            .font(AppFont.mono(.caption))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

private struct WorkspaceCommandPresentation {
    let command: String
    let output: String
    let statusLabel: String
    let accentColor: Color
    let tint: Color
    let stroke: Color
    let display: WorkspaceCommandHumanizer.Info

    init(message: AgentChatMessage, bodyText: String) {
        let parsed = Self.parseCommandBody(bodyText.isEmpty ? message.body : bodyText)
        command = parsed.command
        output = parsed.output
        statusLabel = Self.statusLabel(for: message.status)
        accentColor = Self.accentColor(for: message.status)
        tint = Self.tint(for: message.status)
        stroke = Self.stroke(for: message.status)
        display = WorkspaceCommandHumanizer.humanize(command, isRunning: message.status == .streaming || message.isStreaming)
    }

    private static func parseCommandBody(_ raw: String) -> (command: String, output: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ("Command", "")
        }

        let lines = trimmed.components(separatedBy: .newlines)
        if lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "exec" {
            let command = lines.dropFirst().first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Command"
            let output = lines.dropFirst(2).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return (command, output)
        }

        if let range = trimmed.range(of: " started: ") {
            let command = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (command.isEmpty ? trimmed : command, "")
        }

        let command = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
        let output = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (command, output)
    }

    private static func statusLabel(for status: AgentChatStatus) -> String {
        switch status {
        case .streaming:
            "running"
        case .completed:
            "completed"
        case .failed:
            "failed"
        case .needsApproval:
            "waiting"
        case .ready:
            "queued"
        }
    }

    private static func accentColor(for status: AgentChatStatus) -> Color {
        switch status {
        case .streaming:
            .blue
        case .completed:
            .secondary
        case .failed:
            .red
        case .needsApproval:
            .orange
        case .ready:
            .secondary
        }
    }

    private static func tint(for status: AgentChatStatus) -> Color {
        switch status {
        case .streaming:
            Color(.secondarySystemFill).opacity(0.48)
        case .completed:
            Color(.secondarySystemFill).opacity(0.48)
        case .failed:
            Color.red.opacity(0.08)
        case .needsApproval:
            Color.orange.opacity(0.08)
        case .ready:
            Color(.secondarySystemFill).opacity(0.48)
        }
    }

    private static func stroke(for status: AgentChatStatus) -> Color {
        switch status {
        case .streaming:
            Color.blue.opacity(0.24)
        case .completed:
            Color.white.opacity(0.10)
        case .failed:
            Color.red.opacity(0.48)
        case .needsApproval:
            Color.orange.opacity(0.36)
        case .ready:
            Color.white.opacity(0.10)
        }
    }
}

private struct WorkspaceAssistantActionRow: View {
    let copyText: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                UIPasteboard.general.string = copyText
                withAnimation(.easeInOut(duration: 0.16)) {
                    copied = true
                }
                Task {
                    try? await Task.sleep(for: .seconds(1.4))
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            copied = false
                        }
                    }
                }
            } label: {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(AppFont.caption(weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}

private struct WorkspaceMessageHeader: View {
    let title: String
    let message: AgentChatMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: message.provider?.symbol ?? statusSymbol)
                .font(AppFont.caption(weight: .semibold))
                .foregroundStyle(statusColor)

            Text(title)
                .font(AppFont.subheadline(weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if message.status == .needsApproval {
                Text("Needs approval")
                    .font(AppFont.caption2(weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.14), in: Capsule())
            }

            if message.deliveryState == .failed || message.status == .failed {
                Text("Failed")
                    .font(AppFont.caption2(weight: .bold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.14), in: Capsule())
            }
        }
    }

    private var statusSymbol: String {
        switch message.status {
        case .failed:
            "exclamationmark.triangle"
        case .completed:
            "checkmark.circle"
        case .streaming:
            "dot.radiowaves.left.and.right"
        case .needsApproval:
            "hand.raised"
        case .ready:
            "info.circle"
        }
    }

    private var statusColor: Color {
        switch message.status {
        case .failed:
            .red
        case .completed:
            .green
        case .needsApproval:
            .orange
        case .streaming:
            .blue
        case .ready:
            .secondary
        }
    }
}
