import { run } from "../git/GitService.js";

export class ProcessService {
  async list(): Promise<{ raw: string }> {
    const result = await run("ps", ["-axo", "pid,ppid,command"], process.cwd());
    return { raw: result.stdout };
  }

  async kill(pid: number): Promise<{ pid: number; signal: string }> {
    process.kill(pid, "SIGTERM");
    return { pid, signal: "SIGTERM" };
  }
}

