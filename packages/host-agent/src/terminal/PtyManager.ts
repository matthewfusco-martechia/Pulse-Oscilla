import os from "node:os";
import pty from "node-pty";
import type { BridgeRequest, TerminalCreatePayload, TerminalOutputPayload } from "@pulse-oscilla/protocol";
import { makeEvent } from "@pulse-oscilla/protocol";
import { WorkspaceManager } from "../workspace/WorkspaceManager.js";

type Send = (message: unknown) => void;

export class PtyManager {
  private readonly sessions = new Map<string, pty.IPty>();

  constructor(private readonly workspaceManager: WorkspaceManager) {}

  create(request: BridgeRequest<TerminalCreatePayload>, send: Send): { streamId: string; pid: number } {
    const streamId = request.streamId ?? `term_${crypto.randomUUID()}`;
    const cwd = this.workspaceManager.resolveInside(request.payload.cwd ?? ".");
    const shell = request.payload.shell ?? process.env.SHELL ?? os.userInfo().shell ?? "/bin/zsh";
    const proc = pty.spawn(shell, [], {
      name: "xterm-256color",
      cwd,
      cols: request.payload.cols,
      rows: request.payload.rows,
      env: process.env
    });

    this.sessions.set(streamId, proc);
    proc.onData((data) => {
      const output: TerminalOutputPayload = { fd: "stdout", data };
      send(makeEvent({ ...request, streamId }, output));
    });
    proc.onExit((event) => {
      this.sessions.delete(streamId);
      send(makeEvent({ ...request, streamId }, { kind: "exit", exitCode: event.exitCode, signal: event.signal }));
    });

    return { streamId, pid: proc.pid };
  }

  stdin(streamId: string, data: string): void {
    const session = this.requireSession(streamId);
    session.write(data);
  }

  resize(streamId: string, cols: number, rows: number): void {
    const session = this.requireSession(streamId);
    session.resize(cols, rows);
  }

  signal(streamId: string, signal: string): void {
    const session = this.requireSession(streamId);
    session.kill(signal);
  }

  close(streamId: string): void {
    const session = this.requireSession(streamId);
    session.kill();
    this.sessions.delete(streamId);
  }

  private requireSession(streamId: string): pty.IPty {
    const session = this.sessions.get(streamId);
    if (!session) {
      throw new Error(`Unknown terminal stream: ${streamId}`);
    }
    return session;
  }
}

