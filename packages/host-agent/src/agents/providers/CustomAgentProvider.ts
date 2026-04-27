import { CommandAgentProvider, type AgentRunInput } from "../AgentProvider.js";

export class CustomAgentProvider extends CommandAgentProvider {
  readonly id = "custom" as const;
  readonly displayName = "Custom Agent";

  protected command(input: AgentRunInput): { bin: string; args: string[] } {
    if (!input.customCommand) {
      throw new Error("customCommand is required for custom agent runs");
    }
    return { bin: process.env.SHELL ?? "/bin/zsh", args: ["-lc", input.customCommand] };
  }
}

