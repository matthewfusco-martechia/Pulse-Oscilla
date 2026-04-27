import SwiftUI

struct SecuritySettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeroHeader(
                    eyebrow: "Trust boundary",
                    title: "Local-first security controls.",
                    subtitle: "Session metadata lives on device; execution and repo context stay on the trusted host.",
                    symbol: "lock.shield.fill"
                )

                if let session = environment.connection.acceptedSession {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Active Session", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        LabeledContent("Session ID", value: session.sessionId)
                        LabeledContent("Workspace", value: session.workspaceRoot)
                        LabeledContent("Capabilities", value: "\(session.capabilities.count)")
                    }
                    .oscillaCard()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Connection Diagnostics", systemImage: "stethoscope")
                        .font(.headline)
                    LabeledContent("State", value: stateDescription)
                    if let endpoint = environment.connection.lastEndpoint {
                        LabeledContent("Endpoint", value: endpoint)
                    }
                    if let fingerprint = environment.connection.lastHostFingerprint {
                        LabeledContent("Host Fingerprint", value: fingerprint)
                    }
                    if let expiresAt = environment.connection.lastPairingExpiresAt {
                        LabeledContent("Pairing Expiry", value: expiresAt)
                    }
                    if let message = environment.connection.lastErrorMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                .oscillaCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Session Controls")
                        .font(.headline)
                    Button(role: .destructive) {
                        environment.connection.disconnect()
                    } label: {
                        Label("Disconnect Device", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .oscillaCard()
            }
            .padding()
        }
        .oscillaBackground()
        .navigationTitle("Security")
    }

    private var stateDescription: String {
        switch environment.connection.state {
        case .idle:
            "Idle"
        case .pairing:
            "Pairing"
        case .connected:
            "Connected"
        case .failed:
            "Failed"
        }
    }
}
