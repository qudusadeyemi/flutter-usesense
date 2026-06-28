# Changelog

All notable changes to `usesense_flutter` will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/).

## [2.4.1] - 2026-06-28

### Changed
- Pinned the native SDK to 4.6.0 (Sense rebrand): iOS `UseSenseSDK ~> 4.6`, Android `ai.usesense:sdk:4.6.0`. Previously Android was hard-pinned to 4.5.0.

## [2.4.0] - 2026-06-28

### Changed
- Rebranded front-facing copy from UseSense to Sense.

## [2.3.0] - 2026-06-27

### Added
- White-label `appearance` (FlowAppearance) and `copy` (FlowCopy) overrides, forwarded through the iOS and Android Flows bridges to `UseSenseFlows.run` so the verification flow's look and copy can be customised from the SDK or the dashboard.

### Changed
- Pinned UseSenseSDK to 4.5.0 (iOS `~> 4.5`, Android `ai.usesense:sdk:4.5.0`), which ships the appearance/copy API the bridge calls.

### Fixed
- Removed an invalid trailing comma in the iOS bridge's `UseSenseFlows.run(...)` call that would fail to compile on pre-Swift-6.1 toolchains.

## [2.2.1] - 2026-06-23

### Fixed

- **Android build failure.** Since 2.1.0 the Android bridge passed
  `antispoofOnDeviceEnabled` + `liveSenseV4Enabled` to `UseSenseConfig`, but
  those params shipped only on the iOS SDK — the pinned Android SDK
  (`ai.usesense:sdk:4.3.0`) lacked them, so Android consumers failed to compile.
  Bumped the Android SDK pin to `4.4.0`, which adds both params (and the
  on-device antispoof + LiveSense v4 support) at iOS parity. iOS is unaffected
  (the `~> 4.4` CocoaPods pin already resolves `UseSenseSDK 4.4.1`).

## [2.2.0] - 2026-06-23

Pins the native iOS SDK to **4.4.0**, which makes on-device face mesh work out of
the box. Additive and backward-compatible.

### Fixed

- **iOS face capture "No frames captured."** The face liveness step records frames
  only when on-device face mesh (MediaPipe) is linked. UseSenseSDK 4.4.0 vendors
  patched MediaPipe and pulls it in automatically — no per-app `MediaPipeTasksVision`
  pod, `pre_install` Info.plist hook, or `:linkage => :static` change. Plain
  `use_frameworks!` works (UseSenseSDK 4.4 is a `static_framework`).

### Changed

- iOS dependency pinned to `UseSenseSDK ~> 4.4` (was `~> 4.3`).

## [2.1.0] - 2026-06-16

Tracks the native SDK 4.3.0 release. Additive and backward-compatible —
existing integrations are unaffected; both new flags default to `false`.

### Added

- **`UseSenseConfig.liveSenseV4Enabled`** — opt the session into the
  LiveSense v4 capture flow (constitutive zoom-motion phase + per-frame
  capture-phase tagging + `x-usesense-sdk-version: v4` header). The org
  must also have `livesense_v4_enabled` in its server-side features map.
  Threaded through the Pigeon interface to both platforms.
- **`UseSenseConfig.antispoofOnDeviceEnabled`** — opt in to the on-device
  CelebA-Spoof classifier (native loads the bundled model and attaches
  per-frame spoof probabilities to the upload). Defaults off, in which
  case the watchtower backend runs the classifier server-side.

### Changed

- Native SDK dependency bumped to `4.3.0` (iOS `UseSenseSDK ~> 4.3` via
  CocoaPods; Android `ai.usesense:sdk:4.3.0` via Maven Central).

## [2.0.1] - 2026-04-11

**No-op release.** Bumps the package version with no code changes in
order to validate the `release.yml` GitHub Actions workflow and the
pub.dev OIDC publishing path end-to-end. The `2.0.0` release was
published manually from a local `dart pub publish` because the
OIDC pipeline wasn't wired up yet; this release flushes the same
bits through the automated pipeline so subsequent releases can rely
on tag-pushes as the single source of truth.

No API, wire, or runtime behavior changes — `2.0.0` and `2.0.1` are
binary- and source-compatible.

## [2.0.0] - 2026-04-11

**Breaking release.** Combines the native-SDK / infrastructure /
tooling alignment that was originally planned for `1.1.0` with a
single wire-level breaking change: removal of the deprecated
`gatewayKey` field from `PigeonUseSenseConfig` (and therefore from
the public Dart-facing `UseSenseConfig`). Since the plugin has
never been published to pub.dev and nobody is currently consuming
the `1.0.0` git tag, the breaking change is safe to land directly.

### Removed — BREAKING

- **`UseSenseConfig.gatewayKey`** is gone from the Dart API,
  from the Pigeon-generated `.g.dart` / `.g.swift` / `.g.kt`
  files, and from the Pigeon interface at
  `pigeons/usesense_api.dart`. The field was a v1.x artefact
  from the pre-v4 native SDK era when the plugin passed a
  gateway token through to the native SDK. The native SDKs
  removed the corresponding parameter in v4.0 when the
  Cloudflare Worker proxy took over gateway responsibilities
  server-side, and the plugin was keeping `gatewayKey` around
  only as a deprecated no-op for backward compatibility.
  Removing it from the Pigeon wire shifts the encoded field
  indices (`branding` moves from index 4 to 3,
  `googleCloudProjectNumber` from 5 to 4), so the change is
  wire-incompatible with any `1.0.0` consumer even though
  `gatewayKey` itself was a no-op. Bumping to 2.0.0 makes
  that visible.

### Migration from 1.0.0

Remove any `gatewayKey:` argument from your
`UseSenseConfig(...)` calls:

```diff
  UseSenseConfig(
    apiKey: 'sk_sandbox_...',
    environment: UseSenseEnvironment.sandbox,
-   gatewayKey: 'obsolete',  // remove this line
  )
```

No other public API changes. `apiKey`, `environment`, `baseUrl`,
`branding`, `googleCloudProjectNumber`, `startVerification`,
`startRemoteEnrollment`, `startRemoteVerification`, `onEvent`,
`onCancelled`, `reset` — all unchanged. Code that wasn't passing
`gatewayKey` compiles and runs unchanged against 2.0.0.

### Non-breaking: everything else originally planned for 1.1.0

### Added

- **CI workflow** at `.github/workflows/ci.yml` — runs
  `flutter analyze`, `dart format --set-exit-if-changed`,
  `flutter test`, and `flutter pub publish --dry-run` on every PR.
- **Release workflow** at `.github/workflows/release.yml` —
  triggers on `v*` tag push, verifies the pubspec version matches
  the tag, runs the full CI suite, and publishes to pub.dev via
  OIDC (no long-lived secret required; see the workflow header
  for the one-time pub.dev Automated Publishing setup). Creates
  a matching GitHub Release with auto-generated release notes.
- **`.github/` governance files**: `CODEOWNERS`, PR template,
  bug report + feature request issue templates — matching the
  layout of `qudusadeyemi/usesense-ios-sdk` and
  `qudusadeyemi/usesense-android-sdk`.
- **Example app now accepts the API key at runtime** via a
  `TextField` with show/hide toggle, a sandbox/production
  `Switch`, and `shared_preferences` persistence across
  launches. Matches the iOS example's `@AppStorage("apiKey")` +
  `SecureField` pattern and the Android example's
  `SharedPreferences` pattern — integrators clone, run, paste
  their key once, and test without touching any source code.
  Removes the hardcoded `sk_test_YOUR_SANDBOX_API_KEY`
  placeholder in `example/lib/main.dart`.
- **`shared_preferences: ^2.3.2`** added as an example-only
  dependency. The plugin itself has no runtime state to persist.

### Changed

- **Native iOS SDK dep** in `ios/usesense_flutter.podspec` bumped
  from `~> 1.0.0` to `~> 4.2`. The v1.x SDK used a pre-redaction
  result type and a different `UseSenseConfig` init signature;
  v4.2+ is the current shape used by iOS and Android alike.
- **Native Android SDK dep** in `android/build.gradle.kts` bumped
  from `ai.usesense:sdk:1.0.0` to `ai.usesense:sdk:4.2.1`. The
  Android SDK is now on Maven Central (published as part of the
  v4.2.0 / v4.2.1 release cycle), so `mavenCentral()` is the
  only repository integrators need.
- **iOS plugin (`UseSenseFlutterPlugin.swift`)** no longer passes
  `gatewayKey` to `UseSenseConfig`. The field was removed from
  the native SDK in v4.0 when the Cloudflare Worker proxy took
  over gateway responsibilities server-side. The Pigeon interface
  still accepts the field as a deprecated no-op for backward
  compatibility; it will be removed from the public Pigeon API
  in the next major release.
- **Android plugin (`UseSenseFlutterPlugin.kt`)** ditto — no
  longer passes `gatewayKey` to the native `UseSenseConfig`.
- **iOS plugin error mapping** extended to cover the v4.x-era
  error codes (`tokenExpired`, `tokenAlreadyUsed`,
  `insufficientCredits`, `nonceMismatch`) that were added to
  the native SDK alongside the token-exchange / step-up flows.
- **Default primary colour** in the iOS plugin's BrandingConfig
  fallback bumped from `#4F63F5` (legacy indigo) to `#4F7CFF`
  (DeepSense Blue per Brand Manual v3.0), matching the native
  iOS SDK's default.
- **CONTRIBUTING.md** gains a "Maintainer notes" section
  documenting the Pigeon code generation workflow, the native
  SDK version management process, and the pub.dev OIDC setup.

### Fixed

- `pubspec.yaml` `repository` field pointed at the retired
  `github.com/usesense/usesense-flutter` namespace. Corrected to
  `github.com/qudusadeyemi/flutter-usesense`.
- `pubspec.yaml` `documentation` field pointed at the retired
  `docs.usesense.ai` domain. Corrected to
  `watchtower.usesense.ai/developer-docs`.
- `README.md` "Support" section's repository link had the same
  stale namespace. Fixed.
- `README.md` Android install section referenced a fabricated
  `maven.usesense.com/releases` repository that never existed.
  Removed; the native SDK is now on Maven Central.
- `example/README.md` setup instructions referenced the retired
  `app.usesense.ai` dashboard. Corrected to
  `watchtower.usesense.ai`.

### Notes for integrators

- Except for the removed `gatewayKey` field (see the "Removed —
  BREAKING" section above), no other public Dart API surface has
  changed. `UseSenseConfig` gains no new fields, and
  `VerificationRequest`, `UseSenseResult`, and `UseSenseEvent` are
  unchanged. Code that wasn't passing `gatewayKey` compiles and
  runs unchanged.

## [1.0.0] - 2026-03-13

### Added
- `UseSenseFlutter.initialize()` for SDK configuration with API key and environment
- `UseSenseFlutter.startVerification()` for enrollment and authentication sessions
- `UseSenseFlutter.startRemoteEnrollment()` for hosted enrollment flows
- `UseSenseFlutter.startRemoteVerification()` for hosted verification flows
- `UseSenseFlutter.onEvent` stream for real-time session event listening
- `UseSenseFlutter.onCancelled` stream for user cancellation detection
- `UseSenseFlutter.isInitialized()` for initialization state checking
- `UseSenseFlutter.reset()` for SDK cleanup and resource release
- `UseSenseResult` with decision (APPROVE, REJECT, MANUAL_REVIEW), session ID,
  identity ID, and convenience getters (`isApproved`, `isRejected`, `isPendingReview`)
- `UseSenseError` with 13 structured error codes and retry guidance
- `UseSenseEvent` with 18 event types covering the full session lifecycle
- `BrandingConfig` for UI customization (logo, colors, button radius, font)
- Pigeon-based type-safe platform channels (Dart, Kotlin, Swift)
- iOS support via UseSenseSDK (iOS 16.0+)
- Android support via UseSense Android SDK (API 24+)
- Multi-screen example app with enrollment, authentication, and event log
- Comprehensive README, integration guide, and pub.dev packaging
- CI/CD workflows for pull requests and pub.dev releases
