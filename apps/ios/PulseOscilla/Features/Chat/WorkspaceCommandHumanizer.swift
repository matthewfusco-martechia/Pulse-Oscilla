import Foundation

enum WorkspaceCommandHumanizer {
    struct Info: Hashable {
        let verb: String
        let target: String
    }

    static func humanize(_ raw: String, isRunning: Bool) -> Info {
        let command = unwrapShell(raw)
        let parts = command.split(separator: " ", maxSplits: 1).map(String.init)
        let tool = parts.first.map { ($0 as NSString).lastPathComponent.lowercased() } ?? command
        let args = parts.count > 1 ? parts[1] : ""

        switch tool {
        case "cat", "nl", "head", "tail", "sed", "less", "more":
            return Info(verb: isRunning ? "Reading" : "Read", target: lastPathComponents(from: args, fallback: "file"))
        case "rg", "grep", "ag", "ack":
            return Info(verb: isRunning ? "Searching" : "Searched", target: searchSummary(from: args))
        case "ls":
            return Info(verb: isRunning ? "Listing" : "Listed", target: lastPathComponents(from: args, fallback: "directory"))
        case "find", "fd":
            return Info(verb: isRunning ? "Finding" : "Found", target: lastPathComponents(from: args, fallback: "files"))
        case "mkdir":
            return Info(verb: isRunning ? "Creating" : "Created", target: lastPathComponents(from: args, fallback: "directory"))
        case "rm":
            return Info(verb: isRunning ? "Removing" : "Removed", target: lastPathComponents(from: args, fallback: "file"))
        case "cp":
            return Info(verb: isRunning ? "Copying" : "Copied", target: lastPathComponents(from: args, fallback: "file"))
        case "mv":
            return Info(verb: isRunning ? "Moving" : "Moved", target: lastPathComponents(from: args, fallback: "file"))
        case "git":
            return gitInfo(args, isRunning: isRunning)
        case "npm":
            return Info(verb: isRunning ? "Running" : "Ran", target: "npm \(args)")
        case "xcodebuild":
            return Info(verb: isRunning ? "Building" : "Built", target: "iOS app")
        default:
            return Info(verb: isRunning ? "Running" : "Ran", target: command)
        }
    }

    private static func unwrapShell(_ raw: String) -> String {
        var result = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = result.lowercased()
        let prefixes = [
            "/usr/bin/bash -lc ", "/usr/bin/bash -c ",
            "/bin/bash -lc ", "/bin/bash -c ",
            "bash -lc ", "bash -c ",
            "/bin/zsh -lc ", "zsh -lc ",
            "/bin/sh -c ", "sh -c "
        ]

        for prefix in prefixes where lowered.hasPrefix(prefix) {
            result = String(result.dropFirst(prefix.count))
            if (result.hasPrefix("\"") && result.hasSuffix("\"")) || (result.hasPrefix("'") && result.hasSuffix("'")) {
                result = String(result.dropFirst().dropLast())
            }
            if let range = result.range(of: "&&") {
                result = String(result[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            break
        }

        if let range = result.range(of: " | ") {
            result = String(result[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        return result
    }

    private static func lastPathComponents(from args: String, fallback: String) -> String {
        for token in args.split(separator: " ").reversed() {
            let value = String(token).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !value.isEmpty, !value.hasPrefix("-") else { continue }
            return compactPath(value)
        }
        return fallback
    }

    private static func compactPath(_ path: String) -> String {
        let components = path.split(separator: "/").map(String.init)
        guard components.count > 2 else { return path }
        return components.suffix(2).joined(separator: "/")
    }

    private static func searchSummary(from args: String) -> String {
        let tokens = args.split(separator: " ").map(String.init).filter { !$0.hasPrefix("-") }
        guard let pattern = tokens.first else { return "for text" }
        if let path = tokens.dropFirst().last {
            return "for \(pattern) in \(compactPath(path))"
        }
        return "for \(pattern)"
    }

    private static func gitInfo(_ args: String, isRunning: Bool) -> Info {
        let action = args.split(separator: " ").first.map(String.init) ?? "command"
        switch action {
        case "status":
            return Info(verb: isRunning ? "Checking" : "Checked", target: "git status")
        case "diff":
            return Info(verb: isRunning ? "Reading" : "Read", target: "git diff")
        case "branch":
            return Info(verb: isRunning ? "Listing" : "Listed", target: "branches")
        case "checkout", "switch":
            return Info(verb: isRunning ? "Switching" : "Switched", target: lastPathComponents(from: args, fallback: "branch"))
        case "commit":
            return Info(verb: isRunning ? "Committing" : "Committed", target: "changes")
        case "push":
            return Info(verb: isRunning ? "Pushing" : "Pushed", target: "branch")
        case "pull":
            return Info(verb: isRunning ? "Pulling" : "Pulled", target: "updates")
        default:
            return Info(verb: isRunning ? "Running" : "Ran", target: "git \(args)")
        }
    }
}
