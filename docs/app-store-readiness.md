# App Store Readiness

This checklist defines the minimum production documentation and release gates for shipping Pulse Oscilla through the App Store. It is written for the current local-first product shape: an iOS controller paired to a developer-owned host process.

## Product Positioning

Pulse Oscilla should be presented as a local-first developer companion, not remote desktop, screen sharing, cloud IDE, or hosted AI runtime.

Approved positioning:

- Controls a paired developer machine from iPhone.
- Keeps repositories, shell commands, git operations, credentials, and agent processes on the host.
- Uses a short-lived QR pairing flow to establish trust.
- Exposes command-level tools for terminal, files, git, previews, and AI coding agents.
- Supports Codex, Claude Code, OpenCode, and custom local commands through host-side adapters.

Avoid claims that imply:

- Pulse Oscilla hosts or stores user repositories in a cloud service.
- The iPhone executes arbitrary code locally.
- A relay, if added later, can read repository content or chat payloads after secure-session setup.
- The app guarantees unattended background execution on iOS.

## App Review Notes

Include a short review note with each submission:

```text
Pulse Oscilla pairs with a local host process started by the user on their own developer machine. The iOS app scans a QR code from that host and then sends typed commands over an encrypted session. Repository files, git credentials, shell commands, and AI coding agents remain on the user's host machine.
```

If the build requires a companion host for meaningful review, provide:

- A test host setup command.
- A demo workspace that does not contain private credentials.
- A pairing QR generation path with a long enough TTL for review.
- A reviewer account only if a future hosted service or subscription gate requires one.

## Privacy Nutrition Labels

The App Store privacy answers must match the shipping build, not the roadmap. For the current local-first build, expected disclosures are:

- No third-party advertising or cross-app tracking.
- No analytics collection unless a telemetry SDK is later added and documented.
- User content such as prompts, file snippets, terminal output, photos, or voice input is processed by the paired host when the user initiates those features.
- Device identifiers or pairing identifiers may be stored locally for trusted-device reconnect.
- Diagnostics are local unless explicit crash reporting or hosted logging is added.

If a managed relay, push service, subscription provider, hosted logs, voice transcription, or analytics service is added, update this file, `docs/privacy-local-first.md`, the App Store privacy labels, and the in-app privacy copy before release.

## Required Legal And Support Assets

Before App Store submission:

- Publish a privacy policy that matches [Privacy and Local-First Model](privacy-local-first.md).
- Publish terms of use if subscriptions, paid features, hosted relay, or account-like services are introduced.
- Add a support URL with pairing, host start, and reset instructions.
- Add third-party notices for Remodex-derived code or substantially adapted implementation details.
- Confirm all app icons, screenshots, trademarks, and names are owned or licensed for distribution.

## Permission Review

Every iOS permission prompt must explain the local-first reason for access.

- Camera: scan the host pairing QR.
- Local network: connect to the paired host on the same network.
- Photos: attach selected images to a host-side agent run, if implemented.
- Microphone or speech: capture voice prompt input, if implemented.
- Notifications: alert when a local agent run completes or needs attention, if implemented.

Do not request permissions before the user reaches the feature that needs them.

## Security Release Gates

Do not submit a production build until these are verified:

- Pairing QR expires and cannot be reused indefinitely.
- Device trust is explicit, revocable, and scoped to the host/workspace policy.
- Host path access is confined to the selected workspace root.
- Shell, write, git, and agent actions produce audit records on the host.
- High-risk actions have explicit approval points or conservative defaults.
- Secrets are not committed in app source, docs examples, package defaults, or build settings.
- Debug endpoints, verbose transport logs, and trust-on-first-use shortcuts are not enabled by default in production.

## Release Checklist

- App metadata explains that a companion host process is required.
- Screenshots show the pairing flow and local host relationship.
- Review instructions include host start and pairing steps.
- Privacy labels match the exact build configuration.
- In-app onboarding links to host setup and reset instructions.
- Test matrix is complete for at least one physical iPhone and one macOS host.
- Support contact and privacy policy URLs are live.
- Rollback plan is documented for the App Store build and host package.

## Rollback Plan

For every release, record:

- App Store version and build number.
- Compatible host package or repo commit.
- Minimum iOS, macOS, Node.js, and Xcode versions used for validation.
- Known incompatible protocol versions.
- Steps to downgrade the host package or run the previous tagged host.

If a release breaks pairing or trusted-device state, prioritize a host-side compatibility patch when possible because App Store rollback is slower than publishing a host package.
