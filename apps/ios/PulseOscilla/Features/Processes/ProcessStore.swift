import Foundation
import Observation

@MainActor
@Observable
final class ProcessStore {
    var pidText = ""

    func refresh(using connection: BridgeConnection) async {
        do {
            try await connection.send(capability: .processList, payload: EmptyPayload())
        } catch {
            connection.eventLog.append("Process list failed: \(error.localizedDescription)")
        }
    }

    func kill(using connection: BridgeConnection) async {
        guard let pid = Int(pidText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            connection.eventLog.append("Enter a valid process id")
            return
        }

        do {
            try await connection.send(capability: .processKill, payload: ProcessKillPayload(pid: pid))
        } catch {
            connection.eventLog.append("Process kill failed: \(error.localizedDescription)")
        }
    }
}

