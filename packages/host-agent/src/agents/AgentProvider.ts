import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import type { AgentEventPayload, AgentRunPayload } from "@pulse-oscilla/protocol";

export interface AgentRunInput extends AgentRunPayload {
  workspaceRoot: string;
  streamId: string;
}

export interface AgentProvider {
  id: AgentRunPayload["provider"];
  displayName: string;
  detect(): Promise<AgentAvailability>;
  start(input: AgentRunInput): AsyncIterable<AgentEventPayload>;
  cancel(streamId: string): Promise<void>;
}

export interface AgentAvailability {
  available: boolean;
  reason?: string;
}

export abstract class CommandAgentProvider implements AgentProvider {
  private readonly running = new Map<string, ChildProcessWithoutNullStreams>();

  abstract readonly id: AgentRunPayload["provider"];
  abstract readonly displayName: string;

  protected abstract command(input: AgentRunInput): { bin: string; args: string[] };

  async detect(): Promise<AgentAvailability> {
    return { available: true };
  }

  async *start(input: AgentRunInput): AsyncIterable<AgentEventPayload> {
    const command = this.command(input);
    const child = spawn(command.bin, command.args, {
      cwd: input.workspaceRoot,
      env: process.env,
      stdio: ["pipe", "pipe", "pipe"]
    });
    this.running.set(input.streamId, child);

    yield {
      kind: "tool.started",
      text: `${this.displayName} started: ${command.bin} ${command.args.join(" ")}`
    };

    child.stdin.write(input.prompt);
    child.stdin.end();

    yield* streamChild(child);
    this.running.delete(input.streamId);
  }

  async cancel(streamId: string): Promise<void> {
    const child = this.running.get(streamId);
    if (child) {
      child.kill("SIGTERM");
      this.running.delete(streamId);
    }
  }
}

async function* streamChild(child: ChildProcessWithoutNullStreams): AsyncIterable<AgentEventPayload> {
  const queue: AgentEventPayload[] = [];
  let settled = false;
  let wake: (() => void) | undefined;

  const enqueue = (event: AgentEventPayload) => {
    queue.push(event);
    wake?.();
  };

  child.stdout.on("data", (chunk: Buffer) => {
    enqueue({ kind: "assistant.text", text: chunk.toString("utf8") });
  });
  child.stderr.on("data", (chunk: Buffer) => {
    enqueue({ kind: "shell.output", text: chunk.toString("utf8"), data: { fd: "stderr" } });
  });
  child.on("close", (exitCode) => {
    enqueue({ kind: "run.completed", data: { exitCode } });
    settled = true;
    wake?.();
  });
  child.on("error", (error) => {
    enqueue({ kind: "shell.output", text: error.message, data: { fd: "stderr" } });
    settled = true;
    wake?.();
  });

  while (!settled || queue.length > 0) {
    const event = queue.shift();
    if (event) {
      yield event;
      continue;
    }
    await new Promise<void>((resolve) => {
      wake = resolve;
    });
    wake = undefined;
  }
}

