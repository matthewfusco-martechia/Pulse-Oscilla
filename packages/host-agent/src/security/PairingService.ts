import { randomBytes, randomUUID } from "node:crypto";
import {
  capabilities,
  makeResponse,
  type PairingAcceptedPayload,
  type PairingHelloPayload,
  type QRPairingPayload,
  type WorkspaceDescriptor
} from "@pulse-oscilla/protocol";
import { createHostKeyPair, deriveSessionKey, SecureChannel, type HostKeyPair } from "./KeyManager.js";
import { deviceFingerprint, TrustStore } from "./TrustStore.js";

export interface PairingServiceOptions {
  ttlMs: number;
  workspace: WorkspaceDescriptor;
  requireDeviceApproval?: boolean;
  approveDevice?: (request: DeviceApprovalRequest) => Promise<boolean>;
}

export interface DeviceApprovalRequest {
  deviceName: string;
  deviceIdentityPublicKey: string;
  fingerprint: string;
}

export interface PairingSession {
  id: string;
  nonce: Buffer;
  expiresAt: Date;
  hostKeys: HostKeyPair;
  qrPayload: QRPairingPayload;
  used: boolean;
}

export interface AcceptedPairing {
  sessionId: string;
  channel: SecureChannel;
  acceptedPayload: PairingAcceptedPayload;
}

export class PairingService {
  private readonly sessions = new Map<string, PairingSession>();
  private readonly trustStore: TrustStore;

  constructor(private readonly options: PairingServiceOptions) {
    this.trustStore = TrustStore.forWorkspace(options.workspace.root);
  }

  createPairing(endpoint: string): PairingSession {
    const id = `pair_${randomUUID()}`;
    const nonce = randomBytes(24);
    const hostKeys = createHostKeyPair();
    const expiresAt = new Date(Date.now() + this.options.ttlMs);
    const qrPayload: QRPairingPayload = {
      v: 1,
      endpoint,
      pairingId: id,
      hostPublicKey: hostKeys.publicKeyBase64,
      nonce: nonce.toString("base64"),
      fingerprint: hostKeys.fingerprint,
      workspaceHint: this.options.workspace.name,
      expiresAt: expiresAt.toISOString()
    };

    const session: PairingSession = {
      id,
      nonce,
      expiresAt,
      hostKeys,
      qrPayload,
      used: false
    };

    this.sessions.set(id, session);
    return session;
  }

  async accept(hello: PairingHelloPayload): Promise<AcceptedPairing> {
    const session = this.sessions.get(hello.pairingId);
    if (!session) {
      throw new Error("Unknown pairing session");
    }
    if (session.used) {
      throw new Error("Pairing session already used");
    }
    if (session.expiresAt.getTime() < Date.now()) {
      this.sessions.delete(session.id);
      throw new Error("Pairing session expired");
    }

    session.used = true;
    await this.ensureTrusted(hello);
    const sessionId = `sess_${randomUUID()}`;
    const key = deriveSessionKey({
      privateKey: session.hostKeys.privateKey,
      peerPublicKeyBase64: hello.devicePublicKey,
      salt: session.nonce,
      info: `pulse-oscilla:${session.id}`
    });

    const acceptedPayload: PairingAcceptedPayload = {
      sessionId,
      resumeToken: `resume_${randomUUID()}_${randomBytes(18).toString("base64url")}`,
      hostPublicKey: session.hostKeys.publicKeyBase64,
      capabilities: [...capabilities],
      workspaceId: this.options.workspace.id,
      workspaceRoot: this.options.workspace.root
    };

    return {
      sessionId,
      channel: new SecureChannel(sessionId, key),
      acceptedPayload
    };
  }

  private async ensureTrusted(hello: PairingHelloPayload): Promise<void> {
    if (await this.trustStore.isTrusted(hello.deviceIdentityPublicKey)) {
      return;
    }

    const approvalRequest: DeviceApprovalRequest = {
      deviceName: hello.deviceName,
      deviceIdentityPublicKey: hello.deviceIdentityPublicKey,
      fingerprint: deviceFingerprint(hello.deviceIdentityPublicKey)
    };

    if (this.options.requireDeviceApproval) {
      const approved = await this.options.approveDevice?.(approvalRequest);
      if (!approved) {
        throw new Error("Device pairing rejected by host");
      }
    }

    await this.trustStore.trust(hello);
  }

  makeAcceptedResponse(pairing: AcceptedPairing) {
    return makeResponse(
      {
        requestId: `pair_${pairing.sessionId}`,
        capability: "session.hello"
      },
      pairing.acceptedPayload
    );
  }
}
