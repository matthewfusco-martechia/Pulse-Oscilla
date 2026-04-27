import { appendFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import type { Capability } from "@pulse-oscilla/protocol";

export interface AuditEntry {
  timestamp: string;
  sessionId: string;
  capability: Capability;
  workspaceId?: string;
  summary: string;
}

export class AuditLog {
  constructor(private readonly path = resolve(process.cwd(), ".pulse-oscilla", "audit.log")) {}

  async write(entry: AuditEntry): Promise<void> {
    await mkdir(dirname(this.path), { recursive: true });
    await appendFile(this.path, `${JSON.stringify(entry)}\n`, "utf8");
  }
}

