import {
  createCipheriv,
  createDecipheriv,
  createHash,
  createPublicKey,
  diffieHellman,
  generateKeyPairSync,
  hkdfSync,
  randomBytes,
  type KeyObject
} from "node:crypto";
import type { BridgeEnvelope, EncryptedFrame } from "@pulse-oscilla/protocol";

export interface HostKeyPair {
  privateKey: KeyObject;
  publicKeyDer: Buffer;
  publicKeyBase64: string;
  fingerprint: string;
}

export function createHostKeyPair(): HostKeyPair {
  const pair = generateKeyPairSync("x25519");
  const publicKeyRaw = publicKeyRawBytes(pair.publicKey);
  const publicKeyBase64 = publicKeyRaw.toString("base64");

  return {
    privateKey: pair.privateKey,
    publicKeyDer: publicKeyRaw,
    publicKeyBase64,
    fingerprint: fingerprint(publicKeyRaw)
  };
}

export function deriveSessionKey(input: {
  privateKey: KeyObject;
  peerPublicKeyBase64: string;
  salt: Buffer;
  info: string;
}): Buffer {
  const peerPublicKey = createPublicKey({
    key: {
      kty: "OKP",
      crv: "X25519",
      x: Buffer.from(input.peerPublicKeyBase64, "base64").toString("base64url")
    },
    format: "jwk"
  });
  const sharedSecret = diffieHellman({
    privateKey: input.privateKey,
    publicKey: peerPublicKey
  });

  return Buffer.from(hkdfSync("sha256", sharedSecret, input.salt, input.info, 32));
}

export class SecureChannel {
  private sendSequence = 0;

  constructor(
    private readonly sessionId: string,
    private readonly key: Buffer
  ) {}

  encrypt(envelope: BridgeEnvelope): EncryptedFrame {
    const sequence = ++this.sendSequence;
    const nonce = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", this.key, nonce);
    cipher.setAAD(this.aad(sequence));
    const ciphertext = Buffer.concat([
      cipher.update(Buffer.from(JSON.stringify(envelope), "utf8")),
      cipher.final()
    ]);

    return {
      kind: "secure.message",
      sessionId: this.sessionId,
      sequence,
      nonce: nonce.toString("base64"),
      ciphertext: ciphertext.toString("base64"),
      tag: cipher.getAuthTag().toString("base64")
    };
  }

  decrypt(frame: EncryptedFrame): BridgeEnvelope {
    if (frame.sessionId !== this.sessionId) {
      throw new Error("Encrypted frame session mismatch");
    }

    const decipher = createDecipheriv(
      "aes-256-gcm",
      this.key,
      Buffer.from(frame.nonce, "base64")
    );
    decipher.setAAD(this.aad(frame.sequence));
    decipher.setAuthTag(Buffer.from(frame.tag, "base64"));

    const plaintext = Buffer.concat([
      decipher.update(Buffer.from(frame.ciphertext, "base64")),
      decipher.final()
    ]);

    return JSON.parse(plaintext.toString("utf8")) as BridgeEnvelope;
  }

  private aad(sequence: number): Buffer {
    return Buffer.from(`${this.sessionId}:${sequence}`, "utf8");
  }
}

function fingerprint(publicKeyDer: Buffer | Uint8Array): string {
  const hash = createHash("sha256").update(publicKeyDer).digest("hex").toUpperCase();
  return `${hash.slice(0, 4)}-${hash.slice(4, 8)}-${hash.slice(8, 12)}`;
}

function publicKeyRawBytes(key: KeyObject): Buffer {
  const jwk = key.export({ format: "jwk" });
  if (!jwk.x) {
    throw new Error("X25519 public key export did not include x coordinate");
  }
  return Buffer.from(jwk.x, "base64url");
}
