# Pulse Oscilla Architecture

Pulse Oscilla extends a developer's local machine onto iOS through a secure command-level bridge. The phone is a native controller; the host owns all repository context, command execution, file mutations, git state, local previews, and AI coding-agent processes.

## Runtime Model

1. The developer runs `npx pulse-oscilla` inside or near a repo.
2. The host agent opens a local WebSocket server, creates a short-lived pairing session, and prints a QR payload.
3. The iOS app scans the QR code, verifies the host fingerprint, performs key agreement, and receives a trusted session.
4. iOS sends typed protocol requests by capability.
5. The host executes locally and streams typed events back to iOS.

No cloud service is required. Optional tunnel support should be implemented as another transport adapter using the same end-to-end encrypted session keys.

## Trust Boundary

The iOS device is a controller, not a repository host. Repository context remains on the local machine.

The host enforces:

- workspace-root path confinement
- device/session authentication
- capability-level authorization
- audit logging for shell, writes, git, and AI runs
- explicit approval points for high-risk actions

## Transport

The v1 transport is WebSocket because it supports low-latency bidirectional streams, works well with PTYs, and is simpler to operate locally than gRPC. Protocol messages use JSON envelopes. Large file transfers can add binary frames later without changing the control protocol.

Every request and event includes a `requestId` and usually a `streamId`. Long-running terminal and AI runs are stream-addressable and can survive temporary client disconnects.

## AI Layer

AI coding agents run as host processes in the selected workspace. Pulse Oscilla does not upload repo files from iOS. Provider adapters normalize output from:

- Claude Code
- OpenAI Codex
- OpenCode
- user-defined custom agent commands

The host watches changed files during a run and returns final diffs, changed paths, and structured run events.

## iOS Architecture

The app uses SwiftUI and Observation. Each feature owns an observable store while transport, pairing, and secure session state live in actors/services under `Core`.

The app is designed around suspend/resume rather than pretending iOS can keep sockets alive indefinitely in the background.

