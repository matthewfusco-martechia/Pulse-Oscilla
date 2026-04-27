import SwiftUI
import UIKit

struct PairingView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var pairingPayload = ""
    @State private var isShowingScanner = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HeroHeader(
                        eyebrow: "Phone to localhost",
                        title: "Control the repo without streaming the desktop.",
                        subtitle: "Pair once with the host CLI, then run terminal commands, edit files, inspect git, launch AI agents, and preview local servers from iPhone.",
                        symbol: "iphone.gen3.radiowaves.left.and.right"
                    )

                    PairingCommandCard()

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Pairing Payload", systemImage: "qrcode.viewfinder")
                                .font(.headline)
                            Spacer()
                            Button("Scan") {
                                isShowingScanner = true
                            }
                            .buttonStyle(.bordered)
                            Button("Paste") {
                                pairingPayload = UIPasteboard.general.string ?? pairingPayload
                            }
                            .buttonStyle(.bordered)
                        }

                        TextEditor(text: $pairingPayload)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(minHeight: 180)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .background(OscillaPalette.console.opacity(0.94), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .foregroundStyle(.green)
                            .accessibilityLabel("Pairing payload")
                    }
                    .oscillaCard()

                    if let preview = pairingPreview {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Host Preview", systemImage: "desktopcomputer")
                                .font(.headline)
                            LabeledContent("Endpoint", value: preview.endpoint.absoluteString)
                            LabeledContent("Fingerprint", value: preview.fingerprint)
                            if let workspaceHint = preview.workspaceHint {
                                LabeledContent("Workspace", value: workspaceHint)
                            }
                            LabeledContent("Expires", value: preview.expiresAt)
                        }
                        .oscillaCard()
                    }

                    Button {
                        Task { await environment.connection.pair(rawPayload: pairingPayload) }
                    } label: {
                        Label(pairButtonTitle, systemImage: "lock.open.trianglebadge.exclamationmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(OscillaPalette.ink)
                    .disabled(pairingPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    statusView
                }
                .padding()
            }
            .oscillaBackground()
            .navigationTitle("Pair")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingScanner) {
                NavigationStack {
                    QRScannerView { code in
                        pairingPayload = code
                        isShowingScanner = false
                    }
                    .ignoresSafeArea()
                    .navigationTitle("Scan Pairing QR")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        Button("Cancel") {
                            isShowingScanner = false
                        }
                    }
                }
            }
        }
    }

    private var pairButtonTitle: String {
        switch environment.connection.state {
        case .pairing:
            "Pairing..."
        default:
            "Pair Secure Device"
        }
    }

    private var pairingPreview: PairingPayload? {
        try? JSONDecoder().decode(PairingPayload.self, from: Data(pairingPayload.utf8))
    }

    @ViewBuilder
    private var statusView: some View {
        switch environment.connection.state {
        case .idle:
            PairingHintCard()
        case .pairing:
            HStack(spacing: 12) {
                ProgressView()
                Text("Negotiating encrypted session with the host...")
                    .font(.subheadline.weight(.semibold))
            }
            .oscillaCard()
        case .connected:
            Label("Connected", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .oscillaCard()
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label("Pairing failed", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .oscillaCard()
        }
    }
}

private struct PairingCommandCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Start the host", systemImage: "terminal.fill")
                .font(.headline)

            Text("Run one of these from the local repo you want to control:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("npx pulse-oscilla\n# repo dev mode:\nnpm run dev -- --pairing-ttl-minutes 60 --trust-on-first-use")
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(OscillaPalette.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.green)
        }
        .oscillaCard()
    }
}

private struct PairingHintCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How pairing works")
                .font(.headline)
            PairingStep(number: "1", text: "CLI creates a short-lived pairing session.")
            PairingStep(number: "2", text: "iPhone sends its device key to the host.")
            PairingStep(number: "3", text: "Both sides derive an encrypted session key.")
        }
        .oscillaCard()
    }
}

private struct PairingStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(OscillaPalette.moss, in: Circle())
            Text(text)
                .font(.subheadline)
        }
    }
}
