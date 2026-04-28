import SwiftUI

struct SecuritySettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage(AppFont.storageKey) private var appFontStyleRawValue = AppFont.defaultStoredStyleRawValue
    @AppStorage(WorkspaceGlassPreference.storageKey) private var useLiquidGlass = true

    private var appFontStyleBinding: Binding<AppFont.Style> {
        Binding(
            get: { AppFont.Style(rawValue: appFontStyleRawValue) ?? AppFont.defaultStyle },
            set: { appFontStyleRawValue = $0.rawValue }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                settingsHeader

                SettingsAppearanceCard(appFontStyle: appFontStyleBinding, useLiquidGlass: $useLiquidGlass)

                if let session = environment.connection.acceptedSession {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Active Session", systemImage: "checkmark.seal.fill")
                            .font(AppFont.headline())
                            .foregroundStyle(.green)
                        LabeledContent("Session ID", value: session.sessionId)
                        LabeledContent("Workspace", value: session.workspaceRoot)
                        LabeledContent("Capabilities", value: "\(session.capabilities.count)")
                    }
                    .font(AppFont.callout())
                    .settingsCard()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Connection Diagnostics", systemImage: "stethoscope")
                        .font(AppFont.headline())
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
                            .font(AppFont.caption())
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                .font(AppFont.callout())
                .settingsCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Session Controls")
                        .font(AppFont.headline())
                    Button(role: .destructive) {
                        HapticFeedback.shared.triggerImpactFeedback(style: .light)
                        environment.connection.disconnect()
                    } label: {
                        Label("Disconnect Device", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .settingsCard()
            }
            .padding()
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("Security")
        .adaptiveNavigationBar()
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("Settings")
                .font(AppFont.title2())
                .foregroundStyle(.primary)

            Text("Local-first controls for appearance, trusted sessions, and bridge diagnostics.")
                .font(AppFont.body())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
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

private struct SettingsAppearanceCard: View {
    @Binding var appFontStyle: AppFont.Style
    @Binding var useLiquidGlass: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(AppFont.headline())

            HStack {
                Text("Font")
                    .font(AppFont.callout())
                Spacer()
                Picker("Font", selection: $appFontStyle) {
                    ForEach(AppFont.Style.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Text(appFontStyle.subtitle)
                .font(AppFont.caption())
                .foregroundStyle(.secondary)

            if GlassPreference.isSupported {
                Divider()

                Toggle("Liquid Glass", isOn: $useLiquidGlass)
                    .font(AppFont.callout())

                Text(useLiquidGlass ? "Liquid Glass effects are enabled." : "Using the material fallback.")
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
            }
        }
        .settingsCard()
    }
}

private extension View {
    func settingsCard() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveGlass(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
