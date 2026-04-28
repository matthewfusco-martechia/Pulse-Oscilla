# Pairing and Host Start

This guide covers the production host-start and pairing flow for Pulse Oscilla.

## Start The Host

Run the host from the workspace the iPhone should control:

```bash
npm install
npm run host
```

The host starts a local WebSocket bridge, creates a short-lived pairing session, and prints a QR payload. The workspace exposed to iOS is the directory where the command was started.

For a longer setup window while installing the app on a physical device:

```bash
npm run host -- --pairing-ttl-minutes 60
```

For automation sessions where the CLI trust prompt cannot be answered directly:

```bash
npm run host -- --pairing-ttl-minutes 60 --trust-on-first-use
```

Use `--trust-on-first-use` only for controlled test sessions. Production builds and release demos should prefer explicit trust approval.

Local checkout shortcut:

```bash
./bin/pulse-oscilla --pairing-ttl-minutes 60 --trust-on-first-use
```

Public npm shortcut after the CLI package is published:

```bash
npx pulse-oscilla
```

## Pair An iPhone

1. Start the host in the target workspace.
2. Open Pulse Oscilla on the iPhone.
3. Use the in-app scanner, not a generic camera app, to scan the QR code.
4. Verify the host identity/fingerprint when prompted.
5. Approve the device on the host if the CLI requests confirmation.
6. Confirm that the app reaches the workspace screen and can receive host capability state.

The QR code is a bootstrap mechanism. It should not be treated as a permanent credential.

## Trust And Reconnect Expectations

The production model should support these behaviors:

- First scan establishes trust between one iPhone and one host identity.
- Later reconnects reuse trusted-device state when the host is available.
- Resetting trust on either side requires a fresh QR scan.
- Host restarts should not silently grant broader workspace access than the original trust policy allows.
- Expired or already-used pairing payloads should fail closed.

If trusted reconnect is incomplete in the current build, document that limitation in App Review notes and support docs rather than implying fully unattended reconnect.

## Host Workspace Policy

The host should expose only the workspace selected at start.

- Start the host from the repository root for single-repo work.
- Start from a parent workspace only when multi-repo access is intentional.
- Keep private credentials outside demo workspaces used for App Review.
- Avoid launching from a home directory or broad filesystem root.

## Smoke Test

Run the pairing smoke test before release:

```bash
npm run smoke:pairing
```

This command runs TypeScript validation first, then exercises the local pairing path.

## Troubleshooting

If pairing fails:

- Confirm the iPhone and host can reach each other on the selected network.
- Restart the host and generate a fresh QR code.
- Increase the pairing TTL for manual setup.
- Check whether a firewall is blocking the host WebSocket port.
- Verify the app scanned from the in-app QR scanner.
- Reset trusted-device state if a stale host identity is suspected.

If pairing works but commands fail:

- Confirm the host was started from the intended workspace.
- Check host audit logs for denied capabilities.
- Verify the requested agent command is installed on the host and available in `PATH`.
- Confirm path confinement is not rejecting access outside the workspace root.
