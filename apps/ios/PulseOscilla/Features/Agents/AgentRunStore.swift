import Foundation
import Observation

@MainActor
@Observable
final class AgentRunStore {
    var streamId = "agent_\(UUID().uuidString)"
    var provider: AgentProviderKind = .codex
    var prompt = ""
    var customCommand = ""
    var requireApprovalForWrites = true

    func run(using connection: BridgeConnection) async {
        do {
            try await connection.send(
                capability: .agentRun,
                streamId: streamId,
                payload: AgentRunPayload(
                    provider: provider,
                    prompt: prompt,
                    mode: "interactive",
                    allowedTools: nil,
                    requireApprovalForWrites: requireApprovalForWrites,
                    customCommand: provider == .custom ? customCommand : nil
                )
            )
        } catch {
            connection.eventLog.append("Agent run failed: \(error.localizedDescription)")
        }
    }
}

