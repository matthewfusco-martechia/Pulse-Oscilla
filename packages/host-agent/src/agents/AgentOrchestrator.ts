import { makeEvent, type AgentRunPayload, type BridgeRequest } from "@pulse-oscilla/protocol";
import { ClaudeCodeProvider } from "./providers/ClaudeCodeProvider.js";
import { CodexProvider } from "./providers/CodexProvider.js";
import { CustomAgentProvider } from "./providers/CustomAgentProvider.js";
import { OpenCodeProvider } from "./providers/OpenCodeProvider.js";
import type { AgentProvider } from "./AgentProvider.js";
import { WorkspaceManager } from "../workspace/WorkspaceManager.js";

type Send = (message: unknown) => void;

export class AgentOrchestrator {
  private readonly providers: Map<AgentRunPayload["provider"], AgentProvider>;

  constructor(private readonly workspaceManager: WorkspaceManager) {
    const providers = [
      new ClaudeCodeProvider(),
      new CodexProvider(),
      new OpenCodeProvider(),
      new CustomAgentProvider()
    ];
    this.providers = new Map(providers.map((provider) => [provider.id, provider]));
  }

  async run(request: BridgeRequest<AgentRunPayload>, send: Send): Promise<{ streamId: string }> {
    const streamId = request.streamId ?? `agent_${crypto.randomUUID()}`;
    const provider = this.providers.get(request.payload.provider);
    if (!provider) {
      throw new Error(`Unknown agent provider: ${request.payload.provider}`);
    }

    for await (const event of provider.start({
      ...request.payload,
      workspaceRoot: this.workspaceManager.workspace.root,
      streamId
    })) {
      send(makeEvent({ ...request, streamId }, event));
    }

    return { streamId };
  }

  async cancel(providerId: AgentRunPayload["provider"], streamId: string): Promise<void> {
    const provider = this.providers.get(providerId);
    await provider?.cancel(streamId);
  }
}

