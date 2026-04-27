import { CommandAgentProvider, type AgentRunInput } from "../AgentProvider.js";

export class CodexProvider extends CommandAgentProvider {
  readonly id = "codex" as const;
  readonly displayName = "OpenAI Codex";

  protected command(input: AgentRunInput): { bin: string; args: string[] } {
    return { bin: "codex", args: ["exec", input.prompt] };
  }
}

