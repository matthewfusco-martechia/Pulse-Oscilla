import {
  makeEvent,
  type AgentAvailabilityPayload,
  type AgentRunPayload,
  type BridgeRequest
} from "@pulse-oscilla/protocol";
import { ClaudeCodeProvider } from "./providers/ClaudeCodeProvider.js";
import { CodexProvider } from "./providers/CodexProvider.js";
import { CustomAgentProvider } from "./providers/CustomAgentProvider.js";
import { OpenCodeProvider } from "./providers/OpenCodeProvider.js";
import type { AgentCancelResult, AgentProvider } from "./AgentProvider.js";
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

  async listProviders(): Promise<{ providers: AgentAvailabilityPayload[] }> {
    const providers = await Promise.all(
      Array.from(this.providers.values(), async (provider): Promise<AgentAvailabilityPayload> => {
        try {
          return {
            provider: provider.id,
            displayName: provider.displayName,
            ...(await provider.detect())
          };
        } catch (error) {
          return {
            provider: provider.id,
            displayName: provider.displayName,
            available: false,
            reason: error instanceof Error ? error.message : "Unable to detect agent availability"
          };
        }
      })
    );
    return { providers };
  }

  async run(request: BridgeRequest<AgentRunPayload>, send: Send): Promise<{ streamId: string }> {
    const streamId = request.streamId ?? `agent_${crypto.randomUUID()}`;
    const provider = this.providers.get(request.payload.provider);
    if (!provider) {
      throw new AgentBridgeError(
        "AGENT_PROVIDER_UNKNOWN",
        `Unknown agent provider: ${request.payload.provider}`,
        { provider: request.payload.provider }
      );
    }

    const availability = await provider.detect();
    if (!availability.available) {
      throw new AgentBridgeError(
        "AGENT_UNAVAILABLE",
        availability.reason ?? `${provider.displayName} is not available`,
        {
          provider: provider.id,
          displayName: provider.displayName,
          command: availability.command,
          resolvedPath: availability.resolvedPath
        }
      );
    }

    try {
      for await (const event of provider.start({
        ...request.payload,
        workspaceRoot: this.workspaceManager.workspace.root,
        streamId
      })) {
        send(makeEvent({ ...request, streamId }, event));
      }
    } catch (error) {
      send(makeEvent({ ...request, streamId }, {
        kind: "run.failed",
        text: error instanceof Error ? error.message : "Agent run failed",
        data: { provider: provider.id }
      }));
      throw error;
    }

    return { streamId };
  }

  async cancel(providerId: AgentRunPayload["provider"], streamId: string): Promise<AgentCancelResult> {
    const provider = this.providers.get(providerId);
    if (!provider) {
      throw new AgentBridgeError(
        "AGENT_PROVIDER_UNKNOWN",
        `Unknown agent provider: ${providerId}`,
        { provider: providerId, streamId }
      );
    }

    const result = await provider.cancel(streamId);
    if (!result.cancelled) {
      throw new AgentBridgeError(
        "AGENT_CANCEL_FAILED",
        result.reason ?? `Unable to cancel ${provider.displayName} stream ${streamId}`,
        { provider: providerId, streamId }
      );
    }
    return result;
  }

  async stdin(providerId: AgentRunPayload["provider"], streamId: string, data: string): Promise<{ ok: true }> {
    const provider = this.providers.get(providerId);
    if (!provider) {
      throw new AgentBridgeError(
        "AGENT_PROVIDER_UNKNOWN",
        `Unknown agent provider: ${providerId}`,
        { provider: providerId, streamId }
      );
    }

    const result = await provider.stdin(streamId, data);
    if (!result.ok) {
      throw new AgentBridgeError(
        "AGENT_STDIN_FAILED",
        result.reason ?? `Unable to write to ${provider.displayName} stream ${streamId}`,
        { provider: providerId, streamId }
      );
    }

    return { ok: true };
  }
}

export class AgentBridgeError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly details?: unknown
  ) {
    super(message);
    this.name = "AgentBridgeError";
  }
}
