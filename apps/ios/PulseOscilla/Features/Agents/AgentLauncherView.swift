import SwiftUI

struct AgentLauncherView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store = AgentRunStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeroHeader(
                    eyebrow: "Host-side AI",
                    title: "Run coding agents on the repo.",
                    subtitle: "Prompts execute through the host CLI, so agents see the local codebase and apply changes on the machine.",
                    symbol: "sparkles"
                )

                VStack(alignment: .leading, spacing: 16) {
                    Picker("Provider", selection: $store.provider) {
                        ForEach(AgentProviderKind.allCases) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)

                    if store.provider == .custom {
                        TextField("Custom command", text: $store.customCommand)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                    }

                    Toggle("Require approval for writes", isOn: $store.requireApprovalForWrites)
                        .toggleStyle(.switch)

                    TextEditor(text: $store.prompt)
                        .frame(minHeight: 240)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(.white.opacity(0.54), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            if store.prompt.isEmpty {
                                Text("Ask the agent to inspect, change, test, or explain this repo...")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 20)
                            }
                        }

                    Button {
                        Task { await store.run(using: environment.connection) }
                    } label: {
                        Label("Run \(store.provider.title)", systemImage: "play.sparkle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(OscillaPalette.ember)
                    .disabled(store.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .oscillaCard()

                EventConsoleView(
                    events: environment.connection.agentLines,
                    emptyMessage: "Agent output and tool events will stream here."
                )
            }
            .padding()
        }
        .oscillaBackground()
        .navigationTitle("AI Agents")
    }
}
