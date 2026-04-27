import SwiftUI

struct GitStatusView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store = GitStore()
    @State private var selectedOutput: GitOutput = .status

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeroHeader(
                    eyebrow: "Git controls",
                    title: "Inspect and ship from iPhone.",
                    subtitle: "Git commands run on the host inside the selected workspace.",
                    symbol: "point.3.connected.trianglepath.dotted"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                    ActionCard(title: "Status", subtitle: "Current branch and changes", symbol: "checklist", tint: OscillaPalette.moss, actionTitle: "Run Status") {
                        Task { await store.status(using: environment.connection) }
                    }
                    ActionCard(title: "Diff", subtitle: "Review unstaged changes", symbol: "plus.forwardslash.minus", tint: OscillaPalette.ink, actionTitle: "Show Diff") {
                        Task { await store.diff(using: environment.connection) }
                    }
                    ActionCard(title: "Branches", subtitle: "List local and remote refs", symbol: "arrow.triangle.branch", tint: .blue, actionTitle: "List Branches") {
                        Task { await store.branches(using: environment.connection) }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Label("Commit", systemImage: "shippingbox.fill")
                        .font(.headline)
                    TextField("Commit message", text: $store.commitMessage, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task { await store.commit(using: environment.connection) }
                    } label: {
                        Label("Commit Staged Changes", systemImage: "checkmark.seal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(OscillaPalette.ember)
                    .disabled(store.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .oscillaCard()

                VStack(alignment: .leading, spacing: 12) {
                    Picker("Output", selection: $selectedOutput) {
                        ForEach(GitOutput.allCases) { output in
                            Text(output.title).tag(output)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(selectedOutput.text(from: environment.connection))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(OscillaPalette.console, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .foregroundStyle(.green)
                        .frame(minHeight: 180, alignment: .topLeading)
                }
                .oscillaCard()

                EventConsoleView(events: environment.connection.eventLog)
            }
            .padding()
        }
        .oscillaBackground()
        .navigationTitle("Git")
    }
}

private enum GitOutput: String, CaseIterable, Identifiable {
    case status
    case diff
    case branches

    var id: String { rawValue }

    var title: String {
        switch self {
        case .status:
            "Status"
        case .diff:
            "Diff"
        case .branches:
            "Branches"
        }
    }

    @MainActor
    func text(from connection: BridgeConnection) -> String {
        switch self {
        case .status:
            connection.gitStatusText.isEmpty ? "Run git status." : connection.gitStatusText
        case .diff:
            connection.gitDiffText.isEmpty ? "Run git diff." : connection.gitDiffText
        case .branches:
            connection.gitBranchesText.isEmpty ? "Run branch list." : connection.gitBranchesText
        }
    }
}
