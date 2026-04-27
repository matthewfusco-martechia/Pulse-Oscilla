import { run } from "../git/GitService.js";

export interface PortDescriptor {
  port: number;
  protocol: "http" | "https" | "unknown";
  process?: string;
  url: string;
}

export class PortScanner {
  async list(): Promise<PortDescriptor[]> {
    const result = await run("lsof", ["-nP", "-iTCP", "-sTCP:LISTEN"], process.cwd());
    return result.stdout
      .split("\n")
      .slice(1)
      .map((line) => line.trim())
      .filter(Boolean)
      .map(parseLsofLine)
      .filter((port): port is PortDescriptor => Boolean(port));
  }
}

function parseLsofLine(line: string): PortDescriptor | undefined {
  const columns = line.split(/\s+/);
  const processName = columns[0];
  const nameColumn = columns.find((column) => column.includes(":") && column.includes("LISTEN"));
  if (!nameColumn) {
    return undefined;
  }
  const match = nameColumn.match(/:(\d+).*LISTEN/);
  if (!match?.[1]) {
    return undefined;
  }
  const port = Number(match[1]);
  const protocol = inferProtocol(port);
  const descriptor: PortDescriptor = {
    port,
    protocol,
    url: `${protocol === "https" ? "https" : "http"}://localhost:${port}`
  };
  if (processName) {
    descriptor.process = processName;
  }
  return descriptor;
}

function inferProtocol(port: number): "http" | "https" | "unknown" {
  if ([443, 8443, 9443].includes(port)) {
    return "https";
  }
  if ([3000, 3001, 4200, 5173, 8000, 8080, 9000].includes(port)) {
    return "http";
  }
  return "unknown";
}
