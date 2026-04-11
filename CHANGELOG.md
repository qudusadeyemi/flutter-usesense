# Changelog

All notable changes to `usesense_flutter` will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-04-11

Infrastructure, native-SDK, and tooling alignment release. No
breaking changes to the Dart-facing public API. Bumps the native
SDK deps so the plugin finally compiles against the current iOS /
Android SDK releases, adds CI + release automation, and reworks
the example app to accept the API key at runtime.

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

- No changes to the public Dart API. The `UseSenseConfig`,
  `VerificationRequest`, `UseSenseResult`, and `UseSenseEvent`
  classes are unchanged. Any code written against `1.0.0` should
  keep compiling against `1.1.0` without modification.
- `UseSenseConfig.gatewayKey` is deprecated and has no effect
  (the native SDK no longer supports a gateway key — gateway
  responsibilities live in the Cloudflare Worker proxy at
  `api.usesense.ai`). Remove any `gatewayKey:` argument from
  your `UseSenseConfig(...)` calls at your convenience; it will
  be removed entirely in the next major release.

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
