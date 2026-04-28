import type { AgentEventPayload } from "@pulse-oscilla/protocol";
import { normalizeCodexStderr, normalizeCodexStdout } from "../AgentEventNormalizer.js";
import { CommandAgentProvider, type AgentCommand, type AgentRunInput } from "../AgentProvider.js";

export class CodexProvider extends CommandAgentProvider {
  readonly id = "codex" as const;
  readonly displayName = "OpenAI Codex";
  protected readonly executableName = "codex";

  protected command(input: AgentRunInput): AgentCommand {
    return { bin: this.executableName, args: ["exec", input.prompt], stdin: null };
  }

  protected override classifyStderr(text: string): AgentEventPayload[] {
    return normalizeCodexStderr(text);
  }

  protected override classifyStdout(text: string): AgentEventPayload[] {
    return normalizeCodexStdout(text);
  }
}
