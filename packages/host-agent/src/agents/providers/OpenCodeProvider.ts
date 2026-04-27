import { CommandAgentProvider, type AgentRunInput } from "../AgentProvider.js";

export class OpenCodeProvider extends CommandAgentProvider {
  readonly id = "opencode" as const;
  readonly displayName = "OpenCode";

  protected command(input: AgentRunInput): { bin: string; args: string[] } {
    return { bin: "opencode", args: ["run", input.prompt] };
  }
}

