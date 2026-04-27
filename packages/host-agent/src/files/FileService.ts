import { createHash } from "node:crypto";
import { readdir, readFile, stat, writeFile } from "node:fs/promises";
import { basename, relative } from "node:path";
import type { FileEntry } from "@pulse-oscilla/protocol";
import { WorkspaceManager } from "../workspace/WorkspaceManager.js";

export class FileService {
  constructor(private readonly workspaceManager: WorkspaceManager) {}

  async list(path = "."): Promise<FileEntry[]> {
    const absolutePath = this.workspaceManager.resolveInside(path);
    const names = await readdir(absolutePath);
    const entries = await Promise.all(
      names.map(async (name): Promise<FileEntry> => {
        const entryPath = `${absolutePath}/${name}`;
        const entryStat = await stat(entryPath);
        return {
          name,
          path: relative(this.workspaceManager.workspace.root, entryPath),
          kind: entryStat.isDirectory() ? "directory" : entryStat.isFile() ? "file" : "unknown",
          size: entryStat.size,
          modifiedAt: entryStat.mtime.toISOString()
        };
      })
    );

    return entries.sort((left, right) => {
      if (left.kind !== right.kind) {
        return left.kind === "directory" ? -1 : 1;
      }
      return left.name.localeCompare(right.name);
    });
  }

  async read(path: string): Promise<{ path: string; name: string; content: string; sha256: string }> {
    const absolutePath = this.workspaceManager.resolveInside(path);
    const content = await readFile(absolutePath, "utf8");
    return {
      path,
      name: basename(path),
      content,
      sha256: createHash("sha256").update(content).digest("hex")
    };
  }

  async write(input: { path: string; content: string; expectedSha256?: string }): Promise<{ path: string; sha256: string }> {
    const absolutePath = this.workspaceManager.resolveInside(input.path);
    if (input.expectedSha256) {
      const current = await readFile(absolutePath, "utf8");
      const currentHash = createHash("sha256").update(current).digest("hex");
      if (currentHash !== input.expectedSha256) {
        throw new Error("File changed since it was read");
      }
    }

    await writeFile(absolutePath, input.content, "utf8");
    return {
      path: input.path,
      sha256: createHash("sha256").update(input.content).digest("hex")
    };
  }
}

