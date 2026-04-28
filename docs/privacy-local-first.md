# Privacy and Local-First Model

Pulse Oscilla is designed so the user's developer machine remains the system of record. The iPhone controls the host; it does not become the repository host and it does not require a Pulse Oscilla cloud account for the local pairing model.

## Core Privacy Promises

- Repository files stay on the user's host unless the user explicitly asks the host to transmit data elsewhere through an agent or tool.
- Shell commands, git operations, file writes, previews, and AI coding agents run on the host.
- The iOS app sends typed requests and displays streamed results from the host.
- Pairing uses a short-lived QR bootstrap and a trusted-session model.
- Transport payloads should be encrypted after the secure handshake.
- A relay, if introduced, must be treated as a routing layer, not a trusted data processor for plaintext application payloads.

## Data Flow

1. The user starts the host in a workspace.
2. The host creates a short-lived pairing payload and displays it as a QR code.
3. The iOS app scans the QR code and performs secure session setup with the host.
4. The iOS app sends capability-scoped commands such as terminal input, file reads, git operations, or agent prompts.
5. The host performs the requested work locally and streams typed events back to iOS.

This model means App Store disclosures should focus on user-initiated local processing, local network communication, pairing identifiers, and any optional services that are actually present in the shipping build.

## Data Categories

| Category | Where It Lives | Purpose | Release Notes |
| --- | --- | --- | --- |
| Pairing identity and trusted-device state | iOS Keychain/app storage and host trust store | Reconnect and authenticate paired devices | Must be revocable by the user. |
| Prompts and chat messages | iOS UI/cache if implemented, host runtime | Send instructions to host-side agents | Do not claim cloud storage unless added. |
| Repository file content | Host workspace | File view/edit and agent context | iOS should request only user-selected or feature-required content. |
| Terminal output | Host process, streamed to iOS | Show command results | Avoid persistent hosted logs by default. |
| Git metadata | Host repository | Status, branch, diff, commit operations | Treat remote pushes as user-approved host actions. |
| Photos or attachments | iOS temporary selection, host runtime | Optional agent input | Requires accurate Photos permission copy if implemented. |
| Voice input | iOS temporary capture, configured transcription path | Optional prompt input | Document the transcription provider before shipping. |

## What Pulse Oscilla Should Not Collect By Default

- Advertising identifiers.
- Cross-app tracking data.
- Behavioral analytics.
- Centralized repository snapshots.
- Hosted plaintext chat transcripts.
- User email, phone number, or account profile for local pairing.

If any of these are added later, the privacy policy, App Store labels, onboarding copy, and release notes must be updated before distribution.

## Permissions Copy

Suggested user-facing permission explanations:

- Camera: "Scan the QR code shown by your host machine to pair this iPhone."
- Local Network: "Connect to the paired host running on your local network."
- Photos: "Attach selected images to the prompt sent to your paired host."
- Microphone: "Record voice input for a prompt you choose to send."
- Notifications: "Notify you when a host-side run finishes or needs attention."

## Host Security Responsibilities

The host must enforce the privacy boundary, not merely document it.

- Confine file access to the selected workspace root.
- Store trusted-device state per workspace or with clearly documented scope.
- Log shell, write, git, and agent actions locally for user review.
- Require explicit confirmation for high-risk commands or broad access modes.
- Never embed private relay URLs, API keys, APNs credentials, or developer secrets in public source.

## App Store Privacy Answer Guidance

Before each release, answer these questions against the actual build:

- Does the app include analytics, crash reporting, subscriptions, push, relay, or transcription SDKs?
- Can any hosted service read prompts, files, terminal output, or chat messages?
- Is any user content retained outside the user's devices?
- Are pairing identifiers linked to a user account or only local trusted-device state?
- Are diagnostics collected automatically, manually exported, or not collected?

The answer must be reflected consistently across App Store Connect, the privacy policy, support documentation, and in-app onboarding.
