import { CommandAgentProvider, type AgentCommand, type AgentRunInput } from "../AgentProvider.js";

export class OpenCodeProvider extends CommandAgentProvider {
  readonly id = "opencode" as const;
  readonly displayName = "OpenCode";
  protected readonly executableName = "opencode";

  protected command(input: AgentRunInput): AgentCommand {
    return { bin: this.executableName, args: ["run", input.prompt], stdin: null };
  }
}
