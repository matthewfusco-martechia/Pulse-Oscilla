#!/usr/bin/env node
import process from "node:process";
import qrcode from "qrcode-terminal";
import { startHostAgent } from "@pulse-oscilla/host-agent";

interface CliOptions {
  workspace: string;
  host?: string;
  port?: number;
  pairingTtlMinutes?: number;
  requireDeviceApproval: boolean;
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));
  const startOptions: Parameters<typeof startHostAgent>[0] = {
    workspaceRoot: options.workspace,
    requireDeviceApproval: options.requireDeviceApproval
  };
  if (options.host) {
    startOptions.host = options.host;
  }
  if (options.port !== undefined) {
    startOptions.port = options.port;
  }
  if (options.pairingTtlMinutes !== undefined) {
    startOptions.pairingTtlMs = options.pairingTtlMinutes * 60 * 1000;
  }
  const agent = await startHostAgent(startOptions);

  console.log("");
  console.log("Pulse Oscilla host agent is running.");
  console.log(`Endpoint: ${agent.endpoint}`);
  console.log(`Host fingerprint: ${agent.fingerprint}`);
  console.log("");
  console.log("Scan this QR payload from the iOS app:");
  qrcode.generate(agent.pairingPayload, { small: true });
  console.log("");
  console.log("Raw pairing payload:");
  console.log(agent.pairingPayload);
  console.log("");
  console.log("Press Ctrl-C to stop.");

  const shutdown = async () => {
    await agent.stop();
    process.exit(0);
  };
  process.once("SIGINT", shutdown);
  process.once("SIGTERM", shutdown);
}

function parseArgs(args: string[]): CliOptions {
  const options: CliOptions = {
    workspace: process.cwd(),
    requireDeviceApproval: true
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    const next = args[index + 1];
    if (arg === "--workspace" || arg === "-w") {
      if (!next) {
        throw new Error("--workspace requires a path");
      }
      options.workspace = next;
      index += 1;
      continue;
    }
    if (arg === "--host") {
      if (!next) {
        throw new Error("--host requires a value");
      }
      options.host = next;
      index += 1;
      continue;
    }
    if (arg === "--port" || arg === "-p") {
      if (!next) {
        throw new Error("--port requires a number");
      }
      options.port = parsePositiveInteger(next, "--port");
      index += 1;
      continue;
    }
    if (arg === "--pairing-ttl-minutes" || arg === "--ttl-minutes" || arg === "--ttl") {
      if (!next) {
        throw new Error(`${arg} requires a number of minutes`);
      }
      options.pairingTtlMinutes = parsePositiveInteger(next, arg);
      index += 1;
      continue;
    }
    if (arg === "--trust-on-first-use") {
      options.requireDeviceApproval = false;
      continue;
    }
    if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  return options;
}

function parsePositiveInteger(value: string, name: string): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a positive integer`);
  }
  return parsed;
}

function printHelp(): void {
  console.log(`Pulse Oscilla

Usage:
  pulse-oscilla [--workspace <path>] [--host <host>] [--port <port>] [--pairing-ttl-minutes <minutes>] [--trust-on-first-use]

Options:
  --workspace, -w          Workspace root to expose. Defaults to current directory.
  --host                  Host interface to bind. Defaults to 0.0.0.0.
  --port, -p              Port to bind. Defaults to an ephemeral port.
  --pairing-ttl-minutes   Pairing QR lifetime in minutes. Defaults to host policy.
  --trust-on-first-use    Trust the first device that presents the QR payload without an extra CLI prompt.
`);
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
