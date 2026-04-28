import SwiftUI

struct WorkspaceStreamingTextView: View {
    let text: String
    let isStreaming: Bool
    var enablesSelection = true

    @State private var displayedText = ""

    var body: some View {
        let effectiveText = isStreaming ? displayedText : text
        let content = WorkspaceMarkdownText(text: effectiveText.isEmpty ? text : effectiveText, isStreaming: isStreaming)

        Group {
            if enablesSelection {
                content.textSelection(.enabled)
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            reconcileDisplayedText(with: text)
        }
        .onChange(of: text) { _, nextText in
            reconcileDisplayedText(with: nextText)
        }
        .onChange(of: isStreaming) { _, streaming in
            if !streaming {
                displayedText = text
            }
        }
    }

    private func reconcileDisplayedText(with nextText: String) {
        guard isStreaming else {
            displayedText = nextText
            return
        }
        guard !nextText.isEmpty else {
            displayedText = ""
            return
        }
        if nextText.hasPrefix(displayedText) {
            displayedText.append(String(nextText.dropFirst(displayedText.count)))
        } else {
            displayedText = nextText
        }
    }
}

struct WorkspaceMarkdownText: View {
    let text: String
    var isStreaming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(WorkspaceMarkdownParser.parse(normalizedText, allowOpenFence: isStreaming)) { block in
                switch block.kind {
                case .paragraph(let value):
                    WorkspaceMarkdownInlineText(value)
                case .heading(let level, let value):
                    WorkspaceMarkdownHeading(level: level, text: value)
                case .list(let items, let ordered):
                    WorkspaceMarkdownList(items: items, ordered: ordered)
                case .code(let language, let code):
                    WorkspaceCodeBlock(language: language, code: code)
                case .quote(let value):
                    WorkspaceMarkdownQuote(text: value)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var normalizedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct WorkspaceMarkdownBlock: Identifiable {
    enum Kind {
        case paragraph(String)
        case heading(level: Int, String)
        case list(items: [String], ordered: Bool)
        case code(language: String?, String)
        case quote(String)
    }

    let id: Int
    let kind: Kind
}

private enum WorkspaceMarkdownParser {
    static func parse(_ text: String, allowOpenFence: Bool) -> [WorkspaceMarkdownBlock] {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [WorkspaceMarkdownBlock] = []
        var paragraph: [String] = []
        var index = 0

        func flushParagraph() {
            let value = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            paragraph.removeAll(keepingCapacity: true)
            guard !value.isEmpty else { return }
            blocks.append(WorkspaceMarkdownBlock(id: blocks.count, kind: .paragraph(value)))
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                flushParagraph()
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                index += 1
                var codeLines: [String] = []
                var closedFence = false
                while index < lines.count {
                    let candidate = lines[index]
                    if candidate.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") {
                        closedFence = true
                        index += 1
                        break
                    }
                    codeLines.append(candidate)
                    index += 1
                }
                if closedFence || allowOpenFence || !codeLines.isEmpty {
                    blocks.append(WorkspaceMarkdownBlock(
                        id: blocks.count,
                        kind: .code(language: language.isEmpty ? nil : language, codeLines.joined(separator: "\n"))
                    ))
                }
                continue
            }

            if let heading = parseHeading(trimmed) {
                flushParagraph()
                blocks.append(WorkspaceMarkdownBlock(id: blocks.count, kind: .heading(level: heading.level, heading.text)))
                index += 1
                continue
            }

            if let listItem = parseListItem(trimmed) {
                flushParagraph()
                var items = [listItem.text]
                let ordered = listItem.ordered
                index += 1
                while index < lines.count, let next = parseListItem(lines[index].trimmingCharacters(in: .whitespacesAndNewlines)), next.ordered == ordered {
                    items.append(next.text)
                    index += 1
                }
                blocks.append(WorkspaceMarkdownBlock(id: blocks.count, kind: .list(items: items, ordered: ordered)))
                continue
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                var quoteLines = [String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)]
                index += 1
                while index < lines.count {
                    let next = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    guard next.hasPrefix(">") else { break }
                    quoteLines.append(String(next.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines))
                    index += 1
                }
                blocks.append(WorkspaceMarkdownBlock(id: blocks.count, kind: .quote(quoteLines.joined(separator: "\n"))))
                continue
            }

            paragraph.append(line)
            index += 1
        }

        flushParagraph()
        return blocks
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...4).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        let text = String(line.dropFirst(hashes + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : (hashes, text)
    }

    private static func parseListItem(_ line: String) -> (ordered: Bool, text: String)? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
            return (false, String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let dot = line.firstIndex(of: ".") else { return nil }
        let prefix = line[..<dot]
        guard !prefix.isEmpty, prefix.allSatisfy(\.isNumber) else { return nil }
        let afterDot = line.index(after: dot)
        guard afterDot < line.endIndex, line[afterDot] == " " else { return nil }
        return (true, String(line[line.index(after: afterDot)...]).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private struct WorkspaceMarkdownHeading: View {
    let level: Int
    let text: String

    var body: some View {
        WorkspaceMarkdownInlineText(text)
            .font(font)
            .padding(.top, level == 1 ? 4 : 2)
    }

    private var font: Font {
        switch level {
        case 1: AppFont.title3(weight: .bold)
        case 2: AppFont.headline(weight: .bold)
        default: AppFont.body(weight: .semibold)
        }
    }
}

private struct WorkspaceMarkdownList: View {
    let items: [String]
    let ordered: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(ordered ? "\(offset + 1)." : "•")
                        .font(AppFont.body(weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: ordered ? 24 : 14, alignment: .trailing)
                    WorkspaceMarkdownInlineText(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct WorkspaceMarkdownQuote: View {
    let text: String

    var body: some View {
        WorkspaceMarkdownInlineText(text)
            .padding(.leading, 12)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.28))
                    .frame(width: 3)
            }
    }
}

private struct WorkspaceMarkdownInlineText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(AppFont.body())
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(text)
                .font(AppFont.body())
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WorkspaceCodeBlock: View {
    let language: String?
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(languageLabel)
                    .font(AppFont.mono(.caption))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button {
                    UIPasteboard.general.string = code
                    HapticFeedback.shared.triggerImpactFeedback(style: .light)
                    withAnimation(.easeInOut(duration: 0.16)) {
                        copied = true
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(1.3))
                        await MainActor.run {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                copied = false
                            }
                        }
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(AppFont.caption(weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemFill).opacity(0.55))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code.trimmingCharacters(in: .newlines))
                    .font(AppFont.mono(.callout))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(.secondarySystemFill).opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.10), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var languageLabel: String {
        guard let language, !language.isEmpty else { return "code" }
        return language.lowercased()
    }
}

struct WorkspaceRunningIndicator: View {
    @State private var cursorOpacity: Double = 1
    @State private var shimmerPhase: CGFloat = -1

    let label: String

    init(label: String = "Pulse Oscilla is thinking...") {
        self.label = label
    }

    var body: some View {
        HStack(spacing: 7) {
            glyph
            Text(label)
                .font(AppFont.caption())
                .foregroundStyle(.secondary)
                .overlay {
                    GeometryReader { geometry in
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.34), location: 0.42),
                                .init(color: .white.opacity(0.34), location: 0.58),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.55)
                        .offset(x: shimmerPhase * geometry.size.width)
                    }
                    .allowsHitTesting(false)
                }
                .mask(Text(label).font(AppFont.caption()))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                cursorOpacity = 0.18
            }
            withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: false)) {
                shimmerPhase = 4
            }
        }
        .accessibilityLabel(label)
    }

    private var glyph: some View {
        HStack(alignment: .bottom, spacing: 1) {
            Text(">")
                .font(AppFont.mono(.caption2))
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.secondary)
                .frame(width: 4, height: 1)
                .padding(.bottom, 2)
                .opacity(cursorOpacity)
                .offset(y: -1)
        }
        .foregroundStyle(.secondary)
        .frame(width: 12, height: 12)
        .padding(5)
        .background(
            Circle()
                .fill(Color.primary.opacity(0.02))
                .overlay(Circle().stroke(Color.primary.opacity(0.06), lineWidth: 1))
        )
    }
}
