# Pulse Oscilla

Pulse Oscilla is a local-first bridge between an iPhone and a developer machine. It is not remote desktop or screen mirroring; it exposes command-level primitives for terminal sessions, files, git, local previews, and AI coding agents running on the host machine.

The product model follows a self-hostable, local-first pattern: the host machine owns code, credentials, git state, shell access, and AI-agent processes; the iPhone is a paired controller. See [Privacy and Local-First Model](docs/privacy-local-first.md) for the App Store privacy posture and [App Store Readiness](docs/app-store-readiness.md) for release gates.

## Repository Layout

```text
packages/protocol     Shared TypeScript protocol contracts for the host side
packages/host-agent   Local machine agent: pairing, transport, shell, files, git, AI
packages/cli          npx-facing CLI wrapper
apps/ios/PulseOscilla SwiftUI client source skeleton
docs/architecture.md  Production architecture and protocol notes
```

## Host Agent

Install dependencies, then start the host from the repository or workspace you want the phone to control:

```bash
npm install
npm run host
```

For a longer setup window while installing the iOS app on a physical device:

```bash
npm run host -- --pairing-ttl-minutes 60
```

If the host is being launched by an automation session and you cannot answer the CLI trust prompt directly, allow the first QR holder to pair:

```bash
npm run host -- --pairing-ttl-minutes 60 --trust-on-first-use
```

The CLI starts a local WebSocket bridge, creates a short-lived pairing session, and prints a QR payload that the iOS client can scan. The workspace exposed to iOS is the directory where you run `npm run host`.

For this checkout you can also run the local CLI wrapper directly:

```bash
./bin/pulse-oscilla --pairing-ttl-minutes 60 --trust-on-first-use
```

After the CLI package is published to npm, the equivalent public command will be:

```bash
npx pulse-oscilla
```

For the operational pairing checklist, recovery flow, and security expectations, see [Pairing and Host Start](docs/pairing-host-start.md).

Run the host pairing smoke test:

```bash
npm run smoke:pairing
```

## Production Readiness Docs

- [App Store Readiness](docs/app-store-readiness.md): release gates, App Review notes, metadata, privacy nutrition labels, support, and rollback readiness.
- [Privacy and Local-First Model](docs/privacy-local-first.md): data-flow promises, App Store privacy answers, permissions, retention, and user-facing disclosure language.
- [Pairing and Host Start](docs/pairing-host-start.md): host launch, QR pairing, trust-on-first-use, reconnect expectations, and troubleshooting.
- [Test Matrix](docs/test-matrix.md): host, iOS, security, network, App Store, and regression coverage required before release.
- [Phased Parity Plan](docs/phased-parity-plan.md): staged Remodex-inspired parity roadmap while preserving Pulse Oscilla's multi-agent scope.

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
