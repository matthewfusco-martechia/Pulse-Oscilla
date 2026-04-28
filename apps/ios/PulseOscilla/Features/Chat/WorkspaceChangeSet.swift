import Foundation

struct WorkspaceChangeSet: Identifiable, Hashable {
    let id = UUID()
    var files: [WorkspaceChangedFile]
    var rawDiff: String

    var totalAdditions: Int {
        files.reduce(0) { $0 + $1.additions }
    }

    var totalDeletions: Int {
        files.reduce(0) { $0 + $1.deletions }
    }

    var isEmpty: Bool {
        files.isEmpty
    }
}

struct WorkspaceChangedFile: Identifiable, Hashable {
    var path: String
    var oldPath: String?
    var additions: Int
    var deletions: Int
    var hunks: [WorkspaceDiffHunk]

    var id: String { path }

    var displayName: String {
        (path as NSString).lastPathComponent
    }
}

struct WorkspaceDiffHunk: Identifiable, Hashable {
    let id = UUID()
    var header: String
    var lines: [WorkspaceDiffLine]
}

struct WorkspaceDiffLine: Identifiable, Hashable {
    enum Kind: Hashable {
        case context
        case addition
        case deletion
        case metadata
    }

    let id = UUID()
    var kind: Kind
    var text: String
}

enum WorkspaceDiffParser {
    static func parse(_ diff: String) -> WorkspaceChangeSet {
        var files: [WorkspaceChangedFile] = []
        var currentFile: WorkspaceChangedFile?
        var currentHunk: WorkspaceDiffHunk?

        func flushHunk() {
            guard let hunk = currentHunk else { return }
            currentFile?.hunks.append(hunk)
            currentHunk = nil
        }

        func flushFile() {
            flushHunk()
            guard let file = currentFile else { return }
            files.append(file)
            currentFile = nil
        }

        for line in diff.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            if line.hasPrefix("diff --git ") {
                flushFile()
                currentFile = WorkspaceChangedFile(
                    path: parsePathFromDiffHeader(line) ?? "Unknown file",
                    oldPath: nil,
                    additions: 0,
                    deletions: 0,
                    hunks: []
                )
                continue
            }

            if line.hasPrefix("rename from ") {
                currentFile?.oldPath = String(line.dropFirst("rename from ".count))
                continue
            }

            if line.hasPrefix("rename to ") {
                currentFile?.path = String(line.dropFirst("rename to ".count))
                continue
            }

            if line.hasPrefix("+++ ") {
                let parsedPath = normalizeDiffPath(String(line.dropFirst(4)))
                if parsedPath != "/dev/null" {
                    currentFile?.path = parsedPath
                }
                appendLine(line, kind: .metadata, to: &currentHunk)
                continue
            }

            if line.hasPrefix("--- ") {
                let parsedPath = normalizeDiffPath(String(line.dropFirst(4)))
                if parsedPath != "/dev/null" {
                    currentFile?.oldPath = parsedPath
                }
                appendLine(line, kind: .metadata, to: &currentHunk)
                continue
            }

            if line.hasPrefix("@@") {
                flushHunk()
                currentHunk = WorkspaceDiffHunk(header: line, lines: [])
                continue
            }

            guard currentFile != nil else { continue }

            if line.hasPrefix("+"), !line.hasPrefix("+++") {
                currentFile?.additions += 1
                appendLine(line, kind: .addition, to: &currentHunk)
            } else if line.hasPrefix("-"), !line.hasPrefix("---") {
                currentFile?.deletions += 1
                appendLine(line, kind: .deletion, to: &currentHunk)
            } else {
                appendLine(line, kind: .context, to: &currentHunk)
            }
        }

        flushFile()
        return WorkspaceChangeSet(files: deduplicated(files), rawDiff: diff)
    }

    private static func deduplicated(_ files: [WorkspaceChangedFile]) -> [WorkspaceChangedFile] {
        var uniqueFiles: [WorkspaceChangedFile] = []
        var indexesByPath: [String: Int] = [:]

        for file in files {
            if let existingIndex = indexesByPath[file.path] {
                // Agent transcripts can repeat the same unified diff. Prefer the most complete
                // copy instead of showing duplicate file chips in review.
                let existing = uniqueFiles[existingIndex]
                if file.hunks.count >= existing.hunks.count {
                    uniqueFiles[existingIndex] = file
                }
            } else {
                indexesByPath[file.path] = uniqueFiles.count
                uniqueFiles.append(file)
            }
        }

        return uniqueFiles
    }

    private static func appendLine(
        _ text: String,
        kind: WorkspaceDiffLine.Kind,
        to hunk: inout WorkspaceDiffHunk?
    ) {
        guard hunk != nil else { return }
        hunk?.lines.append(WorkspaceDiffLine(kind: kind, text: text))
    }

    private static func parsePathFromDiffHeader(_ line: String) -> String? {
        let parts = line.split(separator: " ").map(String.init)
        guard parts.count >= 4 else { return nil }
        return normalizeDiffPath(parts[3])
    }

    private static func normalizeDiffPath(_ value: String) -> String {
        var path = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.hasPrefix("a/") || path.hasPrefix("b/") {
            path.removeFirst(2)
        }
        return path
    }
}
