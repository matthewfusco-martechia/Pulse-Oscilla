import { resolve } from "node:path";
import { createInterface } from "node:readline/promises";
import { BridgeServer } from "./server/BridgeServer.js";
import { PairingService } from "./security/PairingService.js";
import { WorkspaceManager } from "./workspace/WorkspaceManager.js";

export interface StartHostAgentOptions {
  workspaceRoot: string;
  host?: string;
  port?: number;
  pairingTtlMs?: number;
  requireDeviceApproval?: boolean;
}

export interface RunningHostAgent {
  endpoint: string;
  pairingPayload: string;
  fingerprint: string;
  stop(): Promise<void>;
}

export async function startHostAgent(options: StartHostAgentOptions): Promise<RunningHostAgent> {
  const workspaceRoot = resolve(options.workspaceRoot);
  const workspaceManager = await WorkspaceManager.create(workspaceRoot);
  const pairingService = new PairingService({
    ttlMs: options.pairingTtlMs ?? 5 * 60 * 1000,
    workspace: workspaceManager.workspace,
    requireDeviceApproval: options.requireDeviceApproval ?? false,
    approveDevice: promptForDeviceApproval
  });

  const server = new BridgeServer({
    host: options.host ?? "0.0.0.0",
    port: options.port ?? 0,
    pairingService,
    workspaceManager
  });

  const endpoint = await server.listen();
  const pairing = pairingService.createPairing(endpoint);

  return {
    endpoint,
    pairingPayload: JSON.stringify(pairing.qrPayload),
    fingerprint: pairing.qrPayload.fingerprint,
    stop: () => server.stop()
  };
}

async function promptForDeviceApproval(request: {
  deviceName: string;
  fingerprint: string;
}): Promise<boolean> {
  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    return false;
  }

  console.log("");
  console.log("Pairing request received.");
  console.log(`Device: ${request.deviceName}`);
  console.log(`Device fingerprint: ${request.fingerprint}`);

  const readline = createInterface({
    input: process.stdin,
    output: process.stdout
  });
  try {
    const answer = await readline.question("Trust this device for this workspace? [y/N] ");
    return answer.trim().toLowerCase() === "y" || answer.trim().toLowerCase() === "yes";
  } finally {
    readline.close();
  }
}
