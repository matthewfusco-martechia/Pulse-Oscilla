import { spawn } from "node:child_process";
import { WorkspaceManager } from "../workspace/WorkspaceManager.js";

export class GitService {
  constructor(private readonly workspaceManager: WorkspaceManager) {}

  status(): Promise<CommandResult> {
    return this.git(["status", "--short", "--branch"]);
  }

  diff(path?: string): Promise<CommandResult> {
    return this.git(path ? ["diff", "--", path] : ["diff"]);
  }

  stage(path?: string): Promise<CommandResult> {
    return this.git(path ? ["add", "--", path] : ["add", "--all"]);
  }

  restore(path?: string): Promise<CommandResult> {
    return this.git(path ? ["restore", "--source=HEAD", "--staged", "--worktree", "--", path] : ["restore", "--source=HEAD", "--staged", "--worktree", "."]);
  }

  branch(): Promise<CommandResult> {
    return this.git(["branch", "--list", "--all", "--verbose", "--no-abbrev"]);
  }

  commit(message: string): Promise<CommandResult> {
    return this.git(["commit", "-m", message]);
  }

  push(): Promise<CommandResult> {
    return this.git(["push"]);
  }

  pull(): Promise<CommandResult> {
    return this.git(["pull", "--ff-only"]);
  }

  private git(args: string[]): Promise<CommandResult> {
    return run("git", args, this.workspaceManager.workspace.root);
  }
}

export interface CommandResult {
  exitCode: number | null;
  stdout: string;
  stderr: string;
}

export function run(command: string, args: string[], cwd: string): Promise<CommandResult> {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(command, args, {
      cwd,
      env: process.env,
      stdio: ["ignore", "pipe", "pipe"]
    });
    const stdout: Buffer[] = [];
    const stderr: Buffer[] = [];

    child.stdout.on("data", (chunk: Buffer) => stdout.push(chunk));
    child.stderr.on("data", (chunk: Buffer) => stderr.push(chunk));
    child.on("error", reject);
    child.on("close", (exitCode) => {
      resolvePromise({
        exitCode,
        stdout: Buffer.concat(stdout).toString("utf8"),
        stderr: Buffer.concat(stderr).toString("utf8")
      });
    });
  });
}
