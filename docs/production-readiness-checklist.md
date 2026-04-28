# Production Readiness Checklist

Use this as the release owner checklist. The detailed evidence should live in the linked docs.

## Documentation

- [x] README explains the host requirement and links to production docs.
- [x] App Store readiness gates are current.
- [x] Privacy/local-first model matches the shipping build.
- [ ] Pairing and host-start instructions have been tested from a clean checkout.
- [ ] Test matrix is completed for the target build.
- [x] Phased parity plan reflects current implementation status.
- [x] Third-party notices include Remodex if code or substantial implementation details are copied or derived.

## App Store

- [ ] Privacy policy URL is live.
- [ ] Support URL is live.
- [ ] Review notes include host setup and pairing steps.
- [ ] Screenshots show the local host relationship.
- [ ] App metadata does not imply cloud repository hosting.
- [ ] Privacy nutrition labels match the exact build.

## Security

- [ ] Pairing QR expires.
- [ ] Trust reset is documented and tested.
- [ ] Workspace path confinement is tested.
- [ ] High-risk actions have approvals or safe defaults.
- [ ] No private relay URLs, credentials, APNs keys, or signing secrets are committed.
- [ ] Debug-only trust shortcuts are disabled by default for release builds.

## Verification

- [x] `npm run typecheck`
- [ ] `npm run smoke:pairing`
- [x] iOS debug build/install on a physical device.
- [x] `xcodebuild -quiet -project apps/ios/PulseOscilla.xcodeproj -scheme PulseOscilla -destination generic/platform=iOS -derivedDataPath /tmp/pulse-oscilla-ios build`
- [x] `npm run test --workspace @pulse-oscilla/host-agent`
- [ ] Pairing on same Wi-Fi.
- [ ] Host offline/reconnect behavior.
- [ ] Permission-denied states for camera and local network.
- [ ] Agent provider missing-command errors.
- [ ] Git workflow on a disposable demo repository.
