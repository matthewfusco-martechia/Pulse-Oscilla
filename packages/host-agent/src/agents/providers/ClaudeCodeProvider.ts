import { CommandAgentProvider, type AgentCommand, type AgentRunInput } from "../AgentProvider.js";

export class ClaudeCodeProvider extends CommandAgentProvider {
  readonly id = "claude-code" as const;
  readonly displayName = "Claude Code";
  protected readonly executableName = "claude";

  protected command(input: AgentRunInput): AgentCommand {
    return { bin: this.executableName, args: ["--print", input.prompt], stdin: null };
  }
}
