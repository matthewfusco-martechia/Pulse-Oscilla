import SwiftUI

struct WorkspaceEmptyState: View {
    let workspace: WorkspaceDescriptor?
    let sendSuggestion: (String) -> Void

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 14) {
                Image(systemName: "terminal.fill")
                    .font(AppFont.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(.systemBackground))
                    .frame(width: 62, height: 62)
                    .background(
                        LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .shadow(color: .blue.opacity(0.25), radius: 18, x: 0, y: 10)

                VStack(spacing: 6) {
                    Text("Hi! How can I help?")
                        .font(.title3.weight(.bold))
                        .font(AppFont.title3(weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Commands, files, git, previews, and code agents run on your Mac.")
                        .font(AppFont.caption())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }

            VStack(spacing: 10) {
                WorkspaceSuggestionChip(
                    title: "Explain this repo",
                    subtitle: workspace?.root ?? "Plain-English tour",
                    symbol: "folder"
                ) {
                    sendSuggestion("Explain this repository in plain English. Focus on what the app does, the important folders, and what I should try next.")
                }

                WorkspaceSuggestionChip(
                    title: "Review my changes",
                    subtitle: "Find bugs, risks, and missing tests",
                    symbol: "plus.forwardslash.minus"
                ) {
                    sendSuggestion("Review the current git diff. Call out bugs, risky changes, missing tests, and suggest the smallest safe fixes.")
                }

                WorkspaceSuggestionChip(
                    title: "Build and diagnose",
                    subtitle: "Run checks and explain failures",
                    symbol: "hammer"
                ) {
                    sendSuggestion("Build the iOS app and summarize any errors in simple language. If there are failures, propose the fix.")
                }
            }
            .frame(maxWidth: 360)
        }
        .padding(.horizontal, 24)
    }
}

private struct WorkspaceSuggestionChip: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .font(AppFont.caption(weight: .bold))
                    .foregroundStyle(.blue)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .font(AppFont.subheadline(weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(AppFont.caption())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .workspaceGlass(cornerRadius: 18, interactive: true)
        }
        .buttonStyle(.plain)
    }
}
