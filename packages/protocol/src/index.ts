export const PROTOCOL_VERSION = 1 as const;

export const capabilities = [
  "session.hello",
  "session.resume",
  "workspace.list",
  "workspace.open",
  "terminal.create",
  "terminal.stdin",
  "terminal.resize",
  "terminal.signal",
  "terminal.close",
  "files.list",
  "files.read",
  "files.write",
  "files.diff",
  "files.watch",
  "git.status",
  "git.diff",
  "git.stage",
  "git.restore",
  "git.commit",
  "git.push",
  "git.pull",
  "git.branch",
  "agent.providers",
  "agent.run",
  "agent.stdin",
  "agent.cancel",
  "process.list",
  "process.kill",
  "preview.ports",
  "preview.open"
] as const;

export type Capability = (typeof capabilities)[number];
export type EnvelopeType = "request" | "event" | "response" | "error" | "heartbeat";

export interface BridgeEnvelope<TPayload = unknown> {
  version: typeof PROTOCOL_VERSION;
  type: EnvelopeType;
  id: string;
  requestId?: string;
  streamId?: string;
  workspaceId?: string;
  capability?: Capability;
  timestamp: string;
  payload: TPayload;
}

export interface BridgeRequest<TPayload = unknown> extends BridgeEnvelope<TPayload> {
  type: "request";
  requestId: string;
  capability: Capability;
}

export interface BridgeEvent<TPayload = unknown> extends BridgeEnvelope<TPayload> {
  type: "event";
  requestId: string;
}

export interface BridgeResponse<TPayload = unknown> extends BridgeEnvelope<TPayload> {
  type: "response";
  requestId: string;
}

export interface BridgeErrorPayload {
  code: string;
  message: string;
  retryable: boolean;
  details?: unknown;
}

export interface BridgeError extends BridgeEnvelope<BridgeErrorPayload> {
  type: "error";
  requestId?: string;
}

export interface QRPairingPayload {
  v: typeof PROTOCOL_VERSION;
  endpoint: string;
  pairingId: string;
  hostPublicKey: string;
  nonce: string;
  fingerprint: string;
  workspaceHint?: string;
  expiresAt: string;
}

export interface PairingHelloPayload {
  pairingId: string;
  deviceName: string;
  devicePublicKey: string;
  deviceIdentityPublicKey: string;
}

export interface PairingAcceptedPayload {
  sessionId: string;
  resumeToken: string;
  hostPublicKey: string;
  capabilities: Capability[];
  workspaceId: string;
  workspaceRoot: string;
}

export interface EncryptedFrame {
  kind: "secure.message";
  sessionId: string;
  sequence: number;
  nonce: string;
  ciphertext: string;
  tag: string;
}

export interface WorkspaceDescriptor {
  id: string;
  name: string;
  root: string;
  gitBranch?: string;
}

export interface TerminalCreatePayload {
  shell?: string;
  cwd?: string;
  cols: number;
  rows: number;
}

export interface TerminalOutputPayload {
  fd: "stdout" | "stderr";
  data: string;
}

export interface FileEntry {
  name: string;
  path: string;
  kind: "file" | "directory" | "symlink" | "unknown";
  size?: number;
  modifiedAt?: string;
}

export interface AgentRunPayload {
  provider: "claude-code" | "codex" | "opencode" | "custom";
  prompt: string;
  mode: "interactive" | "oneshot";
  allowedTools?: string[];
  requireApprovalForWrites: boolean;
  customCommand?: string;
}

export interface AgentInputPayload {
  provider: AgentRunPayload["provider"];
  data: string;
}

export interface AgentAvailabilityPayload {
  provider: AgentRunPayload["provider"];
  displayName: string;
  available: boolean;
  reason?: string;
  command?: string;
  resolvedPath?: string;
  version?: string;
  details?: unknown;
}

export interface AgentEventPayload {
  kind:
    | "assistant.text"
    | "tool.started"
    | "tool.completed"
    | "shell.output"
    | "file.changed"
    | "diff.available"
    | "approval.requested"
    | "run.completed"
    | "run.failed"
    | "run.cancelled";
  text?: string;
  path?: string;
  data?: unknown;
}

export function nowIso(): string {
  return new Date().toISOString();
}

export function newEnvelopeId(prefix: string): string {
  return `${prefix}_${cryptoRandom()}`;
}

export function makeResponse<TPayload>(
  request: Pick<BridgeRequest, "requestId" | "streamId" | "workspaceId" | "capability">,
  payload: TPayload
): BridgeResponse<TPayload> {
  const envelope: BridgeResponse<TPayload> = {
    version: PROTOCOL_VERSION,
    type: "response",
    id: newEnvelopeId("msg"),
    requestId: request.requestId,
    timestamp: nowIso(),
    payload
  };
  if (request.streamId) {
    envelope.streamId = request.streamId;
  }
  if (request.workspaceId) {
    envelope.workspaceId = request.workspaceId;
  }
  if (request.capability) {
    envelope.capability = request.capability;
  }
  return envelope;
}

export function makeEvent<TPayload>(
  request: Pick<BridgeRequest, "requestId" | "streamId" | "workspaceId" | "capability">,
  payload: TPayload
): BridgeEvent<TPayload> {
  const envelope: BridgeEvent<TPayload> = {
    version: PROTOCOL_VERSION,
    type: "event",
    id: newEnvelopeId("evt"),
    requestId: request.requestId,
    timestamp: nowIso(),
    payload
  };
  if (request.streamId) {
    envelope.streamId = request.streamId;
  }
  if (request.workspaceId) {
    envelope.workspaceId = request.workspaceId;
  }
  if (request.capability) {
    envelope.capability = request.capability;
  }
  return envelope;
}

export function makeError(
  input: {
    requestId?: string;
    code: string;
    message: string;
    retryable?: boolean;
    details?: unknown;
  }
): BridgeError {
  const envelope: BridgeError = {
    version: PROTOCOL_VERSION,
    type: "error",
    id: newEnvelopeId("err"),
    timestamp: nowIso(),
    payload: {
      code: input.code,
      message: input.message,
      retryable: input.retryable ?? false
    }
  };
  if (input.requestId) {
    envelope.requestId = input.requestId;
  }
  if (input.details !== undefined) {
    envelope.payload.details = input.details;
  }
  return envelope;
}

function cryptoRandom(): string {
  const bytes = new Uint8Array(12);
  globalThis.crypto.getRandomValues(bytes);
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}
