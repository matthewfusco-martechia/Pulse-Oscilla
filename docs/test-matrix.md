# Test Matrix

This matrix defines the minimum validation expected before a production or TestFlight release. Mark each row with the build number, host commit/package version, device, OS version, and tester initials.

## Required Environments

| Area | Minimum Coverage |
| --- | --- |
| iOS device | One physical iPhone on the minimum supported iOS version and one on the current iOS release. |
| Host OS | macOS on Apple silicon for App Store review parity. Add Linux or Windows only when those hosts are claimed as supported. |
| Node.js | Current supported LTS matching `package.json` engines, currently Node.js 20.10 or newer. |
| Network | Same Wi-Fi LAN, hotspot or restricted network, and offline/reconnect recovery. |
| Workspace | Clean demo repo, repo with uncommitted changes, and repo with ignored/private files. |

## Host And Protocol

| Test | Expected Result |
| --- | --- |
| `npm run typecheck` | Protocol, host-agent, and CLI TypeScript projects compile. |
| `npm run smoke:pairing` | Local pairing smoke test passes. |
| Host start from repo root | QR is printed and workspace root is scoped to that repo. |
| Pairing TTL expiry | Expired QR cannot pair. |
| Wrong or stale QR | Pairing fails without creating trust. |
| Device trust reset | Reconnect requires a fresh QR after trust is removed. |
| Path traversal attempt | Host denies reads/writes outside workspace root. |
| Shell audit event | Terminal command is recorded in host audit log. |
| File write audit event | File mutation is recorded with path and request context. |
| Git action audit event | Git operation is recorded and user-visible. |

## iOS App

| Test | Expected Result |
| --- | --- |
| First launch | Onboarding explains host requirement and pairing. |
| Camera denied | App explains QR scanning needs camera access and offers recovery. |
| Local network denied | App explains host connectivity limitation. |
| Successful QR scan | Secure session starts and workspace capability state appears. |
| App background/foreground | Connection recovers or shows an accurate reconnect state. |
| Host offline | App shows a non-destructive disconnected state. |
| Large stream | Timeline remains responsive while host streams output. |
| Rotation and Dynamic Type | Core pairing and chat UI remain usable. |
| Dark and light mode | Text, glass/material surfaces, and status colors remain legible. |

## Agent Providers

| Provider | Required Checks |
| --- | --- |
| Codex | Launch, stream response, stop/cancel, changed-file summary. |
| Claude Code | Launch with prompt argument, stream response, stop/cancel, error state when missing. |
| OpenCode | Launch with prompt argument, stream response, stop/cancel, error state when missing. |
| Custom command | Prompt delivery, stdin/argument behavior, nonzero exit handling. |

## App Store Review

| Test | Expected Result |
| --- | --- |
| Clean install from archived build | App launches without development-only configuration. |
| Review host setup | Reviewer can follow documented host-start steps. |
| No secrets scan | Build settings, docs, and package defaults do not include private relay URLs or credentials. |
| Privacy labels review | App Store Connect answers match the build. |
| Permission prompt review | Prompts match actual feature use. |
| Support URL review | Public docs cover pairing, reset, and host setup. |

## Regression Sign-Off Template

```text
Build:
Host commit/package:
iOS device and version:
Host OS and Node.js:
Network:
Completed matrix rows:
Known issues:
Release decision:
```
