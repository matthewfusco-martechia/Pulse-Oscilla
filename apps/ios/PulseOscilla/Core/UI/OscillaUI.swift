import SwiftUI

enum OscillaPalette {
    static let ink = Color(red: 0.06, green: 0.08, blue: 0.10)
    static let moss = Color(red: 0.40, green: 0.53, blue: 0.36)
    static let ember = Color(red: 0.93, green: 0.43, blue: 0.22)
    static let fog = Color(red: 0.93, green: 0.91, blue: 0.86)
    static let console = Color(red: 0.03, green: 0.05, blue: 0.04)
}

struct AppBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                LinearGradient(
                    colors: [
                        OscillaPalette.fog,
                        Color(red: 0.82, green: 0.86, blue: 0.78),
                        Color(red: 0.72, green: 0.78, blue: 0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                Circle()
                    .fill(OscillaPalette.ember.opacity(0.18))
                    .frame(width: 260, height: 260)
                    .blur(radius: 40)
                    .offset(x: 140, y: -220)
                    .ignoresSafeArea()
                Circle()
                    .fill(OscillaPalette.moss.opacity(0.22))
                    .frame(width: 340, height: 340)
                    .blur(radius: 56)
                    .offset(x: -170, y: 320)
                    .ignoresSafeArea()
            }
    }
}

extension View {
    func oscillaBackground() -> some View {
        modifier(AppBackground())
    }

    func oscillaCard() -> some View {
        padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.36), lineWidth: 1)
            }
            .shadow(color: OscillaPalette.ink.opacity(0.08), radius: 18, x: 0, y: 12)
    }
}

struct HeroHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var symbol: String = "iphone.and.arrow.forward"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(OscillaPalette.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(OscillaPalette.ember)
            }

            Text(title)
                .font(.system(size: 42, weight: .black, design: .rounded))
                .lineSpacing(-4)
                .foregroundStyle(OscillaPalette.ink)
                .minimumScaleFactor(0.72)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(OscillaPalette.ink.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActionCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    var tint: Color = OscillaPalette.moss
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(tint, in: RoundedRectangle(cornerRadius: 17, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(OscillaPalette.ink)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .oscillaCard()
    }
}

struct EventConsoleView: View {
    let events: [String]
    var emptyMessage = "Bridge events will appear here."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Live Bridge", systemImage: "waveform.path.ecg")
                    .font(.headline)
                Spacer()
                Text("\(events.count)")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.16), in: Capsule())
            }
            .foregroundStyle(.white)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if events.isEmpty {
                        Text(emptyMessage)
                            .foregroundStyle(.white.opacity(0.56))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(Array(events.suffix(60).enumerated()), id: \.offset) { _, event in
                            Text(event)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.green.opacity(0.92))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(14)
            }
            .frame(minHeight: 180, maxHeight: 320)
            .background(OscillaPalette.console, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .padding(16)
        .background(OscillaPalette.ink, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct WorkspaceStatusPill: View {
    let workspace: WorkspaceDescriptor?
    let state: BridgeConnection.State

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace?.name ?? "No workspace")
                    .font(.caption.weight(.bold))
                Text(workspace?.root ?? stateTitle)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
    }

    private var indicatorColor: Color {
        switch state {
        case .connected:
            .green
        case .pairing:
            .orange
        case .failed:
            .red
        case .idle:
            .gray
        }
    }

    private var stateTitle: String {
        switch state {
        case .idle:
            "Waiting for host pairing"
        case .pairing:
            "Pairing..."
        case .connected:
            "Connected"
        case .failed(let message):
            message
        }
    }
}

