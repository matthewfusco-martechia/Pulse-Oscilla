import SwiftUI

struct WorkspaceWorkItemBurst: View {
    let items: [AgentWorkItem]

    @State private var isExpanded = false

    private let collapsedCount = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(visibleItems) { item in
                WorkspaceWorkItemRow(item: item)
            }

            if hiddenCount > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(AppFont.caption2(weight: .bold))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        Text(isExpanded ? "Show fewer tool calls" : "+\(hiddenCount) more tool calls")
                            .font(AppFont.caption(weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var visibleItems: [AgentWorkItem] {
        isExpanded ? items : Array(items.prefix(collapsedCount))
    }

    private var hiddenCount: Int {
        max(items.count - collapsedCount, 0)
    }
}

private struct WorkspaceWorkItemRow: View {
    let item: AgentWorkItem

    var body: some View {
        let commandDisplay = humanizedCommand
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(AppFont.caption(weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 4) {
                if let commandDisplay {
                    HStack(spacing: 4) {
                        Text(commandDisplay.verb)
                            .font(AppFont.subheadline(weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(commandDisplay.target)
                            .font(AppFont.subheadline())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                } else {
                    Text(item.title)
                        .font(AppFont.caption(weight: .bold))
                        .foregroundStyle(.primary)
                }

                if shouldShowDetail, !item.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.detail.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(AppFont.mono(.caption2))
                        .foregroundStyle(.secondary)
                        .lineLimit(8)
                        .textSelection(.enabled)
                }

                if let path = item.path, !path.isEmpty {
                    Text(path)
                        .font(AppFont.mono(.caption2))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemFill).opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var humanizedCommand: WorkspaceCommandHumanizer.Info? {
        guard item.kind == "tool.started" || item.kind == "tool.completed" || item.kind == "shell.output" else {
            return nil
        }
        let detail = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !detail.isEmpty else { return nil }
        if detail.contains("\n"), !detail.hasPrefix("exec\n") {
            return nil
        }
        let command = detail.hasPrefix("exec\n")
            ? detail.replacingOccurrences(of: "exec\n", with: "")
            : detail
        return WorkspaceCommandHumanizer.humanize(command, isRunning: item.state == .running)
    }

    private var shouldShowDetail: Bool {
        humanizedCommand == nil || item.state == .failed || item.kind == "shell.output"
    }

    private var tint: Color {
        switch item.state {
        case .running:
            .blue
        case .completed:
            .green
        case .blocked:
            .orange
        case .failed:
            .red
        }
    }

    private var symbol: String {
        switch item.kind {
        case "approval.requested":
            "hand.raised.fill"
        case "file.changed":
            "doc.badge.gearshape"
        case "diff.available":
            "plus.forwardslash.minus"
        case "shell.output":
            "terminal"
        case "run.completed":
            "checkmark.circle"
        case "tool.started":
            "play.fill"
        case "tool.completed":
            "checkmark"
        default:
            "circle.fill"
        }
    }
}
