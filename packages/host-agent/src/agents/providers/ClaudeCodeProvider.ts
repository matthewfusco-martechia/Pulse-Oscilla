import { CommandAgentProvider, type AgentRunInput } from "../AgentProvider.js";

export class ClaudeCodeProvider extends CommandAgentProvider {
  readonly id = "claude-code" as const;
  readonly displayName = "Claude Code";

  protected command(input: AgentRunInput): { bin: string; args: string[] } {
    return { bin: "claude", args: ["--print", input.prompt] };
  }
}

