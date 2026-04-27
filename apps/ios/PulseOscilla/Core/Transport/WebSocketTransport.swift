import Foundation

actor WebSocketTransport {
    private var task: URLSessionWebSocketTask?

    func connect(to url: URL) {
        let task = URLSession.shared.webSocketTask(with: url)
        self.task = task
        task.resume()
    }

    func send(_ text: String) async throws {
        guard let task else {
            throw TransportError.notConnected
        }
        try await task.send(.string(text))
    }

    func receiveString() async throws -> String {
        guard let task else {
            throw TransportError.notConnected
        }
        let message = try await task.receive()
        switch message {
        case .string(let text):
            return text
        case .data(let data):
            return String(decoding: data, as: UTF8.self)
        @unknown default:
            throw TransportError.unsupportedMessage
        }
    }

    func close() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }
}

enum TransportError: Error {
    case notConnected
    case unsupportedMessage
}

