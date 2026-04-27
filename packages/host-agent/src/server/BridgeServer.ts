import http from "node:http";
import os from "node:os";
import { WebSocketServer, type RawData, type WebSocket } from "ws";
import {
  makeError,
  makeResponse,
  type AgentRunPayload,
  type BridgeEnvelope,
  type BridgeRequest,
  type EncryptedFrame,
  type PairingHelloPayload,
  type TerminalCreatePayload
} from "@pulse-oscilla/protocol";
import { AgentOrchestrator } from "../agents/AgentOrchestrator.js";
import { AuditLog } from "../audit/AuditLog.js";
import { FileService } from "../files/FileService.js";
import { GitService } from "../git/GitService.js";
import { PortScanner } from "../preview/PortScanner.js";
import { ProcessService } from "../processes/ProcessService.js";
import { AuthzPolicy } from "../security/AuthzPolicy.js";
import { PairingService } from "../security/PairingService.js";
import type { SecureChannel } from "../security/KeyManager.js";
import { PtyManager } from "../terminal/PtyManager.js";
import { WorkspaceManager } from "../workspace/WorkspaceManager.js";

export interface BridgeServerOptions {
  host: string;
  port: number;
  pairingService: PairingService;
  workspaceManager: WorkspaceManager;
}

interface ConnectionState {
  sessionId: string;
  channel: SecureChannel;
}

export class BridgeServer {
  private readonly httpServer = http.createServer();
  private readonly wsServer = new WebSocketServer({ server: this.httpServer });
  private readonly authz = new AuthzPolicy();
  private readonly audit = new AuditLog();
  private readonly files: FileService;
  private readonly git: GitService;
  private readonly pty: PtyManager;
  private readonly agents: AgentOrchestrator;
  private readonly processes = new ProcessService();
  private readonly ports = new PortScanner();

  constructor(private readonly options: BridgeServerOptions) {
    this.files = new FileService(options.workspaceManager);
    this.git = new GitService(options.workspaceManager);
    this.pty = new PtyManager(options.workspaceManager);
    this.agents = new AgentOrchestrator(options.workspaceManager);
  }

  listen(): Promise<string> {
    this.wsServer.on("connection", (socket) => this.handleSocket(socket));

    return new Promise((resolvePromise, reject) => {
      this.httpServer.once("error", reject);
      this.httpServer.listen(this.options.port, this.options.host, () => {
        const address = this.httpServer.address();
        if (!address || typeof address === "string") {
          reject(new Error("Unable to determine bridge server address"));
          return;
        }
        resolvePromise(`ws://${advertisedHost(this.options.host)}:${address.port}`);
      });
    });
  }

  stop(): Promise<void> {
    return new Promise((resolvePromise, reject) => {
      this.wsServer.close((wsError) => {
        if (wsError) {
          reject(wsError);
          return;
        }
        this.httpServer.close((httpError) => {
          if (httpError) {
            reject(httpError);
            return;
          }
          resolvePromise();
        });
      });
    });
  }

  private handleSocket(socket: WebSocket): void {
    let state: ConnectionState | undefined;

    socket.once("message", (data) => {
      try {
        const hello = parsePlainPairingHello(data);
        void this.options.pairingService.accept(hello).then((accepted) => {
          state = {
            sessionId: accepted.sessionId,
            channel: accepted.channel
          };
          socket.send(JSON.stringify(accepted.channel.encrypt(this.options.pairingService.makeAcceptedResponse(accepted))));

          socket.on("message", async (secureData) => {
            if (!state) {
              return;
            }
            await this.handleSecureMessage(socket, state, secureData);
          });
        }).catch((error: unknown) => {
          socket.send(JSON.stringify(makeError({
            code: "PAIRING_FAILED",
            message: error instanceof Error ? error.message : "Pairing failed"
          })));
          socket.close();
        });
      } catch (error) {
        socket.send(JSON.stringify(makeError({
          code: "PAIRING_FAILED",
          message: error instanceof Error ? error.message : "Pairing failed"
        })));
        socket.close();
        return;
      }
    });
  }

  private async handleSecureMessage(socket: WebSocket, state: ConnectionState, data: RawData): Promise<void> {
    const send = (message: BridgeEnvelope | unknown) => {
      socket.send(JSON.stringify(state.channel.encrypt(message as BridgeEnvelope)));
    };

    let request: BridgeRequest;
    try {
      const frame = JSON.parse(data.toString()) as EncryptedFrame;
      const envelope = state.channel.decrypt(frame);
      if (envelope.type !== "request" || !envelope.capability || !envelope.requestId) {
        throw new Error("Expected request envelope");
      }
      request = envelope as BridgeRequest;
    } catch (error) {
      send(makeError({
        code: "BAD_MESSAGE",
        message: error instanceof Error ? error.message : "Unable to decode message"
      }));
      return;
    }

    try {
      if (!this.authz.canUse(request.capability)) {
        throw new Error(`Capability denied: ${request.capability}`);
      }
      if (this.authz.requiresAudit(request.capability)) {
        const entry = {
          timestamp: new Date().toISOString(),
          sessionId: state.sessionId,
          capability: request.capability,
          summary: summarizeRequest(request)
        };
        await this.audit.write(
          request.workspaceId ? { ...entry, workspaceId: request.workspaceId } : entry
        );
      }

      const responsePayload = await this.routeRequest(request, send);
      if (responsePayload !== undefined) {
        send(makeResponse(request, responsePayload));
      }
    } catch (error) {
      send(makeError({
        requestId: request.requestId,
        code: "REQUEST_FAILED",
        message: error instanceof Error ? error.message : "Request failed"
      }));
    }
  }

  private async routeRequest(request: BridgeRequest, send: (message: unknown) => void): Promise<unknown> {
    switch (request.capability) {
      case "workspace.list":
      case "workspace.open":
        return { workspaces: [this.options.workspaceManager.workspace] };
      case "files.list":
        return this.files.list(stringField(request.payload, "path", "."));
      case "files.read":
        return this.files.read(requiredString(request.payload, "path"));
      case "files.write":
        const writeInput: { path: string; content: string; expectedSha256?: string } = {
          path: requiredString(request.payload, "path"),
          content: requiredString(request.payload, "content")
        };
        {
          const expectedSha256 = optionalString(request.payload, "expectedSha256");
          if (expectedSha256) {
            writeInput.expectedSha256 = expectedSha256;
          }
        }
        return this.files.write(writeInput);
      case "git.status":
        return this.git.status();
      case "git.diff":
        return this.git.diff(optionalString(request.payload, "path"));
      case "git.branch":
        return this.git.branch();
      case "git.commit":
        return this.git.commit(requiredString(request.payload, "message"));
      case "git.push":
        return this.git.push();
      case "git.pull":
        return this.git.pull();
      case "process.list":
        return this.processes.list();
      case "process.kill":
        return this.processes.kill(requiredNumber(request.payload, "pid"));
      case "preview.ports":
        return this.ports.list();
      case "terminal.create":
        return this.pty.create(request as BridgeRequest<TerminalCreatePayload>, send);
      case "terminal.stdin":
        this.pty.stdin(requiredStreamId(request), requiredString(request.payload, "data"));
        return { ok: true };
      case "terminal.resize":
        this.pty.resize(requiredStreamId(request), requiredNumber(request.payload, "cols"), requiredNumber(request.payload, "rows"));
        return { ok: true };
      case "terminal.signal":
        this.pty.signal(requiredStreamId(request), requiredString(request.payload, "signal"));
        return { ok: true };
      case "terminal.close":
        this.pty.close(requiredStreamId(request));
        return { ok: true };
      case "agent.run":
        return this.agents.run(request as BridgeRequest<AgentRunPayload>, send);
      case "agent.cancel":
        await this.agents.cancel(requiredProvider(request.payload), requiredStreamId(request));
        return { ok: true };
      case "session.hello":
      case "session.resume":
      case "files.diff":
      case "files.watch":
      case "preview.open":
      case "agent.stdin":
        throw new Error(`Capability not implemented yet: ${request.capability}`);
    }
  }
}

function parsePlainPairingHello(data: RawData): PairingHelloPayload {
  const message = JSON.parse(data.toString()) as { type?: string; payload?: unknown };
  if (message.type !== "pairing.hello") {
    throw new Error("First message must be pairing.hello");
  }
  return {
    pairingId: requiredString(message.payload, "pairingId"),
    deviceName: requiredString(message.payload, "deviceName"),
    devicePublicKey: requiredString(message.payload, "devicePublicKey"),
    deviceIdentityPublicKey: requiredString(message.payload, "deviceIdentityPublicKey")
  };
}

function bestLanAddress(): string {
  for (const addresses of Object.values(os.networkInterfaces())) {
    for (const address of addresses ?? []) {
      if (address.family === "IPv4" && !address.internal) {
        return address.address;
      }
    }
  }
  return "127.0.0.1";
}

function advertisedHost(boundHost: string): string {
  if (boundHost === "0.0.0.0" || boundHost === "::") {
    return bestLanAddress();
  }
  return boundHost;
}

function requiredStreamId(request: BridgeRequest): string {
  if (!request.streamId) {
    throw new Error("streamId is required");
  }
  return request.streamId;
}

function requiredString(payload: unknown, key: string): string {
  const value = record(payload)[key];
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${key} must be a non-empty string`);
  }
  return value;
}

function stringField(payload: unknown, key: string, fallback: string): string {
  const value = record(payload)[key];
  return typeof value === "string" ? value : fallback;
}

function optionalString(payload: unknown, key: string): string | undefined {
  const value = record(payload)[key];
  return typeof value === "string" ? value : undefined;
}

function requiredNumber(payload: unknown, key: string): number {
  const value = record(payload)[key];
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error(`${key} must be a finite number`);
  }
  return value;
}

function requiredProvider(payload: unknown): AgentRunPayload["provider"] {
  const value = requiredString(payload, "provider");
  if (value === "claude-code" || value === "codex" || value === "opencode" || value === "custom") {
    return value;
  }
  throw new Error(`Unknown provider: ${value}`);
}

function record(payload: unknown): Record<string, unknown> {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return {};
  }
  return payload as Record<string, unknown>;
}

function summarizeRequest(request: BridgeRequest): string {
  if (request.capability === "terminal.create") {
    return `terminal.create cwd=${stringField(request.payload, "cwd", ".")}`;
  }
  if (request.capability === "agent.run") {
    return `agent.run provider=${stringField(request.payload, "provider", "unknown")}`;
  }
  return request.capability;
}
