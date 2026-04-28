# Phased Parity Plan

Pulse Oscilla uses Remodex as a product and architecture reference, but the goal is not a direct clone. Pulse Oscilla should preserve its broader multi-agent host model while adopting the proven local-first, paired iPhone controller workflow.

## Phase 0: Safe Foundation

Goal: make the existing host and iOS skeleton shippable for controlled testing.

- Keep the host local-first with no required cloud dependency.
- Complete QR pairing and secure handshake from the iOS scanner.
- Enforce workspace-root path confinement.
- Keep audit logging for shell, file, git, and agent actions.
- Document App Store privacy, support, and review flows.
- Validate the test matrix on physical hardware.

Exit criteria:

- A new tester can start the host, pair an iPhone, and run a safe demo workflow from docs alone.
- Failed pairing, expired QR, host offline, and permission-denied states are understandable.

## Phase 1: Remodex-Style Conversation Core

Goal: reach parity with the core iPhone-native chat control loop.

- Persist conversation/thread state.
- Stream assistant and tool output into a bottom-anchored timeline.
- Add queued follow-up prompts while a run is active.
- Add stop/cancel and clear run-state recovery.
- Show changed paths and final diff summaries after agent runs.
- Support trusted reconnect without requiring a fresh QR for every host restart.

Exit criteria:

- A user can leave and return to an active run without losing the conversation context.
- The phone can steer and inspect a host-side agent run without touching the host terminal.

## Phase 2: Developer Workflow Parity

Goal: make common repository workflows practical from iPhone.

- Add git status, diff, branch switch, commit, pull, and push flows with approvals.
- Add file mention and slash-command composer affordances.
- Add plan mode as a first-class agent run mode.
- Add provider capability badges for Codex, Claude Code, OpenCode, and custom commands.
- Add local preview discovery/opening for host-served development servers.

Exit criteria:

- A user can inspect changes, ask an agent for edits, review diffs, and commit from iPhone with clear approval points.
- Provider differences are visible instead of hidden behind generic errors.

## Phase 3: Production Operations

Goal: harden the product for public TestFlight and App Store operations.

- Add a public support guide and privacy policy.
- Add release compatibility notes between app builds and host package versions.
- Add reset and recovery UX for broken trust state.
- Add optional notification flow only after privacy and permission docs are updated.
- Add optional relay/Tailscale guidance while preserving direct local operation.
- Add crash/diagnostic collection only if it is explicitly disclosed and user-appropriate.

Exit criteria:

- App Review can validate the app from documented setup steps.
- Users can diagnose host reachability, stale pairing, and missing agent commands without developer support.

## Phase 4: Advanced Parity And Differentiation

Goal: go beyond Remodex where Pulse Oscilla's protocol model is broader.

- Add multi-workspace switching with clear trust boundaries.
- Add richer agent orchestration across multiple providers.
- Add capability-scoped approvals for high-risk tools.
- Add attachment handling beyond photos if privacy docs and storage rules are ready.
- Add self-hosted relay recipes for stable private-network use.
- Add enterprise-friendly audit export if demand appears.

Exit criteria:

- Pulse Oscilla remains local-first and self-hostable while supporting workflows that are not tied to a single AI runtime.
- New hosted or relay features do not weaken the host-owned repository model.
