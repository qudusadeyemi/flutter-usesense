# UseSense Flutter Plugin v4.1 Implementation Plan

**Date:** April 6, 2026
**Current state:** v1.0.0 Flutter plugin wrapping native SDKs (`UseSenseSDK ~> 1.0.0` iOS, `ai.usesense:sdk:1.0.0` Android)
**Target:** v4.1.0 unified spec compliance on both iOS and Android

---

## Architecture Context

The Flutter plugin is a **thin bridge** that delegates all heavy lifting to native SDKs via Pigeon-generated platform channels. The native SDKs handle:
- Session creation, camera capture, frame management, challenges
- Signal collection, 3D liveness, upload, verdict handling

The plugin layer handles:
- Dart API surface, config/request/result type mapping
- Pigeon schema (Dart <-> Swift/Kotlin codegen)
- Event forwarding (native -> Dart)
- ViewController/Activity presentation

**Key architectural decision:** The v4.1 features (Geometric Coherence, Suspicion Engine, Inline Step-Up, Cloudflare auth proxy, etc.) are implemented **inside the native SDKs**. The Flutter plugin needs to:
1. Expose new v4.1 APIs (server-side init, token exchange)
2. Add new Pigeon types for v4.1 config/response fields
3. Forward new event types from native SDKs
4. Remove deprecated config fields (gatewayKey)
5. Update dependencies to v4.1 native SDKs
6. Bump version to 4.1.0

---

## Phase 1: Dependency & Version Bumps

### 1.1 Bump native SDK dependencies

**Files:**
- `ios/usesense_flutter.podspec` (line 17): `UseSenseSDK`, `'~> 1.0.0'` -> `'~> 4.1.0'`
- `android/build.gradle.kts` (line 29): `ai.usesense:sdk:1.0.0` -> `ai.usesense:sdk:4.1.0`

**Rationale:** The native SDKs v4.1 implement all the heavy features: Cloudflare Worker auth proxy, Geometric Coherence with MediaPipe + 3DMM + cryptographic binding, Suspicion Engine, Flash Reflection, RMAS, inline step-up orchestrator, screen detection signals, nonce dual-delivery, 30-frame cap, adaptive FPS. The Flutter plugin exposes and configures them.

### 1.2 Bump plugin version

**Files:**
- `pubspec.yaml` (line 6): version `1.0.0` -> `4.1.0`
- `ios/usesense_flutter.podspec` (line 3): version `1.0.0` -> `4.1.0`
- `android/build.gradle.kts` (line 7): version `1.0.0` -> `4.1.0`

### 1.3 Update Android minSdk

**File:** `android/build.gradle.kts` (line 14)
- `minSdk = 24` -> `minSdk = 28` (v4.1 spec requires API 28+ / Android 9)

### 1.4 Update iOS platform version

**File:** `ios/usesense_flutter.podspec` (line 19)
- Keep `ios, '16.0'` (spec says 15.0+ but current already requires 16.0, which is fine)

---

## Phase 2: Pigeon Schema Updates

**File:** `pigeons/usesense_api.dart`

This is the source of truth for the platform channel contract. All changes here auto-generate Dart, Kotlin, and Swift code.

### 2.1 Remove deprecated config field

Remove `gatewayKey` from `PigeonUseSenseConfig`. The Cloudflare Worker proxy means SDKs no longer send Supabase gateway keys.

```dart
// REMOVE from PigeonUseSenseConfig:
//   String? gatewayKey;
```

### 2.2 Add new event types

Add v4.1 lifecycle events to `PigeonEventType`:

```dart
enum PigeonEventType {
  // ... existing 18 types ...
  stepUpTriggered,       // Suspicion engine triggered inline step-up
  stepUpCompleted,       // Inline step-up challenge finished
  faceGuideReady,        // Face positioned correctly in oval guide
  countdownStarted,      // 3-2-1 countdown began
  geometricCoherenceCompleted,  // 3DMM + binding proof computed
}
```

### 2.3 Add server-side init request type

```dart
/// Request for server-side init token exchange flow.
class PigeonTokenExchangeRequest {
  PigeonTokenExchangeRequest({required this.clientToken});
  String clientToken;
}
```

### 2.4 Expand result type with v4.1 verdict fields

```dart
class PigeonUseSenseResult {
  // ... existing fields ...

  // NEW v4.1 fields (nullable for backward compat)
  int? channelTrustScore;    // 0-100
  int? livenessScore;        // 0-100
  int? dedupeRiskScore;      // 0-100
  String? channelTrustVerdict;  // "PASS" | "FAIL" | "REVIEW"
  String? livenessVerdict;
  String? dedupeVerdict;
  bool? stepUpTriggered;
  bool? stepUpPassed;
}
```

### 2.5 Add server-side init host API methods

```dart
@HostApi()
abstract class UseSenseHostApi {
  // ... existing methods ...

  /// Exchange a client token for a session (server-side init flow).
  /// The native SDK calls POST /v1/sessions/exchange-token.
  @async
  PigeonUseSenseResult startVerificationWithToken(
    PigeonTokenExchangeRequest request,
  );
}
```

### 2.6 Regenerate Pigeon code

After all schema changes, run:
```bash
dart run pigeon --input pigeons/usesense_api.dart
```

This regenerates:
- `lib/src/generated/usesense_api.g.dart`
- `android/src/main/kotlin/com/usesense/flutter/UseSenseApi.g.kt`
- `ios/Classes/UseSenseApi.g.swift`

---

## Phase 3: Dart Public API Updates

### 3.1 Update `UseSenseConfig` — remove gatewayKey

**File:** `lib/src/usesense_types.dart`

Remove `gatewayKey` field from `UseSenseConfig` class. The Cloudflare Worker proxy injects gateway headers server-side.

```dart
class UseSenseConfig {
  const UseSenseConfig({
    required this.apiKey,
    this.environment = UseSenseEnvironment.auto,
    this.baseUrl,
    // REMOVED: this.gatewayKey,
    this.branding,
    this.googleCloudProjectNumber,
  });
  // ...
}
```

### 3.2 Add new event types

**File:** `lib/src/usesense_types.dart`

Add to `UseSenseEventType` enum:
```dart
enum UseSenseEventType {
  // ... existing 18 ...
  stepUpTriggered,
  stepUpCompleted,
  faceGuideReady,
  countdownStarted,
  geometricCoherenceCompleted,
}
```

### 3.3 Expand `UseSenseResult` with pillar scores

**File:** `lib/src/usesense_types.dart`

```dart
class UseSenseResult {
  const UseSenseResult({
    required this.sessionId,
    this.sessionType,
    this.identityId,
    required this.decision,
    required this.timestamp,
    this.channelTrustScore,
    this.livenessScore,
    this.dedupeRiskScore,
    this.channelTrustVerdict,
    this.livenessVerdict,
    this.dedupeVerdict,
    this.stepUpTriggered,
    this.stepUpPassed,
  });

  // ... existing fields ...

  /// DeepSense channel trust score (0-100). Null if not available.
  final int? channelTrustScore;
  /// LiveSense liveness score (0-100). Null if not available.
  final int? livenessScore;
  /// MatchSense deduplication risk score (0-100). Null if not available.
  final int? dedupeRiskScore;
  /// Per-pillar verdicts: "PASS", "FAIL", or "REVIEW".
  final String? channelTrustVerdict;
  final String? livenessVerdict;
  final String? dedupeVerdict;
  /// Whether the inline step-up was triggered during this session.
  final bool? stepUpTriggered;
  /// Whether the inline step-up challenge was passed (null if not triggered).
  final bool? stepUpPassed;
}
```

### 3.4 Add new error codes

**File:** `lib/src/usesense_error.dart`

Add error codes matching v4.1 server responses:
```dart
static const int nonceMismatch = 3003;       // Nonce validation failed
static const int tokenExpired = 3004;         // Client token past TTL
static const int tokenAlreadyUsed = 3005;     // Token already exchanged
static const int tokenNotFound = 3006;        // Invalid client token
static const int insufficientCredits = 6002;  // Org out of credits
static const int rateLimited = 2003;          // 429 Too Many Requests
```

Update `codeFromString()` to handle new string codes:
```dart
case 'nonce_mismatch': return nonceMismatch;
case 'token_expired': return tokenExpired;
case 'token_already_used': return tokenAlreadyUsed;
case 'token_not_found': return tokenNotFound;
case 'insufficient_credits': return insufficientCredits;
case 'rate_limited': return rateLimited;
```

### 3.5 Add server-side init method to public API

**File:** `lib/src/usesense_flutter_plugin.dart`

```dart
/// Start a verification session using a client token from server-side init.
///
/// The integrator's backend calls POST /v1/sessions/create-token to get
/// a client_token, passes it to the app, and the SDK exchanges it for
/// a full session via POST /v1/sessions/exchange-token.
///
/// Use this for reference image matching (KYC) or zero-credential-exposure flows.
Future<UseSenseResult> startVerificationWithToken(String clientToken) {
  return _platform.startVerificationWithToken(clientToken);
}
```

### 3.6 Update platform interface

**File:** `lib/src/usesense_flutter_platform_interface.dart`

Add abstract method:
```dart
Future<UseSenseResult> startVerificationWithToken(String clientToken);
```

### 3.7 Update method channel implementation

**File:** `lib/src/usesense_flutter_method_channel.dart`

- Add `startVerificationWithToken()` implementation calling Pigeon host API
- Update `_toPigeonConfig()` to remove `gatewayKey` mapping
- Update `_fromPigeonResult()` to map new pillar score fields

### 3.8 Update barrel export

**File:** `lib/usesense_flutter.dart`

No changes needed if all new types are in existing files. Verify the barrel exports everything.

---

## Phase 4: iOS Native Bridge Updates

**File:** `ios/Classes/UseSenseFlutterPlugin.swift`

### 4.1 Update `initialize()` — remove gatewayKey

Remove `gatewayKey` from `UseSenseConfig` construction (line 47-52). The v4.1 native SDK no longer takes a gateway key since the Cloudflare Worker handles it.

```swift
// BEFORE:
let sdkConfig = UseSenseConfig(
    apiKey: config.apiKey,
    gatewayKey: config.gatewayKey ?? UseSenseConfig.defaultGatewayKey,
    environment: environment,
    branding: brandingConfig
)

// AFTER:
let sdkConfig = UseSenseConfig(
    apiKey: config.apiKey,
    environment: environment,
    branding: brandingConfig
)
```

### 4.2 Add `startVerificationWithToken()` implementation

```swift
func startVerificationWithToken(
    request: PigeonTokenExchangeRequest,
    completion: @escaping (Result<PigeonUseSenseResult, Error>) -> Void
) {
    guard let client = client else {
        completion(.failure(PigeonError(
            code: "sdk_not_initialized",
            message: "UseSense SDK is not initialized. Call initialize() first.",
            details: nil
        )))
        return
    }

    guard let rootVC = UIApplication.shared.delegate?.window??.rootViewController else {
        completion(.failure(PigeonError(
            code: "sdk_not_initialized",
            message: "Root view controller is not available.",
            details: nil
        )))
        return
    }

    // Exchange client token and start verification in one call.
    // The native SDK handles token exchange -> session creation -> camera UI.
    let session = client.startVerificationWithToken(clientToken: request.clientToken)

    let vc = UseSenseViewController(session: session) { [weak self] result in
        DispatchQueue.main.async {
            rootVC.dismiss(animated: true)
            switch result {
            case .success(let decision):
                completion(.success(self?.mapDecisionToPigeon(decision) ?? ...))
            case .failure(let error):
                if error.code == .userCancelled {
                    self?.flutterApi?.onCancelled { _ in }
                    completion(.failure(PigeonError(
                        code: "session_cancelled",
                        message: "User cancelled the verification session.",
                        details: nil
                    )))
                } else {
                    completion(.failure(self?.mapError(error) ?? PigeonError(
                        code: "sdk_error",
                        message: error.localizedDescription,
                        details: nil
                    )))
                }
            }
        }
    }

    vc.modalPresentationStyle = .fullScreen
    rootVC.present(vc, animated: true)
}
```

### 4.3 Update result mapping for v4.1 fields

Update `PigeonUseSenseResult` construction to include pillar scores:

```swift
let pigeonResult = PigeonUseSenseResult(
    sessionId: decision.sessionId,
    sessionType: decision.sessionType,
    identityId: decision.identityId,
    decision: decision.decision,
    timestamp: decision.timestamp,
    channelTrustScore: decision.channelTrustScore.map { Int64($0) },
    livenessScore: decision.livenessScore.map { Int64($0) },
    dedupeRiskScore: decision.dedupeRiskScore.map { Int64($0) },
    channelTrustVerdict: decision.pillarVerdicts?.channelTrust,
    livenessVerdict: decision.pillarVerdicts?.liveness,
    dedupeVerdict: decision.pillarVerdicts?.dedupe,
    stepUpTriggered: decision.inlineStepUp?.triggered,
    stepUpPassed: decision.inlineStepUp?.passed
)
```

### 4.4 Add new event type mappings

Update `forwardEvent()` switch to handle new native event types:

```swift
case .stepUpTriggered: pigeonType = .stepUpTriggered
case .stepUpCompleted: pigeonType = .stepUpCompleted
case .faceGuideReady: pigeonType = .faceGuideReady
case .countdownStarted: pigeonType = .countdownStarted
case .geometricCoherenceCompleted: pigeonType = .geometricCoherenceCompleted
```

### 4.5 Add new error code mappings

Update `mapError()` to handle v4.1 error codes:

```swift
case .nonceMismatch: code = "nonce_mismatch"
case .tokenExpired: code = "token_expired"
case .tokenAlreadyUsed: code = "token_already_used"
case .tokenNotFound: code = "token_not_found"
case .insufficientCredits: code = "insufficient_credits"
case .rateLimited: code = "rate_limited"
```

---

## Phase 5: Android Native Bridge Updates

**File:** `android/src/main/kotlin/com/usesense/flutter/UseSenseFlutterPlugin.kt`

### 5.1 Update `initialize()` — remove gatewayKey

Remove `gatewayKey` from `UseSenseConfig` construction (line 103-111):

```kotlin
// BEFORE:
val nativeConfig = UseSenseConfig(
    apiKey = config.apiKey,
    environment = environment,
    baseUrl = config.baseUrl ?: UseSenseConfig.DEFAULT_BASE_URL,
    gatewayKey = config.gatewayKey,
    branding = brandingConfig,
    googleCloudProjectNumber = ...
)

// AFTER:
val nativeConfig = UseSenseConfig(
    apiKey = config.apiKey,
    environment = environment,
    baseUrl = config.baseUrl ?: UseSenseConfig.DEFAULT_BASE_URL,
    branding = brandingConfig,
    googleCloudProjectNumber = ...
)
```

### 5.2 Add `startVerificationWithToken()` implementation

```kotlin
override fun startVerificationWithToken(
    request: PigeonTokenExchangeRequest,
    callback: (Result<PigeonUseSenseResult>) -> Unit,
) {
    val currentActivity = activity
    if (currentActivity == null) {
        callback(Result.failure(FlutterError("sdk_not_initialized",
            "Activity is not available.", null)))
        return
    }
    if (!UseSense.isInitialized) {
        callback(Result.failure(FlutterError("sdk_not_initialized",
            "UseSense SDK is not initialized. Call initialize() first.", null)))
        return
    }

    // Native SDK handles: exchange-token -> session creation -> camera UI
    UseSense.startVerificationWithToken(
        currentActivity,
        request.clientToken,
        object : UseSenseCallback {
            override fun onSuccess(result: UseSenseResult) {
                mainHandler.post {
                    callback(Result.success(mapResultToPigeon(result)))
                }
            }
            override fun onError(error: UseSenseError) {
                mainHandler.post {
                    callback(Result.failure(mapErrorToFlutter(error)))
                }
            }
            override fun onCancelled() {
                mainHandler.post {
                    flutterApi?.onCancelled {}
                    callback(Result.failure(FlutterError("session_cancelled",
                        "User cancelled the verification session.", null)))
                }
            }
        }
    )
}
```

### 5.3 Update result mapping for v4.1 fields

Update `mapResultToPigeon()`:

```kotlin
private fun mapResultToPigeon(result: UseSenseResult): PigeonUseSenseResult {
    return PigeonUseSenseResult(
        sessionId = result.sessionId,
        sessionType = result.sessionType,
        identityId = result.identityId,
        decision = result.decision,
        timestamp = result.timestamp,
        channelTrustScore = result.channelTrustScore?.toLong(),
        livenessScore = result.livenessScore?.toLong(),
        dedupeRiskScore = result.dedupeRiskScore?.toLong(),
        channelTrustVerdict = result.pillarVerdicts?.channelTrust,
        livenessVerdict = result.pillarVerdicts?.liveness,
        dedupeVerdict = result.pillarVerdicts?.dedupe,
        stepUpTriggered = result.inlineStepUp?.triggered,
        stepUpPassed = result.inlineStepUp?.passed,
    )
}
```

### 5.4 Add new event type mappings

Update `mapEventToPigeon()`:

```kotlin
EventType.STEP_UP_TRIGGERED -> PigeonEventType.STEP_UP_TRIGGERED
EventType.STEP_UP_COMPLETED -> PigeonEventType.STEP_UP_COMPLETED
EventType.FACE_GUIDE_READY -> PigeonEventType.FACE_GUIDE_READY
EventType.COUNTDOWN_STARTED -> PigeonEventType.COUNTDOWN_STARTED
EventType.GEOMETRIC_COHERENCE_COMPLETED -> PigeonEventType.GEOMETRIC_COHERENCE_COMPLETED
```

### 5.5 Add new error code mappings

Update `mapErrorToFlutter()`:

```kotlin
UseSenseError.NONCE_MISMATCH -> "nonce_mismatch"
UseSenseError.TOKEN_EXPIRED -> "token_expired"
UseSenseError.TOKEN_ALREADY_USED -> "token_already_used"
UseSenseError.TOKEN_NOT_FOUND -> "token_not_found"
UseSenseError.INSUFFICIENT_CREDITS -> "insufficient_credits"
UseSenseError.RATE_LIMITED -> "rate_limited"
```

---

## Phase 6: Example App Updates

**Files:** `example/lib/`

### 6.1 Update initialization

**File:** `example/lib/main.dart`

Remove any `gatewayKey` from the example config.

### 6.2 Add server-side init demo

**File:** `example/lib/screens/home_screen.dart`

Add a third button: "Verify with Token (Server-Init)" with a text field for `client_token`. Demonstrates:
```dart
final result = await useSense.startVerificationWithToken(clientToken);
```

### 6.3 Update result screen with pillar scores

**File:** `example/lib/screens/result_screen.dart`

Display pillar scores when available:
- Channel Trust: score + verdict
- Liveness: score + verdict
- Dedupe Risk: score + verdict
- Step-up: triggered/passed status

### 6.4 Add new event tile labels

**File:** `example/lib/widgets/event_tile.dart`

Add labels/icons for:
- `stepUpTriggered` -> Shield icon, "Step-up triggered"
- `stepUpCompleted` -> Shield check icon, "Step-up completed"
- `faceGuideReady` -> Face icon, "Face positioned"
- `countdownStarted` -> Timer icon, "Countdown started"
- `geometricCoherenceCompleted` -> 3D icon, "3D analysis complete"

---

## Phase 7: Documentation Updates

### 7.1 Update README.md

- Remove all references to `gatewayKey` and Supabase
- Add server-side init flow documentation
- Update config reference (remove gatewayKey, note baseUrl defaults to api.usesense.ai)
- Add pillar scores section to result handling
- Add new event types to events table
- Add new error codes to errors table
- Update version references to 4.1.0
- Update requirements: Android API 28+

### 7.2 Update INTEGRATION_GUIDE.md

- Add Chapter: Server-Side Init / Token Exchange
- Add Chapter: Understanding Pillar Scores
- Update auth architecture section (Cloudflare Worker proxy)
- Add inline step-up event handling section
- Update webhook section with v4.1 response fields

### 7.3 Update CHANGELOG.md

Add v4.1.0 entry documenting all breaking changes and new features.

---

## Phase 8: Testing

### 8.1 Update unit tests

- Test `startVerificationWithToken()` Pigeon round-trip
- Test new event type mappings
- Test new error code mappings
- Test result type with pillar scores (nullable fields)
- Test config without gatewayKey

### 8.2 Integration testing checklist

- [ ] Initialize with v4.1 native SDKs (no gatewayKey)
- [ ] Standard verification flow works end-to-end
- [ ] Server-side init token exchange flow works
- [ ] All 23 event types forward correctly
- [ ] Pillar scores appear in result
- [ ] Step-up events fire when suspicion is high
- [ ] New error codes surface correctly
- [ ] Session expiry (15 min TTL) handled
- [ ] Android API 28 minimum enforced
- [ ] iOS 16+ works as before

---

## File Change Summary

| File | Action | Changes |
|------|--------|---------|
| `pubspec.yaml` | Edit | Version bump to 4.1.0 |
| `pigeons/usesense_api.dart` | Edit | Add event types, token exchange request, expand result, add host method, remove gatewayKey |
| `lib/src/generated/usesense_api.g.dart` | Regenerate | Auto-generated from Pigeon |
| `lib/src/usesense_types.dart` | Edit | Remove gatewayKey, add event types, expand result |
| `lib/src/usesense_error.dart` | Edit | Add 6 new error codes + codeFromString cases |
| `lib/src/usesense_flutter_plugin.dart` | Edit | Add startVerificationWithToken() |
| `lib/src/usesense_flutter_platform_interface.dart` | Edit | Add startVerificationWithToken() abstract |
| `lib/src/usesense_flutter_method_channel.dart` | Edit | Add startVerificationWithToken(), update mappings |
| `ios/usesense_flutter.podspec` | Edit | Version + dependency bump |
| `ios/Classes/UseSenseApi.g.swift` | Regenerate | Auto-generated from Pigeon |
| `ios/Classes/UseSenseFlutterPlugin.swift` | Edit | Add token flow, update mappings, remove gatewayKey |
| `android/build.gradle.kts` | Edit | Version + dependency bump + minSdk 28 |
| `android/src/main/kotlin/.../UseSenseApi.g.kt` | Regenerate | Auto-generated from Pigeon |
| `android/src/main/kotlin/.../UseSenseFlutterPlugin.kt` | Edit | Add token flow, update mappings, remove gatewayKey |
| `example/lib/main.dart` | Edit | Remove gatewayKey from example |
| `example/lib/screens/home_screen.dart` | Edit | Add token exchange demo |
| `example/lib/screens/result_screen.dart` | Edit | Show pillar scores |
| `example/lib/widgets/event_tile.dart` | Edit | Add new event labels |
| `README.md` | Edit | v4.1 docs update |
| `INTEGRATION_GUIDE.md` | Edit | v4.1 docs update |
| `CHANGELOG.md` | Edit | v4.1.0 changelog entry |

---

## Execution Order

```
1. Dependency & version bumps (Phase 1)
   ↓
2. Pigeon schema changes + regenerate (Phase 2)
   ↓
3. Dart public API updates (Phase 3)  ←──── can parallel with 4+5
   ↓
4. iOS native bridge updates (Phase 4) ←── depends on Pigeon regen
   ↓
5. Android native bridge updates (Phase 5) ←── depends on Pigeon regen
   ↓
6. Example app updates (Phase 6) ←── depends on Dart API
   ↓
7. Documentation (Phase 7) ←── can parallel with 6
   ↓
8. Testing (Phase 8)
```

Phases 3, 4, 5 can run in parallel after Phase 2 completes.
Phases 6 and 7 can run in parallel.

---

## What the Native SDKs Handle (NOT in scope for Flutter plugin)

These v4.1 features are implemented entirely inside the native SDKs and require NO Flutter plugin changes beyond version bumps:

- **Cloudflare Worker auth proxy** — native SDK sends `x-api-key` only, no Supabase headers
- **Nonce dual-delivery** — native SDK sends `x-nonce` header + `?nonce=` query param
- **Camera capture params** — native SDK reads `upload.max_frames` (30), `upload.target_fps` (2-5), `upload.capture_duration_ms` (up to 8000)
- **Face guide phase** — native SDK UI shows oval overlay with 8-frame auto-advance
- **Countdown phase** — native SDK UI shows 3-2-1 animation
- **Frame hashing** — native SDK computes SHA-256 per JPEG frame
- **Challenge system** — native SDK executes follow_dot, head_turn, speak_phrase
- **MediaPipe FaceMesh** — native SDK runs 468-landmark face detection
- **On-device 3DMM fitting** — native SDK fits PCA shape model to landmarks
- **Cryptographic binding** — native SDK computes HMAC-SHA256 binding proofs per frame
- **Verification package** — native SDK builds and uploads the full package
- **Suspicion Engine** — native SDK runs 4-signal rolling analysis during capture
- **Flash Reflection** — native SDK runs 3-color flash challenge with RGB sampling
- **RMAS** — native SDK runs randomized micro-action sequence
- **Inline step-up orchestrator** — native SDK handles threshold, selection, timeout
- **Screen detection signals** — native SDK computes luminance/edge/color signals
- **Signal collection** — native SDK collects all iOS/Android platform signals
- **Metadata assembly** — native SDK builds the complete JSON per Chapter 8
- **Upload protocol** — native SDK sends multipart frames + metadata + audio
- **Retry strategy** — native SDK implements exponential backoff per Chapter 1.7
- **Verdict parsing** — native SDK parses full decision response per Chapter 9

---

## Breaking Changes for Integrators

1. **`gatewayKey` removed** from `UseSenseConfig` — no longer needed with Cloudflare proxy
2. **Android minSdk raised** from 24 to 28
3. **New nullable fields** on `UseSenseResult` — existing code unaffected (all nullable)
4. **New event types** — existing `onEvent` listeners see unknown types as additional enum values
5. **New error codes** — existing error handling still works (falls through to default)
