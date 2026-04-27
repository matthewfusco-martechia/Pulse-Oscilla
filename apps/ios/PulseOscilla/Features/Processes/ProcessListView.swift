import SwiftUI

struct ProcessListView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store = ProcessStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeroHeader(
                    eyebrow: "Host process control",
                    title: "Inspect running work.",
                    subtitle: "List local processes and terminate stuck dev servers from the trusted bridge.",
                    symbol: "cpu.fill"
                )

                ActionCard(
                    title: "Process Table",
                    subtitle: "Refresh the host process list using ps.",
                    symbol: "list.bullet.rectangle",
                    tint: OscillaPalette.moss,
                    actionTitle: "Refresh Processes"
                ) {
                    Task { await store.refresh(using: environment.connection) }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Label("Terminate Process", systemImage: "xmark.octagon.fill")
                        .font(.headline)
                    Text("This sends SIGTERM on the host. Use it for dev servers you own.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("PID", text: $store.pidText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                        Button(role: .destructive) {
                            Task { await store.kill(using: environment.connection) }
                        } label: {
                            Label("Kill", systemImage: "xmark")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.pidText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .oscillaCard()

                Text(environment.connection.processListText.isEmpty ? "Refresh to load processes." : environment.connection.processListText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(OscillaPalette.console, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .foregroundStyle(.green)
                    .frame(minHeight: 260, alignment: .topLeading)
            }
            .padding()
        }
        .oscillaBackground()
        .navigationTitle("Processes")
    }
}

