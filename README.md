# Pulse Oscilla

Pulse Oscilla is a local-first bridge between an iPhone and a developer machine. It is not remote desktop or screen mirroring; it exposes command-level primitives for terminal sessions, files, git, local previews, and AI coding agents running on the host machine.

## Repository Layout

```text
packages/protocol     Shared TypeScript protocol contracts for the host side
packages/host-agent   Local machine agent: pairing, transport, shell, files, git, AI
packages/cli          npx-facing CLI wrapper
apps/ios/PulseOscilla SwiftUI client source skeleton
docs/architecture.md  Production architecture and protocol notes
```

## Host Agent

Install dependencies, then start the host from a local repository:

```bash
npm install
npm run dev
```

For a longer setup window while installing the iOS app on a physical device:

```bash
npm run dev -- --pairing-ttl-minutes 60
```

If the host is being launched by an automation session and you cannot answer the CLI trust prompt directly, allow the first QR holder to pair:

```bash
npm run dev -- --pairing-ttl-minutes 60 --trust-on-first-use
```

The CLI starts a local WebSocket bridge, creates a short-lived pairing session, and prints a QR payload that the iOS client can scan. The workspace exposed to iOS is the directory where you run `npm run dev`.

Run the host pairing smoke test:

```bash
npm run smoke:pairing
```

## Current Implementation Stage

This repo contains the production-oriented foundation:

- typed protocol envelopes and capabilities
- host CLI bootstrap
- QR pairing/session service
- per-workspace trusted-device store with CLI approval for new devices
- encrypted-session primitives
- WebSocket bridge routing
- PTY terminal manager
- guarded file service
- git service
- AI agent provider abstraction for Claude Code, Codex, OpenCode, and custom commands
- SwiftUI app structure with transport/security/state-management skeletons

The next implementation pass should wire the SwiftUI QR scanner to the secure handshake and harden the host authorization policy around trusted devices.
