import Foundation
import Observation

@MainActor
@Observable
final class TerminalSessionStore {
    var streamId = "term_\(UUID().uuidString)"
    var input = ""
    var cwd = "."

    func start(using connection: BridgeConnection) async {
        do {
            try await connection.send(
                capability: .terminalCreate,
                streamId: streamId,
                payload: TerminalCreatePayload(shell: nil, cwd: cwd, cols: 96, rows: 32)
            )
        } catch {
            connection.eventLog.append("Terminal start failed: \(error.localizedDescription)")
        }
    }

    func sendInput(using connection: BridgeConnection) async {
        let command = input
        input = ""
        do {
            try await connection.send(
                capability: .terminalStdin,
                streamId: streamId,
                payload: TerminalInputPayload(data: "\(command)\n")
            )
        } catch {
            connection.eventLog.append("Terminal input failed: \(error.localizedDescription)")
        }
    }
}

