import { randomUUID } from "node:crypto";
import { lstat, readFile } from "node:fs/promises";
import { basename, resolve, sep } from "node:path";
import type { WorkspaceDescriptor } from "@pulse-oscilla/protocol";

export class WorkspaceManager {
  private constructor(readonly workspace: WorkspaceDescriptor) {}

  static async create(root: string): Promise<WorkspaceManager> {
    const resolvedRoot = resolve(root);
    const stat = await lstat(resolvedRoot);
    if (!stat.isDirectory()) {
      throw new Error(`Workspace root is not a directory: ${resolvedRoot}`);
    }

    const workspace: WorkspaceDescriptor = {
      id: `ws_${randomUUID()}`,
      name: basename(resolvedRoot),
      root: resolvedRoot
    };
    const gitBranch = await readGitHead(resolvedRoot);
    if (gitBranch) {
      workspace.gitBranch = gitBranch;
    }

    return new WorkspaceManager(workspace);
  }

  resolveInside(relativePath = "."): string {
    const requested = resolve(this.workspace.root, relativePath);
    if (requested !== this.workspace.root && !requested.startsWith(`${this.workspace.root}${sep}`)) {
      throw new Error(`Path escapes workspace root: ${relativePath}`);
    }
    return requested;
  }
}

async function readGitHead(root: string): Promise<string | undefined> {
  try {
    const head = await readFile(resolve(root, ".git", "HEAD"), "utf8");
    const refPrefix = "ref: refs/heads/";
    if (head.startsWith(refPrefix)) {
      return head.slice(refPrefix.length).trim();
    }
    return head.trim().slice(0, 12);
  } catch {
    return undefined;
  }
}
