import SwiftUI

struct FileBrowserView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store = FileStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeroHeader(
                    eyebrow: "Workspace files",
                    title: "Browse and edit through the host.",
                    subtitle: "File operations stay confined to the trusted workspace root on your development machine.",
                    symbol: "folder.fill"
                )

                VStack(alignment: .leading, spacing: 14) {
                    Label("Directory Browser", systemImage: "list.bullet.rectangle")
                        .font(.headline)
                    TextField("Directory path", text: $store.path)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task { await store.list(using: environment.connection) }
                    } label: {
                        Label("List Directory", systemImage: "arrow.down.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(OscillaPalette.moss)

                    if !environment.connection.fileEntries.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(environment.connection.fileEntries) { entry in
                                Button {
                                    if entry.kind == .directory {
                                        store.path = entry.path
                                        Task { await store.list(using: environment.connection) }
                                    } else {
                                        store.selectedFile = entry.path
                                        Task { await store.read(using: environment.connection) }
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: entry.kind.symbol)
                                            .foregroundStyle(entry.kind == .directory ? OscillaPalette.moss : OscillaPalette.ink)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(entry.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(OscillaPalette.ink)
                                            Text(entry.path)
                                                .font(.caption2.monospaced())
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        if let size = entry.size, entry.kind == .file {
                                            Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if entry.id != environment.connection.fileEntries.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .background(.white.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .oscillaCard()

                VStack(alignment: .leading, spacing: 14) {
                    Label("File Editor", systemImage: "doc.text")
                        .font(.headline)
                    TextField("File path", text: $store.selectedFile)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Read File") {
                            Task { await store.read(using: environment.connection) }
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Write Draft") {
                            Task { await store.write(using: environment.connection) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(OscillaPalette.ember)
                    }

                    TextEditor(text: $store.draftContent)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 220)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(.white.opacity(0.54), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    if let openedFile = environment.connection.openedFile {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Open: \(openedFile.path)")
                                .font(.caption.weight(.bold))
                            Text("SHA256 \(openedFile.sha256)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .oscillaCard()

                EventConsoleView(events: environment.connection.eventLog)
            }
            .padding()
        }
        .onChange(of: environment.connection.openedFile) { _, file in
            guard let file else { return }
            store.selectedFile = file.path
            store.draftContent = file.content
        }
        .oscillaBackground()
        .navigationTitle("Files")
    }
}
