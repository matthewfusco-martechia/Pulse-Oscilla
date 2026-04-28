import Foundation

enum WorkspaceTimelineReducer {
    static func project(messages: [AgentChatMessage]) -> [AgentChatMessage] {
        let ordered = enforceIntraTurnOrder(in: messages.sorted(by: stableSort))
        let collapsedThinking = collapseThinkingMessages(in: ordered)
        let withoutCommandThinkingEchoes = removeRedundantThinkingCommandActivityMessages(in: collapsedThinking)
        let dedupedUsers = removeDuplicateUserMessages(in: withoutCommandThinkingEchoes)
        let dedupedFileChanges = removeDuplicateFileChangeMessages(in: dedupedUsers)
        let dedupedAssistant = removeDuplicateAssistantMessages(in: dedupedFileChanges)
        let withoutCompletionMarkers = removeSuccessfulCompletionMarkers(in: dedupedAssistant)
        let coalescedAssistantTurns = coalesceAssistantMessagesByTurn(in: withoutCompletionMarkers)
        return normalizeForDisplay(coalescedAssistantTurns)
    }

    static func assistantResponseAnchorMessageId(in messages: [AgentChatMessage], activeTurnId: String?) -> UUID? {
        if let activeTurnId,
           let message = messages.last(where: { $0.role == .assistant && $0.turnId == activeTurnId }) {
            return message.id
        }

        return messages.last(where: { $0.role == .assistant && ($0.isStreaming || $0.status == .streaming) })?.id
    }

    static func timelineDisplayText(for message: AgentChatMessage) -> String {
        let trimmed = sanitizeAssistantTranscriptIfNeeded(message.body, role: message.role)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard message.isStreaming || message.status == .streaming else {
            return trimmed
        }

        let placeholders: Set<String> = [
            "...",
            "Applying file changes...",
            "Updating...",
            "Coordinating agents...",
            "Planning...",
            "Waiting for input...",
            "The Mac has started the selected agent."
        ]
        return placeholders.contains(trimmed) ? "" : trimmed
    }

    private static func sanitizeAssistantTranscriptIfNeeded(_ text: String, role: AgentChatRole) -> String {
        guard role == .assistant else { return text }
        guard text.contains("OpenAI Codex")
            || text.contains("Reading additional input from stdin")
            || text.contains("workdir:")
            || text.contains("session id:")
        else {
            return dedupeAdjacentLines(in: text)
        }

        var output: [String] = []
        var isInsideMetadataFence = false
        var shouldDropNextPromptEcho = false

        for line in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed == "--------" {
                isInsideMetadataFence.toggle()
                continue
            }

            if isInsideMetadataFence || isCodexMetadataLine(trimmed) {
                continue
            }

            if trimmed == "user" {
                shouldDropNextPromptEcho = true
                continue
            }

            if shouldDropNextPromptEcho {
                shouldDropNextPromptEcho = false
                if isLikelyPromptEcho(trimmed) {
                    continue
                }
            }

            output.append(line)
        }

        return dedupeAdjacentLines(in: output.joined(separator: "\n"))
    }

    private static func isCodexMetadataLine(_ line: String) -> Bool {
        line.isEmpty
            || line == "Reading additional input from stdin..."
            || line.hasPrefix("OpenAI Codex ")
            || line.hasPrefix("workdir:")
            || line.hasPrefix("model:")
            || line.hasPrefix("provider:")
            || line.hasPrefix("approval:")
            || line.hasPrefix("sandbox:")
            || line.hasPrefix("reasoning effort:")
            || line.hasPrefix("reasoning summaries:")
            || line.hasPrefix("session id:")
    }

    private static func isLikelyPromptEcho(_ line: String) -> Bool {
        !line.isEmpty && line.count <= 120 && !line.contains(".") && !line.contains("?") && !line.contains("!")
    }

    private static func dedupeAdjacentLines(in text: String) -> String {
        var result: [String] = []
        for line in text.components(separatedBy: .newlines) {
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               result.last?.trimmingCharacters(in: .whitespacesAndNewlines) == line.trimmingCharacters(in: .whitespacesAndNewlines) {
                continue
            }
            result.append(line)
        }
        return result.joined(separator: "\n")
    }

    private static func normalizeForDisplay(_ messages: [AgentChatMessage]) -> [AgentChatMessage] {
        var projected: [AgentChatMessage] = []
        var seenKeys = Set<String>()

        for message in messages {
            var normalized = message
            normalized.body = timelineDisplayText(for: normalized)

            if normalized.body.isEmpty,
               normalized.kind == .chat,
               normalized.role == .assistant,
               !normalized.isStreaming,
               normalized.status != .streaming {
                continue
            }

            if normalized.kind == .thinking,
               normalized.body.isEmpty,
               !normalized.isStreaming {
                continue
            }

            let key = dedupeKey(for: normalized)
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)

            if shouldMergeWithPrevious(normalized, previous: projected.last) {
                projected[projected.count - 1].body = mergedBody(projected.last?.body ?? "", normalized.body)
                projected[projected.count - 1].status = normalized.status
                projected[projected.count - 1].isStreaming = normalized.isStreaming
            } else {
                projected.append(normalized)
            }
        }

        return projected
    }

    private static func dedupeKey(for message: AgentChatMessage) -> String {
        if let itemId = message.itemId, !itemId.isEmpty {
            return itemId
        }
        return [
            message.role.rawValue,
            message.kind.rawValue,
            message.streamId ?? "",
            message.title ?? "",
            message.body
        ].joined(separator: "|")
    }

    private static func shouldMergeWithPrevious(_ message: AgentChatMessage, previous: AgentChatMessage?) -> Bool {
        guard let previous else { return false }
        guard previous.streamId == message.streamId else { return false }
        guard previous.kind == message.kind, previous.role == message.role else { return false }
        return message.kind == .toolActivity || message.kind == .thinking
    }

    private static func mergedBody(_ lhs: String, _ rhs: String) -> String {
        if lhs.isEmpty { return rhs }
        if rhs.isEmpty { return lhs }
        if lhs.contains(rhs) { return lhs }
        return "\(lhs)\n\(rhs)"
    }

    private static func enforceIntraTurnOrder(in messages: [AgentChatMessage]) -> [AgentChatMessage] {
        var indicesByTurn: [String: [Int]] = [:]
        for (index, message) in messages.enumerated() {
            guard let turnId = message.turnId, !turnId.isEmpty else { continue }
            indicesByTurn[turnId, default: []].append(index)
        }

        var result = messages
        for indices in indicesByTurn.values where indices.count > 1 {
            let turnMessages = indices.map { result[$0] }
            let sorted: [AgentChatMessage]
            if hasInterleavedUserFlow(turnMessages) {
                sorted = turnMessages.sorted(by: stableSort)
            } else if hasInterleavedAssistantActivityFlow(turnMessages) {
                let userMessages = turnMessages.filter { $0.role == .user }
                let openingUserId = userMessages.count == 1
                    ? userMessages.min(by: stableSort)?.id
                    : nil

                sorted = turnMessages.sorted { lhs, rhs in
                    let lhsIsOpeningUser = openingUserId != nil && lhs.id == openingUserId
                    let rhsIsOpeningUser = openingUserId != nil && rhs.id == openingUserId
                    if lhsIsOpeningUser != rhsIsOpeningUser { return lhsIsOpeningUser }
                    return stableSort(lhs, rhs)
                }
            } else {
                sorted = turnMessages.sorted { lhs, rhs in
                    let lhsPriority = intraTurnPriority(lhs)
                    let rhsPriority = intraTurnPriority(rhs)
                    if lhsPriority != rhsPriority {
                        return lhsPriority < rhsPriority
                    }
                    return stableSort(lhs, rhs)
                }
            }

            for (offset, originalIndex) in indices.enumerated() {
                result[originalIndex] = sorted[offset]
            }
        }

        return result
    }

    private static func collapseThinkingMessages(in messages: [AgentChatMessage]) -> [AgentChatMessage] {
        var result: [AgentChatMessage] = []
        result.reserveCapacity(messages.count)

        for message in messages {
            guard message.role == .system, message.kind == .thinking else {
                result.append(message)
                continue
            }

            guard let previousIndex = latestReusableThinkingIndex(in: result, for: message) else {
                result.append(message)
                continue
            }

            let incoming = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if !incoming.isEmpty {
                result[previousIndex].body = mergeThinkingText(existing: result[previousIndex].body, incoming: incoming)
            }
            result[previousIndex].status = message.status
            result[previousIndex].isStreaming = message.isStreaming
        }

        return result
    }

    private static func latestReusableThinkingIndex(
        in messages: [AgentChatMessage],
        for incoming: AgentChatMessage
    ) -> Int? {
        for index in messages.indices.reversed() {
            let candidate = messages[index]
            if candidate.role == .assistant || candidate.role == .user {
                break
            }
            guard candidate.role == .system,
                  candidate.kind == .thinking,
                  shouldMergeThinkingRows(previous: candidate, incoming: incoming)
            else {
                continue
            }
            return index
        }

        return nil
    }

    private static func shouldMergeThinkingRows(previous: AgentChatMessage, incoming: AgentChatMessage) -> Bool {
        let previousItemId = normalizedIdentifier(previous.itemId)
        let incomingItemId = normalizedIdentifier(incoming.itemId)
        if let previousItemId, let incomingItemId, previousItemId == incomingItemId {
            return true
        }

        guard hasCompatibleThinkingTurnScope(previous: previous, incoming: incoming) else {
            return false
        }

        if isPlaceholderThinkingRow(previous) {
            return true
        }

        let previousHasStableIdentity = hasStableThinkingIdentity(previous)
        let incomingHasStableIdentity = hasStableThinkingIdentity(incoming)

        if previousHasStableIdentity,
           incomingHasStableIdentity,
           previousItemId != nil,
           incomingItemId != nil {
            return false
        }

        if isPlaceholderThinkingRow(incoming) {
            return !previousHasStableIdentity
        }

        if !previousHasStableIdentity || !incomingHasStableIdentity {
            return thinkingSnapshotsOverlap(previous: previous, incoming: incoming)
        }

        return false
    }

    private static func normalizedIdentifier(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func hasCompatibleThinkingTurnScope(previous: AgentChatMessage, incoming: AgentChatMessage) -> Bool {
        let previousTurnId = normalizedIdentifier(previous.turnId)
        let incomingTurnId = normalizedIdentifier(incoming.turnId)
        guard let previousTurnId, let incomingTurnId else {
            return true
        }
        return previousTurnId == incomingTurnId
    }

    private static func hasStableThinkingIdentity(_ message: AgentChatMessage) -> Bool {
        guard let itemId = normalizedIdentifier(message.itemId) else {
            return false
        }
        return !(itemId.hasPrefix("turn:") && itemId.contains("|kind:\(AgentMessageKind.thinking.rawValue)"))
    }

    private static func isPlaceholderThinkingRow(_ message: AgentChatMessage) -> Bool {
        normalizedThinkingContent(from: message.body).isEmpty
    }

    private static func thinkingSnapshotsOverlap(previous: AgentChatMessage, incoming: AgentChatMessage) -> Bool {
        let previousText = normalizedThinkingContent(from: previous.body)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let incomingText = normalizedThinkingContent(from: incoming.body)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !previousText.isEmpty, !incomingText.isEmpty else {
            return previousText.isEmpty || incomingText.isEmpty
        }

        let previousLower = previousText.lowercased()
        let incomingLower = incomingText.lowercased()
        return previousLower == incomingLower
            || previousLower.contains(incomingLower)
            || incomingLower.contains(previousLower)
    }

    private static func normalizedThinkingContent(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let placeholders: Set<String> = ["thinking...", "thinking", "...", "planning...", "working..."]
        return placeholders.contains(trimmed.lowercased()) ? "" : trimmed
    }

    private static func mergeThinkingText(existing: String, incoming: String) -> String {
        let existingTrimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let incomingTrimmed = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !incomingTrimmed.isEmpty else { return existingTrimmed }
        guard !existingTrimmed.isEmpty else { return incomingTrimmed }

        let existingLower = existingTrimmed.lowercased()
        let incomingLower = incomingTrimmed.lowercased()
        let placeholderValues: Set<String> = ["thinking...", "thinking", "..."]

        if placeholderValues.contains(incomingLower) { return existingTrimmed }
        if placeholderValues.contains(existingLower) { return incomingTrimmed }
        if incomingLower == existingLower { return incomingTrimmed }
        if incomingTrimmed.contains(existingTrimmed) { return incomingTrimmed }
        if existingTrimmed.contains(incomingTrimmed) { return existingTrimmed }

        return "\(existingTrimmed)\n\(incomingTrimmed)"
    }

    private static func removeRedundantThinkingCommandActivityMessages(in messages: [AgentChatMessage]) -> [AgentChatMessage] {
        let commandKeysByTurn = messages.reduce(into: [String: Set<String>]()) { partialResult, message in
            guard message.role == .system,
                  message.kind == .commandExecution,
                  let turnId = normalizedIdentifier(message.turnId),
                  let commandKey = commandActivityKey(from: message.body) else {
                return
            }
            partialResult[turnId, default: Set<String>()].insert(commandKey)
        }

        guard !commandKeysByTurn.isEmpty else {
            return messages
        }

        return messages.filter { message in
            guard message.role == .system,
                  message.kind == .thinking,
                  let turnId = normalizedIdentifier(message.turnId),
                  let commandKeys = commandKeysByTurn[turnId] else {
                return true
            }

            let lines = normalizedThinkingContent(from: message.body)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !lines.isEmpty else {
                return true
            }

            return !lines.allSatisfy { line in
                guard let commandKey = commandActivityKey(from: line) else {
                    return false
                }
                return commandKeys.contains(commandKey)
            }
        }
    }

    private static func commandActivityKey(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parsed = trimmed.components(separatedBy: .newlines)
        let firstLine = parsed.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
        let candidate: String
        if firstLine == "exec", parsed.count > 1 {
            candidate = parsed[1]
        } else if let range = firstLine.range(of: " started: ") {
            candidate = String(firstLine[range.upperBound...])
        } else {
            let tokens = firstLine.split(whereSeparator: \.isWhitespace).map(String.init)
            guard tokens.count >= 2 else { return nil }
            let status = tokens[0].lowercased()
            guard status == "running"
                || status == "completed"
                || status == "failed"
                || status == "stopped" else {
                return nil
            }
            candidate = tokens.dropFirst().joined(separator: " ")
        }

        let normalized = candidate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? nil : normalized
    }

    private static func removeDuplicateUserMessages(in messages: [AgentChatMessage]) -> [AgentChatMessage] {
        removeDuplicates(in: messages) { message in
            guard message.role == .user else { return nil }
            return [
                "user",
                message.turnId ?? message.streamId ?? "",
                message.body.trimmingCharacters(in: .whitespacesAndNewlines)
            ].joined(separator: "|")
        }
    }

    private static func removeDuplicateFileChangeMessages(in messages: [AgentChatMessage]) -> [AgentChatMessage] {
        removeDuplicates(in: messages) { message in
            guard message.kind == .fileChange else { return nil }
            return [
                "file",
                message.turnId ?? message.streamId ?? "",
                message.itemId ?? "",
                message.title ?? "",
                message.body.trimmingCharacters(in: .whitespacesAndNewlines)
            ].joined(separator: "|")
        }
    }

    private static func removeDuplicateAssistantMessages(in messages: [AgentChatMessage]) -> [AgentChatMessage] {
        removeDuplicates(in: messages) { message in
            guard message.role == .assistant, !message.isStreaming else { return nil }
            let body = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return nil }
            return [
                "assistant",
                message.turnId ?? message.streamId ?? "",
                body
            ].joined(separator: "|")
        }
    }

    private static func removeSuccessfulCompletionMarkers(in messages: [AgentChatMessage]) -> [AgentChatMessage] {
        messages.filter { message in
            !(message.role == .system
                && message.kind == .toolActivity
                && message.status == .completed
                && message.title == "Agent finished")
        }
    }

    private static func coalesceAssistantMessagesByTurn(in messages: [AgentChatMessage]) -> [AgentChatMessage] {
        let groupedAssistantIndices = Dictionary(grouping: messages.indices.filter { index in
            messages[index].role == .assistant
                && messages[index].kind == .chat
                && normalizedIdentifier(messages[index].turnId ?? messages[index].streamId) != nil
        }) { index in
            normalizedIdentifier(messages[index].turnId ?? messages[index].streamId) ?? ""
        }

        let mergeGroups = groupedAssistantIndices.values.filter { $0.count > 1 }
        guard !mergeGroups.isEmpty else { return messages }

        var mergedByInsertionIndex: [Int: AgentChatMessage] = [:]
        var removedIndices = Set<Int>()

        for indices in mergeGroups {
            let sortedIndices = indices.sorted {
                stableSort(messages[$0], messages[$1])
            }
            guard let insertionIndex = sortedIndices.last else { continue }

            var merged = messages[insertionIndex]
            merged.body = sortedIndices
                .map { timelineDisplayText(for: messages[$0]).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .reduce(into: "") { partialResult, text in
                    partialResult = mergedBody(partialResult, text)
                }
            merged.isStreaming = sortedIndices.contains { messages[$0].isStreaming }
            merged.status = merged.isStreaming ? .streaming : messages[insertionIndex].status

            mergedByInsertionIndex[insertionIndex] = merged
            removedIndices.formUnion(sortedIndices.dropLast())
        }

        var result: [AgentChatMessage] = []
        result.reserveCapacity(messages.count - removedIndices.count)

        for index in messages.indices {
            if removedIndices.contains(index) {
                continue
            }

            if let merged = mergedByInsertionIndex[index] {
                result.append(merged)
            } else {
                result.append(messages[index])
            }
        }

        return result
    }

    private static func removeDuplicates(
        in messages: [AgentChatMessage],
        key: (AgentChatMessage) -> String?
    ) -> [AgentChatMessage] {
        var seen = Set<String>()
        var result: [AgentChatMessage] = []
        result.reserveCapacity(messages.count)

        for message in messages {
            guard let value = key(message), !value.isEmpty else {
                result.append(message)
                continue
            }
            guard !seen.contains(value) else { continue }
            seen.insert(value)
            result.append(message)
        }

        return result
    }

    private static func hasInterleavedUserFlow(_ messages: [AgentChatMessage]) -> Bool {
        let ordered = messages.sorted(by: stableSort)
        var seenNonUser = false

        for message in ordered {
            if message.role == .user {
                if seenNonUser {
                    return true
                }
            } else {
                seenNonUser = true
            }
        }

        return false
    }

    private static func hasInterleavedAssistantActivityFlow(_ messages: [AgentChatMessage]) -> Bool {
        let assistantItemIds = Set(
            messages
                .filter { $0.role == .assistant }
                .compactMap { normalizedIdentifier($0.itemId) }
        )
        if assistantItemIds.count > 1 {
            return true
        }

        let ordered = messages.sorted(by: stableSort)
        var hasActivityBeforeAssistant = false
        var seenAssistant = false

        for message in ordered {
            if message.role == .assistant {
                seenAssistant = true
            } else if isInterleavableSystemActivity(message) {
                if !seenAssistant {
                    hasActivityBeforeAssistant = true
                } else if hasActivityBeforeAssistant {
                    return true
                }
            }
        }

        return false
    }

    private static func isInterleavableSystemActivity(_ message: AgentChatMessage) -> Bool {
        guard message.role == .system else { return false }
        switch message.kind {
        case .thinking, .toolActivity, .commandExecution:
            return true
        case .chat, .fileChange, .userInputPrompt:
            return false
        }
    }

    private static func intraTurnPriority(_ message: AgentChatMessage) -> Int {
        switch message.role {
        case .user:
            return 0
        case .system:
            switch message.kind {
            case .thinking:
                return 1
            case .toolActivity:
                return 2
            case .commandExecution:
                return 3
            case .chat:
                return 4
            case .fileChange:
                return 5
            case .userInputPrompt:
                return 6
            }
        case .assistant:
            return 4
        }
    }

    private static func stableSort(_ lhs: AgentChatMessage, _ rhs: AgentChatMessage) -> Bool {
        if lhs.orderIndex != rhs.orderIndex {
            return lhs.orderIndex < rhs.orderIndex
        }
        return lhs.createdAt < rhs.createdAt
    }
}
