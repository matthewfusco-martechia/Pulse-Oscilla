import assert from "node:assert/strict";
import test from "node:test";
import type { AgentEventPayload } from "@pulse-oscilla/protocol";
import { normalizeCodexStderr, normalizeCodexStdout } from "../src/agents/AgentEventNormalizer.js";
import {
  CommandAgentProvider,
  resolveExecutable,
  type AgentCommand,
  type AgentRunInput
} from "../src/agents/AgentProvider.js";

test("resolveExecutable finds absolute executable paths and misses unknown commands", async () => {
  assert.equal(await resolveExecutable(process.execPath), process.execPath);
  assert.equal(await resolveExecutable("__pulse_oscilla_missing_agent__"), undefined);
});

test("normalizeCodexStderr converts Codex progress blocks into bridge events", () => {
  assert.deepEqual(normalizeCodexStderr("codex\nhello from codex\n"), [
    { kind: "assistant.text", text: "hello from codex\n" }
  ]);
  assert.deepEqual(normalizeCodexStderr("exec\nnpm test\n"), [
    { kind: "tool.started", text: "npm test" }
  ]);
  assert.deepEqual(normalizeCodexStderr("failed\nexit code 1\n"), [
    { kind: "run.failed", text: "failed\nexit code 1", data: { source: "codex" } }
  ]);
});

test("normalizeCodexStdout removes Codex banner and prompt echo", () => {
  const text = `Reading additional input from stdin...
OpenAI Codex v0.125.0 (research preview)
--------
workdir: /tmp/repo
model: gpt-5.5
provider: openai
approval: never
sandbox: workspace-write
reasoning effort: low
session id: abc
--------
user
hey
Hey. What do you want to work on?
Hey. What do you want to work on?
`;

  assert.deepEqual(normalizeCodexStdout(text), [
    { kind: "assistant.text", text: "Hey. What do you want to work on?\n" }
  ]);
});

test("normalizeCodexStderr hides benign rollout persistence errors", () => {
  assert.deepEqual(
    normalizeCodexStderr("2026-04-28T13:32:48.716046Z ERROR codex_core::session: failed to record rollout items: thread abc not found\n"),
    []
  );
});

test("CommandAgentProvider emits run.failed for nonzero exits", async () => {
  const provider = new NodeScriptProvider("process.exit(7);");

  const events = await collect(provider.start(inputFor("failed-stream")));

  assert.equal(events.at(-1)?.kind, "run.failed");
  assert.deepEqual(events.at(-1)?.data, { exitCode: 7, signal: null });
});

test("CommandAgentProvider reports explicit cancellation", async () => {
  const provider = new NodeScriptProvider("setTimeout(() => undefined, 30_000);");
  const iterator = provider.start(inputFor("cancel-stream"))[Symbol.asyncIterator]();

  const first = await iterator.next();
  assert.equal(first.value?.kind, "tool.started");

  const cancelResult = await provider.cancel("cancel-stream");
  assert.equal(cancelResult.cancelled, true);

  const rest: AgentEventPayload[] = [];
  for (;;) {
    const next = await iterator.next();
    if (next.done) {
      break;
    }
    rest.push(next.value);
  }

  assert.equal(rest.at(-1)?.kind, "run.cancelled");
  assert.deepEqual(rest.at(-1)?.data, { exitCode: null, signal: "SIGTERM" });
});

test("CommandAgentProvider writes stdin to a running agent", async () => {
  const provider = new NodeScriptProvider(
    "process.stdin.once('data', (chunk) => { console.log(chunk.toString().trim()); process.exit(0); });",
    true
  );
  const iterator = provider.start(inputFor("stdin-stream"))[Symbol.asyncIterator]();

  const first = await iterator.next();
  assert.equal(first.value?.kind, "tool.started");

  const inputResult = await provider.stdin("stdin-stream", "approved\n");
  assert.deepEqual(inputResult, { ok: true });

  const rest: AgentEventPayload[] = [];
  for (;;) {
    const next = await iterator.next();
    if (next.done) {
      break;
    }
    rest.push(next.value);
  }

  assert(rest.some((event) => event.kind === "assistant.text" && event.text?.includes("approved")));
  assert.equal(rest.at(-1)?.kind, "run.completed");
});

test("CommandAgentProvider closes stdin for argument-only one-shot agents", async () => {
  const provider = new NodeScriptProvider(
    "process.stdin.once('end', () => { console.log('stdin closed'); process.exit(0); }); process.stdin.resume();"
  );

  const events = await collect(provider.start(inputFor("stdin-close-stream")));

  assert(events.some((event) => event.kind === "assistant.text" && event.text?.includes("stdin closed")));
  assert.equal(events.at(-1)?.kind, "run.completed");
});

class NodeScriptProvider extends CommandAgentProvider {
  readonly id = "custom" as const;
  readonly displayName = "Node Test Agent";
  protected readonly executableName = process.execPath;

  constructor(
    private readonly script: string,
    private readonly keepStdinOpen = false
  ) {
    super();
  }

  protected command(_input: AgentRunInput): AgentCommand {
    return {
      bin: process.execPath,
      args: ["--input-type=module", "--eval", this.script],
      stdin: null,
      keepStdinOpen: this.keepStdinOpen
    };
  }
}

function inputFor(streamId: string): AgentRunInput {
  return {
    provider: "custom",
    prompt: "hello",
    mode: "oneshot",
    requireApprovalForWrites: true,
    workspaceRoot: process.cwd(),
    streamId
  };
}

async function collect(iterable: AsyncIterable<AgentEventPayload>): Promise<AgentEventPayload[]> {
  const events: AgentEventPayload[] = [];
  for await (const event of iterable) {
    events.push(event);
  }
  return events;
}
