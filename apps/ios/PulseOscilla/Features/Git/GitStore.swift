import Foundation
import Observation

@MainActor
@Observable
final class GitStore {
    var commitMessage = ""

    func status(using connection: BridgeConnection) async {
        await send(.gitStatus, using: connection)
    }

    func diff(using connection: BridgeConnection) async {
        await send(.gitDiff, using: connection)
    }

    func branches(using connection: BridgeConnection) async {
        await send(.gitBranch, using: connection)
    }

    func commit(using connection: BridgeConnection) async {
        do {
            try await connection.send(capability: .gitCommit, payload: GitCommitPayload(message: commitMessage))
        } catch {
            connection.eventLog.append("git commit failed: \(error.localizedDescription)")
        }
    }

    private func send(_ capability: Capability, using connection: BridgeConnection) async {
        do {
            try await connection.send(capability: capability, payload: EmptyPayload())
        } catch {
            connection.eventLog.append("\(capability.rawValue) failed: \(error.localizedDescription)")
        }
    }
}

