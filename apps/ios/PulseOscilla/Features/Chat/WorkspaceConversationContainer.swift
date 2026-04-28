import SwiftUI

struct WorkspaceConversationContainer: View {
    let messages: [AgentChatMessage]
    let revision: Int
    let isAgentRunning: Bool
    let workspace: WorkspaceDescriptor?
    let sendSuggestion: (String) -> Void
    let onTapOutsideComposer: () -> Void

    @State private var followsLatest = true
    @State private var lastAssistantAnchorId: UUID?
    private let bottomAnchorId = "workspace-chat-bottom-anchor"

    var body: some View {
        let timelineMessages = WorkspaceTimelineReducer.project(messages: messages)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if timelineMessages.isEmpty {
                        WorkspaceEmptyState(
                            workspace: workspace,
                            sendSuggestion: sendSuggestion
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 70)
                    } else {
                        ForEach(timelineMessages) { message in
                            WorkspaceMessageRow(message: message)
                                .id(message.id)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorId)
                        .allowsHitTesting(false)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTapOutsideComposer)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12).onChanged { _ in
                    followsLatest = false
                }
            )
            .overlay(alignment: .bottom) {
                if !followsLatest, !timelineMessages.isEmpty {
                    Button {
                        followsLatest = true
                        scrollToBottom(proxy)
                    } label: {
                        Label("Latest", systemImage: "arrow.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .workspaceGlass(cornerRadius: 18, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, isAgentRunning ? 48 : 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if isAgentRunning {
                    WorkspaceStreamingDock()
                        .padding(.horizontal, 18)
                        .padding(.bottom, 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                scrollToBottom(proxy)
            }
            .onChange(of: revision) { _, _ in
                if followsLatest {
                    scrollAfterTimelineChange(proxy, timelineMessages: timelineMessages)
                }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard !messages.isEmpty else { return }
        withAnimation(.snappy(duration: 0.24)) {
            proxy.scrollTo(bottomAnchorId, anchor: .bottom)
        }
    }

    private func scrollAfterTimelineChange(_ proxy: ScrollViewProxy, timelineMessages: [AgentChatMessage]) {
        let activeTurnId = timelineMessages.last {
            $0.isStreaming || $0.status == .streaming
        }?.turnId

        if isAgentRunning,
           let assistantId = WorkspaceTimelineReducer.assistantResponseAnchorMessageId(
            in: timelineMessages,
            activeTurnId: activeTurnId
           ),
           assistantId != lastAssistantAnchorId {
            lastAssistantAnchorId = assistantId
            withAnimation(.snappy(duration: 0.24)) {
                proxy.scrollTo(assistantId, anchor: .top)
            }
            return
        }

        scrollToBottom(proxy)
    }
}

private struct WorkspaceStreamingDock: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Streaming from the Mac")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .workspaceGlass(cornerRadius: 18)
    }
}
