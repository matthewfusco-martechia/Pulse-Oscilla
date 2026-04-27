import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";

export interface TrustedDevice {
  deviceIdentityPublicKey: string;
  deviceName: string;
  fingerprint: string;
  trustedAt: string;
}

export class TrustStore {
  constructor(private readonly path: string) {}

  static forWorkspace(root: string): TrustStore {
    return new TrustStore(resolve(root, ".pulse-oscilla", "trusted-devices.json"));
  }

  async isTrusted(deviceIdentityPublicKey: string): Promise<boolean> {
    const devices = await this.list();
    return devices.some((device) => device.deviceIdentityPublicKey === deviceIdentityPublicKey);
  }

  async trust(input: { deviceIdentityPublicKey: string; deviceName: string }): Promise<TrustedDevice> {
    const devices = await this.list();
    const existing = devices.find((device) => device.deviceIdentityPublicKey === input.deviceIdentityPublicKey);
    if (existing) {
      return existing;
    }

    const trustedDevice: TrustedDevice = {
      deviceIdentityPublicKey: input.deviceIdentityPublicKey,
      deviceName: input.deviceName,
      fingerprint: deviceFingerprint(input.deviceIdentityPublicKey),
      trustedAt: new Date().toISOString()
    };

    await mkdir(dirname(this.path), { recursive: true });
    await writeFile(this.path, JSON.stringify([...devices, trustedDevice], null, 2), "utf8");
    return trustedDevice;
  }

  async list(): Promise<TrustedDevice[]> {
    try {
      const raw = await readFile(this.path, "utf8");
      const parsed = JSON.parse(raw) as unknown;
      if (!Array.isArray(parsed)) {
        return [];
      }
      return parsed.filter(isTrustedDevice);
    } catch {
      return [];
    }
  }
}

export function deviceFingerprint(deviceIdentityPublicKey: string): string {
  const hash = createHash("sha256")
    .update(Buffer.from(deviceIdentityPublicKey, "base64"))
    .digest("hex")
    .toUpperCase();
  return `${hash.slice(0, 4)}-${hash.slice(4, 8)}-${hash.slice(8, 12)}`;
}

function isTrustedDevice(value: unknown): value is TrustedDevice {
  if (!value || typeof value !== "object") {
    return false;
  }
  const record = value as Record<string, unknown>;
  return (
    typeof record.deviceIdentityPublicKey === "string" &&
    typeof record.deviceName === "string" &&
    typeof record.fingerprint === "string" &&
    typeof record.trustedAt === "string"
  );
}

