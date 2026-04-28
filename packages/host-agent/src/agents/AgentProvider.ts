import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { access } from "node:fs/promises";
import { constants as fsConstants } from "node:fs";
import { delimiter, isAbsolute, join } from "node:path";
import type { AgentEventPayload, AgentRunPayload } from "@pulse-oscilla/protocol";
import { normalizeStderr, normalizeStdout } from "./AgentEventNormalizer.js";

export interface AgentRunInput extends AgentRunPayload {
  workspaceRoot: string;
  streamId: string;
}

export interface AgentProvider {
  id: AgentRunPayload["provider"];
  displayName: string;
  detect(): Promise<AgentAvailability>;
  start(input: AgentRunInput): AsyncIterable<AgentEventPayload>;
  stdin(streamId: string, data: string): Promise<AgentInputResult>;
  cancel(streamId: string): Promise<AgentCancelResult>;
}

export interface AgentAvailability {
  available: boolean;
  reason?: string;
  command?: string;
  resolvedPath?: string;
  version?: string;
  details?: unknown;
}

export interface AgentCancelResult {
  cancelled: boolean;
  reason?: string;
  signal?: NodeJS.Signals;
}

export interface AgentInputResult {
  ok: boolean;
  reason?: string;
}

interface RunningProcess {
  child: ChildProcessWithoutNullStreams;
  cancelRequested: boolean;
}

export abstract class CommandAgentProvider implements AgentProvider {
  private readonly running = new Map<string, RunningProcess>();

  abstract readonly id: AgentRunPayload["provider"];
  abstract readonly displayName: string;
  protected abstract readonly executableName: string;

  protected abstract command(input: AgentRunInput): AgentCommand;

  protected classifyStdout(text: string): AgentEventPayload[] {
    return normalizeStdout(text);
  }

  protected classifyStderr(text: string): AgentEventPayload[] {
    return normalizeStderr(text);
  }

  async detect(): Promise<AgentAvailability> {
    const resolvedPath = await resolveExecutable(this.executableName);
    if (!resolvedPath) {
      return {
        available: false,
        command: this.executableName,
        reason: `${this.displayName} executable not found on PATH`
      };
    }

    const availability: AgentAvailability = {
      available: true,
      command: this.executableName,
      resolvedPath
    };
    const version = await readCommandVersion(resolvedPath);
    if (version) {
      availability.version = version;
    }
    return availability;
  }

  async *start(input: AgentRunInput): AsyncIterable<AgentEventPayload> {
    const command = this.command(input);
    const child = spawn(command.bin, command.args, {
      cwd: input.workspaceRoot,
      env: process.env,
      detached: process.platform !== "win32",
      stdio: ["pipe", "pipe", "pipe"]
    });
    this.running.set(input.streamId, { child, cancelRequested: false });

    yield {
      kind: "tool.started",
      text: `${this.displayName} started: ${command.bin} ${command.args.join(" ")}`
    };

    if (command.stdin === null) {
      if (!command.keepStdinOpen) {
        child.stdin.end();
      }
    } else {
      child.stdin.write(command.stdin ?? input.prompt);
      if (!command.keepStdinOpen) {
        child.stdin.end();
      }
    }

    try {
      yield* streamChild(child, {
        stdout: (text) => this.classifyStdout(text),
        stderr: (text) => this.classifyStderr(text),
        isCancelled: () => this.running.get(input.streamId)?.cancelRequested ?? false
      });
    } finally {
      this.running.delete(input.streamId);
    }
  }

  async cancel(streamId: string): Promise<AgentCancelResult> {
    const running = this.running.get(streamId);
    if (!running) {
      return { cancelled: false, reason: `No running ${this.displayName} stream for ${streamId}` };
    }

    running.cancelRequested = true;
    if (running.child.killed) {
      return { cancelled: true, reason: "Process was already signalled", signal: "SIGTERM" };
    }
    const signalled = signalChildProcess(running.child, "SIGTERM");
    if (signalled) {
      setTimeout(() => {
        if (!running.child.killed && running.child.exitCode === null && running.child.signalCode === null) {
          signalChildProcess(running.child, "SIGKILL");
        }
      }, 2_000).unref();
    }
    return signalled
      ? { cancelled: true, signal: "SIGTERM" }
      : { cancelled: false, reason: `Unable to signal ${this.displayName} process` };
  }

  async stdin(streamId: string, data: string): Promise<AgentInputResult> {
    const running = this.running.get(streamId);
    if (!running) {
      return { ok: false, reason: `No running ${this.displayName} stream for ${streamId}` };
    }
    if (running.child.stdin.destroyed || running.child.stdin.writableEnded) {
      return { ok: false, reason: `${this.displayName} stdin is closed` };
    }

    return await new Promise((resolve) => {
      running.child.stdin.write(data, (error) => {
        resolve(error ? { ok: false, reason: error.message } : { ok: true });
      });
    });
  }
}

function signalChildProcess(child: ChildProcessWithoutNullStreams, signal: NodeJS.Signals): boolean {
  if (process.platform !== "win32" && child.pid !== undefined) {
    try {
      process.kill(-child.pid, signal);
      return true;
    } catch {
      return child.kill(signal);
    }
  }

  return child.kill(signal);
}

export interface AgentCommand {
  bin: string;
  args: string[];
  /**
   * undefined: send the user prompt to stdin.
   * null: close stdin without writing.
   * string: send this exact stdin payload.
   */
  stdin?: string | null;
  keepStdinOpen?: boolean;
}

interface StreamClassifiers {
  stdout(text: string): AgentEventPayload[];
  stderr(text: string): AgentEventPayload[];
  isCancelled(): boolean;
}

async function* streamChild(
  child: ChildProcessWithoutNullStreams,
  classifiers: StreamClassifiers
): AsyncIterable<AgentEventPayload> {
  const queue: AgentEventPayload[] = [];
  let settled = false;
  let wake: (() => void) | undefined;

  const enqueue = (events: AgentEventPayload[]) => {
    queue.push(...events);
    wake?.();
  };

  child.stdout.on("data", (chunk: Buffer) => {
    enqueue(classifiers.stdout(chunk.toString("utf8")));
  });
  child.stderr.on("data", (chunk: Buffer) => {
    enqueue(classifiers.stderr(chunk.toString("utf8")));
  });
  child.on("close", (exitCode, signal) => {
    if (classifiers.isCancelled()) {
      enqueue([{ kind: "run.cancelled", text: "Agent run cancelled", data: { exitCode, signal } }]);
    } else if (exitCode === 0) {
      enqueue([{ kind: "run.completed", data: { exitCode, signal } }]);
    } else {
      enqueue([{
        kind: "run.failed",
        text: exitCode === null ? `Agent process terminated by signal ${signal ?? "unknown"}` : `Agent process exited with code ${exitCode}`,
        data: { exitCode, signal }
      }]);
    }
    settled = true;
    wake?.();
  });
  child.on("error", (error) => {
    enqueue([{ kind: "run.failed", text: error.message, data: { code: (error as NodeJS.ErrnoException).code } }]);
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

export async function resolveExecutable(command: string): Promise<string | undefined> {
  if (!command) {
    return undefined;
  }

  if (isAbsolute(command) || command.includes("/")) {
    return await canExecute(command) ? command : undefined;
  }

  for (const directory of (process.env.PATH ?? "").split(delimiter)) {
    if (!directory) {
      continue;
    }
    const candidate = join(directory, command);
    if (await canExecute(candidate)) {
      return candidate;
    }
  }

  return undefined;
}

async function canExecute(path: string): Promise<boolean> {
  try {
    await access(path, fsConstants.X_OK);
    return true;
  } catch {
    return false;
  }
}

async function readCommandVersion(command: string): Promise<string | undefined> {
  return new Promise((resolve) => {
    const child = spawn(command, ["--version"], {
      env: process.env,
      stdio: ["ignore", "pipe", "pipe"]
    });
    let output = "";
    const timer = setTimeout(() => {
      child.kill("SIGTERM");
      resolve(undefined);
    }, 2_000);
    const collect = (chunk: Buffer) => {
      output += chunk.toString("utf8");
    };
    child.stdout.on("data", collect);
    child.stderr.on("data", collect);
    child.on("error", () => {
      clearTimeout(timer);
      resolve(undefined);
    });
    child.on("close", () => {
      clearTimeout(timer);
      const firstLine = output.trim().split(/\r?\n/)[0];
      resolve(firstLine || undefined);
    });
  });
}
