import Foundation
import Observation

@MainActor
@Observable
final class PreviewStore {
    func refresh(using connection: BridgeConnection) async {
        do {
            try await connection.send(capability: .previewPorts, payload: EmptyPayload())
        } catch {
            connection.eventLog.append("Port discovery failed: \(error.localizedDescription)")
        }
    }
}

