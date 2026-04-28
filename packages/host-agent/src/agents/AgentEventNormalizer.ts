import type { AgentEventPayload } from "@pulse-oscilla/protocol";

export function normalizeStdout(text: string): AgentEventPayload[] {
  return text.length > 0 ? [{ kind: "assistant.text", text }] : [];
}

export function normalizeStderr(text: string): AgentEventPayload[] {
  return text.length > 0 ? [{ kind: "shell.output", text, data: { fd: "stderr" } }] : [];
}

export function normalizeCodexStderr(text: string): AgentEventPayload[] {
  const trimmed = text.trim();
  if (!trimmed) {
    return [];
  }

  const lines = text.split(/\r?\n/);
  const firstLine = lines[0]?.trim() ?? "";
  const rest = lines.slice(1).join("\n").trim();

  if (firstLine === "codex") {
    return rest ? [{ kind: "assistant.text", text: `${rest}\n` }] : [];
  }

  if (firstLine === "exec") {
    return [{ kind: "tool.started", text: rest || "Codex executed a command" }];
  }

  if (firstLine.startsWith("succeeded")) {
    return [{ kind: "tool.completed", text: trimmed }];
  }

  if (firstLine.startsWith("failed")) {
    return [{ kind: "run.failed", text: trimmed, data: { source: "codex" } }];
  }

  if (firstLine === "tokens used") {
    return [{ kind: "tool.completed", text: trimmed, data: { category: "usage" } }];
  }

  if (/^\d{4}-\d{2}-\d{2}T.*\b(ERROR|WARN)\b/.test(firstLine)) {
    if (isBenignCodexRuntimeDiagnostic(trimmed)) {
      return [];
    }
    return [{ kind: "shell.output", text, data: { fd: "stderr" } }];
  }

  return [{ kind: "assistant.text", text }];
}

export function normalizeCodexStdout(text: string): AgentEventPayload[] {
  const cleaned = cleanCodexHumanOutput(text);
  return cleaned.length > 0 ? [{ kind: "assistant.text", text: cleaned }] : [];
}

function cleanCodexHumanOutput(text: string): string {
  const normalized = text.replace(/\r\n/g, "\n");
  const lines = normalized.split("\n");
  const output: string[] = [];
  let skippingMetadataBlock = false;
  let hasSeenUserMarker = false;

  for (const line of lines) {
    const trimmed = line.trim();

    if (!trimmed) {
      if (output.length > 0 && output.at(-1) !== "") {
        output.push("");
      }
      continue;
    }

    if (trimmed === "--------") {
      skippingMetadataBlock = !skippingMetadataBlock;
      continue;
    }

    if (skippingMetadataBlock) {
      continue;
    }

    if (trimmed === "user") {
      hasSeenUserMarker = true;
      output.length = 0;
      continue;
    }

    if (!hasSeenUserMarker && isCodexBannerLine(trimmed)) {
      continue;
    }

    if (hasSeenUserMarker && output.length === 0 && isLikelyEchoedShortPrompt(trimmed)) {
      continue;
    }

    output.push(line);
  }

  return dedupeRepeatedFinalLines(output)
    .join("\n")
    .trim()
    .concat(output.length > 0 ? "\n" : "");
}

function isCodexBannerLine(line: string): boolean {
  return line === "Reading additional input from stdin..."
    || line.startsWith("OpenAI Codex ")
    || line.startsWith("workdir: ")
    || line.startsWith("model: ")
    || line.startsWith("provider: ")
    || line.startsWith("approval: ")
    || line.startsWith("sandbox: ")
    || line.startsWith("reasoning effort: ")
    || line.startsWith("reasoning summaries: ")
    || line.startsWith("session id: ");
}

function isLikelyEchoedShortPrompt(line: string): boolean {
  return line.length <= 80 && !/[.!?]$/.test(line);
}

function dedupeRepeatedFinalLines(lines: string[]): string[] {
  const result: string[] = [];
  for (const line of lines) {
    if (line.trim() && result.at(-1)?.trim() === line.trim()) {
      continue;
    }
    result.push(line);
  }
  return result;
}

function isBenignCodexRuntimeDiagnostic(text: string): boolean {
  const lower = text.toLowerCase();
  return lower.includes("failed to record rollout items")
    || lower.includes("no rollout found")
    || lower.includes("thread")
    && lower.includes("not found");
}
