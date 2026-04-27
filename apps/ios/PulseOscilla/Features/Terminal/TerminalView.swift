import SwiftUI

struct TerminalView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store = TerminalSessionStore()

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HeroHeader(
                        eyebrow: "PTY bridge",
                        title: "Run the host shell.",
                        subtitle: "Commands execute on your development machine with streamed output and repo-local context.",
                        symbol: "terminal.fill"
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Session")
                            .font(.headline)

                        TextField("Working directory", text: $store.cwd)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)

                        Button {
                            Task { await store.start(using: environment.connection) }
                        } label: {
                            Label("Start Shell Session", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(OscillaPalette.ink)
                    }
                    .oscillaCard()

                    EventConsoleView(
                        events: environment.connection.terminalLines,
                        emptyMessage: "Start a shell session, then send a command."
                    )
                }
                .padding()
            }

            HStack(spacing: 10) {
                TextField("Command", text: $store.input)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await store.sendInput(using: environment.connection) }
                    }

                Button {
                    Task { await store.sendInput(using: environment.connection) }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(OscillaPalette.ember)
                .disabled(store.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(.bar)
        }
        .oscillaBackground()
        .navigationTitle("Terminal")
    }
}
