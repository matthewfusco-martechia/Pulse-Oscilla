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
    @State private var latestUserAnchorId: UUID?
    @State private var pinnedTurnId: String?
    @State private var didInitialScroll = false
    private let bottomAnchorId = "workspace-chat-bottom-anchor"

    var body: some View {
        let timelineMessages = WorkspaceTimelineReducer.project(messages: messages)

        ScrollViewReader { proxy in
            GeometryReader { geometry in
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
                            ForEach(Array(timelineMessages.enumerated()), id: \.element.id) { index, message in
                                WorkspaceMessageRow(
                                    message: message,
                                    showsAssistantHeader: showsAssistantHeader(at: index, in: timelineMessages),
                                    showsAssistantActions: showsAssistantActions(at: index, in: timelineMessages)
                                )
                                    .id(message.id)
                            }
                        }

                        if shouldReserveActiveTurnRunway {
                            Color.clear
                                .frame(height: max(geometry.size.height * 0.72, 420))
                                .allowsHitTesting(false)
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
            }
            .onAppear {
                guard !didInitialScroll else { return }
                didInitialScroll = true
                scrollToBottom(proxy)
            }
            .onChange(of: revision) { _, _ in
                scrollAfterTimelineChange(proxy, timelineMessages: timelineMessages)
            }
            .onChange(of: isAgentRunning) { _, running in
                if !running {
                    pinnedTurnId = nil
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
        if let latestUser = timelineMessages.last(where: { $0.role == .user }),
           latestUser.id != latestUserAnchorId {
            latestUserAnchorId = latestUser.id
            pinnedTurnId = latestUser.turnId
            followsLatest = true
            scrollUserPromptToTop(proxy, id: latestUser.id)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
                scrollUserPromptToTop(proxy, id: latestUser.id)
            }
            return
        }

        guard followsLatest else { return }

        let activeTurnId = timelineMessages.last {
            $0.isStreaming || $0.status == .streaming
        }?.turnId

        if isAgentRunning,
           let pinnedTurnId,
           activeTurnId == pinnedTurnId {
            return
        }

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

    private func scrollUserPromptToTop(_ proxy: ScrollViewProxy, id: UUID) {
        withAnimation(.snappy(duration: 0.24)) {
            proxy.scrollTo(id, anchor: UnitPoint(x: 1, y: 0.08))
        }
    }

    private var shouldReserveActiveTurnRunway: Bool {
        isAgentRunning && pinnedTurnId != nil
    }

    private func showsAssistantHeader(at index: Int, in messages: [AgentChatMessage]) -> Bool {
        let message = messages[index]
        guard message.role == .assistant, message.kind == .chat else { return true }
        let turnId = message.turnId ?? message.streamId
        guard let turnId else { return true }

        return !messages[..<index].contains { previous in
            previous.role == .assistant
                && previous.kind == .chat
                && (previous.turnId ?? previous.streamId) == turnId
        }
    }

    private func showsAssistantActions(at index: Int, in messages: [AgentChatMessage]) -> Bool {
        let message = messages[index]
        guard message.role == .assistant, message.kind == .chat else { return true }
        let turnId = message.turnId ?? message.streamId
        guard let turnId else { return true }

        return !messages[(index + 1)...].contains { next in
            next.role == .assistant
                && next.kind == .chat
                && (next.turnId ?? next.streamId) == turnId
        }
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
