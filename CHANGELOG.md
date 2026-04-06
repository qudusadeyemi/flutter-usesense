# Changelog

All notable changes to `usesense_flutter` will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/).

## [4.1.0] - 2026-04-06

### Breaking Changes
- **Removed `gatewayKey`** from `UseSenseConfig`. The Cloudflare Worker proxy
  now injects Supabase gateway headers server-side. SDKs only send the
  `x-api-key` header.
- **Android minimum SDK raised** from API 24 to **API 28** (Android 9+).
- Native SDK dependencies updated to v4.1.0 (`UseSenseSDK ~> 4.1.0` on iOS,
  `ai.usesense:sdk:4.1.0` on Android).

### Added
- `UseSenseFlutter.startVerificationWithToken()` for the server-side init
  token exchange flow (1:1 reference image matching, zero-credential exposure).
- `UseSenseResult` now includes pillar scores: `channelTrustScore`,
  `livenessScore`, `dedupeRiskScore` (0-100), per-pillar verdicts
  (`channelTrustVerdict`, `livenessVerdict`, `dedupeVerdict`), and inline
  step-up status (`stepUpTriggered`, `stepUpPassed`).
- 5 new event types: `stepUpTriggered`, `stepUpCompleted`, `faceGuideReady`,
  `countdownStarted`, `geometricCoherenceCompleted`.
- 6 new error codes: `nonceMismatch`, `tokenExpired`, `tokenAlreadyUsed`,
  `tokenNotFound`, `insufficientCredits`, `rateLimited`.
- `rate_limited` added to retryable error codes.
- `PigeonTokenExchangeRequest` Pigeon message class for the token exchange
  flow.

### Changed
- Example app restyled using the UseSense Brand Manual v3.0 color palette
  (`#4F7CFF` blue primary, `#00D4AA` green, `#FF6B4A` red, warm neutrals).
- Example result screen now displays pillar score bars with color-coded
  verdicts and step-up status.
- Example home screen adds "Verify with Token" flow for server-side init
  demonstration.
- Default branding primary color updated from `#4F46E5` to `#4F7CFF`.
- API key prefix in example changed from `sk_test_*` to `pk_sandbox_*` to
  reflect that publishable keys should be used in client apps.

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
