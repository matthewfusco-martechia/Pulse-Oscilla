import { CommandAgentProvider, type AgentCommand, type AgentRunInput } from "../AgentProvider.js";

export class CustomAgentProvider extends CommandAgentProvider {
  readonly id = "custom" as const;
  readonly displayName = "Custom Agent";
  protected readonly executableName = process.env.SHELL ?? "/bin/zsh";

  protected command(input: AgentRunInput): AgentCommand {
    if (!input.customCommand) {
      throw new Error("customCommand is required for custom agent runs");
    }
    return { bin: this.executableName, args: ["-lc", input.customCommand], stdin: input.prompt };
  }
}
