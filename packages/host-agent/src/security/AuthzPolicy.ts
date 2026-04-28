import type { Capability } from "@pulse-oscilla/protocol";

const highRiskCapabilities = new Set<Capability>([
  "terminal.create",
  "files.write",
  "git.stage",
  "git.restore",
  "git.commit",
  "git.push",
  "git.pull",
  "agent.run",
  "process.kill"
]);

export class AuthzPolicy {
  canUse(_capability: Capability): boolean {
    return true;
  }

  requiresAudit(capability: Capability): boolean {
    return highRiskCapabilities.has(capability);
  }
}
