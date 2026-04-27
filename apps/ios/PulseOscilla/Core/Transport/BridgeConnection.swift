import Foundation
import Observation

@MainActor
@Observable
final class BridgeConnection {
    enum State: Equatable {
        case idle
        case pairing
        case connected
        case failed(String)
    }

    var state: State = .idle
    var activeWorkspace: WorkspaceDescriptor?
    var acceptedSession: PairingAcceptedPayload?
    var eventLog: [String] = []
    var terminalLines: [String] = []
    var agentLines: [String] = []
    var fileEntries: [FileEntry] = []
    var openedFile: RemoteFile?
    var gitStatusText = ""
    var gitDiffText = ""
    var gitBranchesText = ""
    var processListText = ""
    var ports: [PortDescriptor] = []
    var lastErrorMessage: String?
    var lastEndpoint: String?
    var lastHostFingerprint: String?
    var lastPairingExpiresAt: String?

    @ObservationIgnored private let pairingManager = PairingManager()
    @ObservationIgnored private let transport = WebSocketTransport()
    @ObservationIgnored private var secureSession: SecureSession?
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()

    func pair(rawPayload: String) async {
        state = .pairing
        do {
            let result = try await pairingManager.pair(rawPayload: rawPayload, transport: transport)
            lastEndpoint = result.payload.endpoint.absoluteString
            lastHostFingerprint = result.payload.fingerprint
            lastPairingExpiresAt = result.payload.expiresAt
            secureSession = result.secureSession
            acceptedSession = result.accepted
            activeWorkspace = WorkspaceDescriptor(
                id: result.accepted.workspaceId,
                name: result.payload.workspaceHint ?? "Workspace",
                root: result.accepted.workspaceRoot,
                gitBranch: nil
            )
            state = .connected
            eventLog.append("Connected to \(result.accepted.workspaceRoot)")
            Task { await receiveLoop() }
        } catch {
            lastErrorMessage = error.localizedDescription
            state = .failed(error.localizedDescription)
            appendEvent("Pairing failed: \(error.localizedDescription)")
        }
    }

    func send<Payload: Encodable>(
        capability: Capability,
        streamId: String? = nil,
        payload: Payload
    ) async throws {
        guard let secureSession, let workspaceId = activeWorkspace?.id else {
            throw BridgeConnectionError.notConnected
        }
        let request = BridgeRequest(
            capability: capability,
            workspaceId: workspaceId,
            streamId: streamId,
            payload: payload
        )
        let requestData = try encoder.encode(request)
        let frame = try await secureSession.encrypt(requestData)
        let frameData = try encoder.encode(frame)
        try await transport.send(String(decoding: frameData, as: UTF8.self))
    }

    func disconnect() {
        Task { await transport.close() }
        secureSession = nil
        acceptedSession = nil
        activeWorkspace = nil
        state = .idle
        terminalLines.removeAll()
        agentLines.removeAll()
        fileEntries.removeAll()
        openedFile = nil
        gitStatusText = ""
        gitDiffText = ""
        gitBranchesText = ""
        processListText = ""
        ports.removeAll()
    }

    private func receiveLoop() async {
        while secureSession != nil {
            do {
                guard let secureSession else { return }
                let text = try await transport.receiveString()
                let frame = try decoder.decode(EncryptedFrame.self, from: Data(text.utf8))
                let data = try await secureSession.decrypt(frame)
                routeIncomingEnvelope(data)
            } catch {
                lastErrorMessage = error.localizedDescription
                appendEvent("Connection receive error: \(error.localizedDescription)")
                return
            }
        }
    }

    private func routeIncomingEnvelope(_ data: Data) {
        do {
            let envelope = try decoder.decode(BridgeEnvelopeRaw.self, from: data)
            switch envelope.type {
            case "response":
                try routeResponse(envelope)
            case "event":
                try routeEvent(envelope)
            case "error":
                routeError(envelope)
            default:
                appendRawEvent(data)
            }
        } catch {
            appendRawEvent(data)
        }
    }

    private func routeResponse(_ envelope: BridgeEnvelopeRaw) throws {
        guard let capability = envelope.capability else {
            appendEvent("Response \(envelope.id)")
            return
        }

        switch capability {
        case .filesList:
            fileEntries = try decodePayload([FileEntry].self, from: envelope)
            appendEvent("Listed \(fileEntries.count) files")
        case .filesRead:
            openedFile = try decodePayload(RemoteFile.self, from: envelope)
            appendEvent("Opened \(openedFile?.path ?? "file")")
        case .filesWrite:
            let result = try decodePayload(FileWriteResult.self, from: envelope)
            openedFile = openedFile.map {
                RemoteFile(path: $0.path, name: $0.name, content: $0.content, sha256: result.sha256)
            }
            appendEvent("Wrote \(result.path)")
        case .gitStatus:
            gitStatusText = commandText(try decodePayload(CommandResult.self, from: envelope))
            appendEvent("Git status updated")
        case .gitDiff:
            gitDiffText = commandText(try decodePayload(CommandResult.self, from: envelope))
            appendEvent("Git diff updated")
        case .gitBranch:
            gitBranchesText = commandText(try decodePayload(CommandResult.self, from: envelope))
            appendEvent("Git branches updated")
        case .gitCommit, .gitPush, .gitPull:
            appendEvent(commandText(try decodePayload(CommandResult.self, from: envelope)))
        case .previewPorts:
            ports = try decodePayload([PortDescriptor].self, from: envelope)
            appendEvent("Detected \(ports.count) listening ports")
        case .processList:
            processListText = try decodePayload(ProcessListResult.self, from: envelope).raw
            appendEvent("Process list updated")
        case .processKill:
            let result = try decodePayload(ProcessKillResult.self, from: envelope)
            appendEvent("Sent \(result.signal) to pid \(result.pid)")
        case .terminalCreate:
            let result = try decodePayload(TerminalCreateResult.self, from: envelope)
            terminalLines.append("PTY attached: \(result.streamId) pid=\(result.pid)")
        case .agentRun:
            let result = try decodePayload(AgentRunResult.self, from: envelope)
            agentLines.append("Agent run completed: \(result.streamId)")
        case .workspaceList, .workspaceOpen:
            appendEvent("Workspace response received")
        default:
            appendEvent("\(capability.rawValue) completed")
        }
    }

    private func routeEvent(_ envelope: BridgeEnvelopeRaw) throws {
        guard let capability = envelope.capability else {
            appendEvent("Event \(envelope.id)")
            return
        }

        switch capability {
        case .terminalCreate:
            if let output = try? decodePayload(TerminalOutputPayload.self, from: envelope) {
                terminalLines.append(output.data)
            } else {
                appendEvent("Terminal event")
            }
        case .agentRun:
            let event = try decodePayload(AgentEventPayload.self, from: envelope)
            let text = event.text ?? event.path ?? event.kind
            agentLines.append("[\(event.kind)] \(text)")
            appendEvent("Agent: \(event.kind)")
        default:
            appendEvent("\(capability.rawValue) event")
        }
    }

    private func routeError(_ envelope: BridgeEnvelopeRaw) {
        if case .object(let payload) = envelope.payload {
            let message = payload["message"]?.stringValue ?? "Bridge request failed"
            lastErrorMessage = message
            appendEvent("Error: \(message)")
            return
        }
        appendEvent("Bridge error")
    }

    private func decodePayload<Value: Decodable>(_ type: Value.Type, from envelope: BridgeEnvelopeRaw) throws -> Value {
        let data = try encoder.encode(envelope.payload)
        return try decoder.decode(type, from: data)
    }

    private func commandText(_ result: CommandResult) -> String {
        let output = [result.stdout, result.stderr]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
        if output.isEmpty {
            return "Command exited \(result.exitCode.map(String.init) ?? "unknown")"
        }
        return output
    }

    private func appendRawEvent(_ data: Data) {
        if let raw = String(data: data, encoding: .utf8) {
            appendEvent(raw)
        }
    }

    private func appendEvent(_ event: String) {
        eventLog.append(event)
        if eventLog.count > 300 {
            eventLog.removeFirst(eventLog.count - 300)
        }
    }
}

enum BridgeConnectionError: Error {
    case notConnected
}

private extension JSONValue {
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }
}
