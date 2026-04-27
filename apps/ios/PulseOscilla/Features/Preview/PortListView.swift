import SwiftUI

struct PortListView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store = PreviewStore()
    @State private var selectedPort: PortDescriptor?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeroHeader(
                    eyebrow: "Dev server awareness",
                    title: "Find local ports fast.",
                    subtitle: "The host scans listening processes and returns candidate localhost previews for mobile inspection.",
                    symbol: "safari.fill"
                )

                ActionCard(
                    title: "Running Ports",
                    subtitle: "Detect Vite, Next, Metro, Rails, Django, and other local services.",
                    symbol: "network",
                    tint: .blue,
                    actionTitle: "Refresh Ports"
                ) {
                    Task { await store.refresh(using: environment.connection) }
                }

                if !environment.connection.ports.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detected Services")
                            .font(.headline)
                        ForEach(environment.connection.ports) { port in
                            Button {
                                selectedPort = port
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "network")
                                        .foregroundStyle(.blue)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(port.url)
                                            .font(.subheadline.weight(.semibold))
                                        Text([port.process, port.protocol].compactMap { $0 }.joined(separator: " • "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(port.port)")
                                        .font(.caption.monospacedDigit().weight(.bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.blue.opacity(0.12), in: Capsule())
                                }
                                .padding(12)
                                .background(.white.opacity(0.38), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .oscillaCard()
                }

                EventConsoleView(
                    events: environment.connection.eventLog,
                    emptyMessage: "Detected port data will stream back from the host."
                )
            }
            .padding()
        }
        .oscillaBackground()
        .navigationTitle("Previews")
        .sheet(item: $selectedPort) { port in
            NavigationStack {
                if let url = URL(string: port.url) {
                    DevPreviewWebView(url: url)
                        .ignoresSafeArea(edges: .bottom)
                        .navigationTitle(":\(port.port)")
                        .navigationBarTitleDisplayMode(.inline)
                } else {
                    ContentUnavailableView("Invalid URL", systemImage: "exclamationmark.triangle", description: Text(port.url))
                }
            }
        }
    }
}
