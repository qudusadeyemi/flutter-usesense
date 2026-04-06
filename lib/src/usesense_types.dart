/// Public types for the UseSense Flutter plugin.
///
/// These types provide a clean, idiomatic Dart API on top of the
/// Pigeon-generated message classes.
library;

/// The target environment for the UseSense backend.
enum UseSenseEnvironment {
  /// Sandbox environment for testing.
  sandbox,

  /// Production environment.
  production,

  /// Auto-detect from the API key prefix.
  auto,
}

/// The type of verification session.
enum SessionType {
  /// Enroll a new identity.
  enrollment,

  /// Authenticate an existing identity.
  authentication,
}

/// Branding configuration for the SDK's camera UI.
class BrandingConfig {
  /// Creates a [BrandingConfig].
  const BrandingConfig({
    this.displayName,
    this.logoUrl,
    this.primaryColor,
    this.redirectUrl,
    this.buttonRadius = 12,
    this.fontFamily,
  });

  /// Display name shown in the UI. Null inherits from organization settings.
  final String? displayName;

  /// URL of the logo shown in the UI. Null inherits from organization settings.
  final String? logoUrl;

  /// Primary color hex string (e.g. `#4F7CFF`). Null inherits from
  /// organization settings.
  final String? primaryColor;

  /// URL to redirect to after session completion. Null inherits from
  /// organization settings.
  final String? redirectUrl;

  /// Corner radius for buttons in dp. Defaults to 12.
  final int buttonRadius;

  /// Custom font family name. Null uses the system default.
  final String? fontFamily;
}

/// Configuration for the UseSense SDK.
class UseSenseConfig {
  /// Creates a [UseSenseConfig].
  ///
  /// [apiKey] is required. All other fields have sensible defaults.
  const UseSenseConfig({
    required this.apiKey,
    this.environment = UseSenseEnvironment.auto,
    this.baseUrl,
    this.branding,
    this.googleCloudProjectNumber,
  });

  /// Your UseSense API key (`pk_prod_*`, `pk_sandbox_*`, etc.).
  final String apiKey;

  /// The backend environment. Defaults to [UseSenseEnvironment.auto].
  final UseSenseEnvironment environment;

  /// Override the default backend URL. Null uses the SDK default
  /// (`https://api.usesense.ai/v1`).
  final String? baseUrl;

  /// Optional UI branding overrides.
  final BrandingConfig? branding;

  /// Google Cloud project number for Play Integrity attestation (Android only).
  final int? googleCloudProjectNumber;
}

/// A request to start a verification session.
class VerificationRequest {
  /// Creates a [VerificationRequest].
  const VerificationRequest({
    required this.sessionType,
    this.externalUserId,
    this.identityId,
    this.metadata,
  });

  /// The type of session to start.
  final SessionType sessionType;

  /// Your internal user identifier. Optional.
  final String? externalUserId;

  /// The identity ID to authenticate against. Required for
  /// [SessionType.authentication].
  final String? identityId;

  /// Arbitrary key-value metadata attached to the session.
  final Map<String, String>? metadata;
}

/// The outcome of a completed verification session.
class UseSenseResult {
  /// Creates a [UseSenseResult].
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

  /// Unique session identifier.
  final String sessionId;

  /// The session type (`enrollment` or `authentication`).
  final String? sessionType;

  /// The identity ID assigned during enrollment, or verified during
  /// authentication.
  final String? identityId;

  /// The verification decision: `APPROVE`, `REJECT`, or `MANUAL_REVIEW`.
  final String decision;

  /// ISO 8601 timestamp of the decision.
  final String timestamp;

  /// DeepSense channel trust score (0-100). Null if not available.
  final int? channelTrustScore;

  /// LiveSense liveness score (0-100). Null if not available.
  final int? livenessScore;

  /// MatchSense deduplication risk score (0-100). Null if not available.
  final int? dedupeRiskScore;

  /// Channel trust pillar verdict: `PASS`, `FAIL`, or `REVIEW`.
  final String? channelTrustVerdict;

  /// Liveness pillar verdict: `PASS`, `FAIL`, or `REVIEW`.
  final String? livenessVerdict;

  /// Dedupe pillar verdict: `PASS`, `FAIL`, or `REVIEW`.
  final String? dedupeVerdict;

  /// Whether the inline step-up was triggered during this session.
  final bool? stepUpTriggered;

  /// Whether the inline step-up challenge was passed. Null if not triggered.
  final bool? stepUpPassed;

  /// Whether the decision is `APPROVE`.
  bool get isApproved => decision == 'APPROVE';

  /// Whether the decision is `REJECT`.
  bool get isRejected => decision == 'REJECT';

  /// Whether the decision is `MANUAL_REVIEW`.
  bool get isPendingReview => decision == 'MANUAL_REVIEW';

  @override
  String toString() =>
      'UseSenseResult(sessionId: $sessionId, decision: $decision)';
}

/// Event types emitted by the native SDK during a verification session.
enum UseSenseEventType {
  /// Session created on the server.
  sessionCreated,

  /// Device permissions requested.
  permissionsRequested,

  /// Device permissions granted.
  permissionsGranted,

  /// Device permissions denied by the user.
  permissionsDenied,

  /// Frame capture started.
  captureStarted,

  /// A single frame was captured.
  frameCaptured,

  /// All frames captured.
  captureCompleted,

  /// Audio recording started.
  audioRecordStarted,

  /// Audio recording finished.
  audioRecordCompleted,

  /// Challenge phase started.
  challengeStarted,

  /// Challenge phase finished.
  challengeCompleted,

  /// Upload started.
  uploadStarted,

  /// Upload progress update.
  uploadProgress,

  /// Upload finished.
  uploadCompleted,

  /// Server evaluation started.
  completeStarted,

  /// Verdict received from server.
  decisionReceived,

  /// Image quality analysis result.
  imageQualityCheck,

  /// An error occurred.
  error,

  /// Suspicion engine triggered inline step-up.
  stepUpTriggered,

  /// Inline step-up challenge finished.
  stepUpCompleted,

  /// Face positioned correctly in oval guide.
  faceGuideReady,

  /// 3-2-1 countdown began.
  countdownStarted,

  /// 3D geometric coherence analysis completed.
  geometricCoherenceCompleted,
}

/// An event emitted by the native SDK during a verification session.
class UseSenseEvent {
  /// Creates a [UseSenseEvent].
  const UseSenseEvent({
    required this.type,
    required this.timestamp,
    this.data,
  });

  /// The event type.
  final UseSenseEventType type;

  /// Millisecond timestamp of the event.
  final int timestamp;

  /// Optional event payload.
  final Map<String, Object?>? data;

  @override
  String toString() => 'UseSenseEvent(type: $type, timestamp: $timestamp)';
}
