import Foundation
import Observation

@MainActor
@Observable
final class FileStore {
    var path = "."
    var selectedFile = ""
    var draftContent = ""

    func list(using connection: BridgeConnection) async {
        await send(.filesList, path: path, using: connection)
    }

    func read(using connection: BridgeConnection) async {
        await send(.filesRead, path: selectedFile, using: connection)
    }

    func write(using connection: BridgeConnection) async {
        do {
            try await connection.send(
                capability: .filesWrite,
                payload: FileWritePayload(path: selectedFile, content: draftContent, expectedSha256: nil)
            )
        } catch {
            connection.eventLog.append("File write failed: \(error.localizedDescription)")
        }
    }

    private func send(_ capability: Capability, path: String, using connection: BridgeConnection) async {
        do {
            try await connection.send(capability: capability, payload: PathPayload(path: path))
        } catch {
            connection.eventLog.append("\(capability.rawValue) failed: \(error.localizedDescription)")
        }
    }
}

