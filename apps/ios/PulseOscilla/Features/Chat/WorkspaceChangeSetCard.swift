import SwiftUI

struct WorkspaceChangeSetCard: View {
    @Environment(AppEnvironment.self) private var environment
    let diffText: String

    @State private var isShowingReview = false

    private var changeSet: WorkspaceChangeSet {
        WorkspaceDiffParser.parse(diffText)
    }

    var body: some View {
        let changeSet = changeSet

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "plus.forwardslash.minus")
                    .font(AppFont.caption(weight: .bold))
                    .foregroundStyle(.blue)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(changeSet.isEmpty ? "No code changes" : "\(changeSet.files.count) changed file\(changeSet.files.count == 1 ? "" : "s")")
                        .font(AppFont.body(weight: .bold))
                    Text("+\(changeSet.totalAdditions) -\(changeSet.totalDeletions)")
                        .font(AppFont.mono(.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button("Review") {
                    isShowingReview = true
                }
                .font(AppFont.caption(weight: .bold))
                .buttonStyle(.bordered)
                .disabled(changeSet.isEmpty)
            }

            ForEach(changeSet.files.prefix(4)) { file in
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(AppFont.caption())
                        .foregroundStyle(.secondary)
                    Text(file.path)
                        .font(AppFont.caption(weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    Text("+\(file.additions)")
                        .font(AppFont.mono(.caption2))
                        .foregroundStyle(.green)
                    Text("-\(file.deletions)")
                        .font(AppFont.mono(.caption2))
                        .foregroundStyle(.red)
                }
            }

            if changeSet.files.count > 4 {
                Text("+\(changeSet.files.count - 4) more files")
                    .font(AppFont.caption2(weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .workspaceGlass(cornerRadius: 18, interactive: true)
        .sheet(isPresented: $isShowingReview) {
            WorkspaceDiffReviewSheet(changeSet: changeSet)
                .environment(environment)
        }
    }
}

private struct WorkspaceDiffReviewSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    let changeSet: WorkspaceChangeSet

    @State private var selectedFileId: String?
    @State private var commitMessage = ""
    @State private var isRunningAction = false
    @State private var errorMessage: String?

    private var selectedFile: WorkspaceChangedFile? {
        if let selectedFileId {
            return changeSet.files.first { $0.id == selectedFileId }
        }
        return changeSet.files.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryHeader

                if changeSet.files.isEmpty {
                    ContentUnavailableView("No changes", systemImage: "checkmark.circle", description: Text("There is no diff to review."))
                } else {
                    filePicker
                    Divider()
                    diffScroll
                }

                actionBar
            }
            .navigationTitle("Review Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Git action failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(changeSet.files.count) changed file\(changeSet.files.count == 1 ? "" : "s")")
                    .font(AppFont.headline())
                Text("+\(changeSet.totalAdditions) -\(changeSet.totalDeletions)")
                    .font(AppFont.mono(.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
    }

    private var filePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(changeSet.files) { file in
                    Button {
                        selectedFileId = file.id
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(file.displayName)
                                .font(AppFont.caption(weight: .bold))
                                .lineLimit(1)
                            Text("+\(file.additions) -\(file.deletions)")
                                .font(AppFont.mono(.caption2))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            selectedFile?.id == file.id ? Color.blue.opacity(0.16) : Color(.secondarySystemFill).opacity(0.42),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }

    private var diffScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let selectedFile {
                    HStack {
                        Text(selectedFile.path)
                            .font(AppFont.body(weight: .bold))
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        Button(role: .destructive) {
                            Task { await restore(file: selectedFile) }
                        } label: {
                            Label("Revert", systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRunningAction)
                    }

                    ForEach(selectedFile.hunks) { hunk in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(hunk.header)
                                .font(AppFont.mono(.caption))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemFill).opacity(0.48))

                            ForEach(hunk.lines) { line in
                                Text(line.text.isEmpty ? " " : line.text)
                                    .font(AppFont.mono(.caption))
                                    .foregroundStyle(lineForeground(line.kind))
                                    .textSelection(.enabled)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(lineBackground(line.kind))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .padding()
        }
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            TextField("Commit message", text: $commitMessage)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button {
                    Task { await stageAll() }
                } label: {
                    Label("Stage All", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isRunningAction || changeSet.files.isEmpty)

                Button {
                    Task { await commitAndPush() }
                } label: {
                    Label("Commit & Push", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunningAction || commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .background(.bar)
    }

    private func lineForeground(_ kind: WorkspaceDiffLine.Kind) -> Color {
        switch kind {
        case .addition:
            .green
        case .deletion:
            .red
        case .metadata:
            .secondary
        case .context:
            .primary
        }
    }

    private func lineBackground(_ kind: WorkspaceDiffLine.Kind) -> Color {
        switch kind {
        case .addition:
            Color.green.opacity(0.10)
        case .deletion:
            Color.red.opacity(0.10)
        case .metadata:
            Color(.secondarySystemFill).opacity(0.22)
        case .context:
            Color.clear
        }
    }

    private func restore(file: WorkspaceChangedFile) async {
        await runGitAction {
            try await environment.connection.send(capability: .gitRestore, payload: PathPayload(path: file.path))
        }
    }

    private func stageAll() async {
        await runGitAction {
            try await environment.connection.send(capability: .gitStage, payload: EmptyPayload())
        }
    }

    private func commitAndPush() async {
        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        await runGitAction {
            try await environment.connection.send(capability: .gitStage, payload: EmptyPayload())
            try await environment.connection.send(capability: .gitCommit, payload: GitCommitPayload(message: message))
            try await environment.connection.send(capability: .gitPush, payload: EmptyPayload())
        }
    }

    private func runGitAction(_ action: () async throws -> Void) async {
        isRunningAction = true
        defer { isRunningAction = false }

        do {
            try await action()
            HapticFeedback.shared.triggerNotificationFeedback(.success)
        } catch {
            errorMessage = error.localizedDescription
            HapticFeedback.shared.triggerNotificationFeedback(.error)
        }
    }
}
