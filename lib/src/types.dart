/// Environment for the UseSense SDK.
enum UseSenseEnvironment {
  sandbox,
  production,
  auto;

  String get value => name;
}

/// Type of verification session.
enum SessionType {
  enrollment,
  authentication;

  String get value => name;
}

/// Branding configuration for the verification UI.
class BrandingConfig {
  final String? logoUrl;
  final String primaryColor;
  final int buttonRadius;
  final String? fontFamily;

  const BrandingConfig({
    this.logoUrl,
    this.primaryColor = '#4F63F5',
    this.buttonRadius = 12,
    this.fontFamily,
  });

  Map<String, dynamic> toMap() => {
        if (logoUrl != null) 'logoUrl': logoUrl,
        'primaryColor': primaryColor,
        'buttonRadius': buttonRadius,
        if (fontFamily != null) 'fontFamily': fontFamily,
      };
}

/// SDK configuration.
class UseSenseConfig {
  final String apiKey;
  final UseSenseEnvironment environment;
  final String? baseUrl;
  final String? gatewayKey;
  final BrandingConfig? branding;
  final int? googleCloudProjectNumber;

  const UseSenseConfig({
    required this.apiKey,
    this.environment = UseSenseEnvironment.auto,
    this.baseUrl,
    this.gatewayKey,
    this.branding,
    this.googleCloudProjectNumber,
  });

  Map<String, dynamic> toMap() => {
        'apiKey': apiKey,
        'environment': environment.value,
        if (baseUrl != null) 'baseUrl': baseUrl,
        if (gatewayKey != null) 'gatewayKey': gatewayKey,
        if (branding != null) 'branding': branding!.toMap(),
        if (googleCloudProjectNumber != null)
          'googleCloudProjectNumber': googleCloudProjectNumber,
      };
}

/// Verification request parameters.
class VerificationRequest {
  final SessionType sessionType;
  final String? externalUserId;
  final String? identityId;
  final Map<String, dynamic>? metadata;

  const VerificationRequest({
    required this.sessionType,
    this.externalUserId,
    this.identityId,
    this.metadata,
  });

  Map<String, dynamic> toMap() => {
        'sessionType': sessionType.value,
        if (externalUserId != null) 'externalUserId': externalUserId,
        if (identityId != null) 'identityId': identityId,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Result of a successful verification.
class UseSenseResult {
  final String sessionId;
  final String? sessionType;
  final String? identityId;
  final String decision;
  final String timestamp;
  final bool isApproved;
  final bool isRejected;
  final bool isPendingReview;

  const UseSenseResult({
    required this.sessionId,
    this.sessionType,
    this.identityId,
    required this.decision,
    required this.timestamp,
    required this.isApproved,
    required this.isRejected,
    required this.isPendingReview,
  });

  factory UseSenseResult.fromMap(Map<dynamic, dynamic> map) {
    return UseSenseResult(
      sessionId: map['sessionId'] as String,
      sessionType: map['sessionType'] as String?,
      identityId: map['identityId'] as String?,
      decision: map['decision'] as String,
      timestamp: map['timestamp'] as String,
      isApproved: map['isApproved'] as bool? ?? false,
      isRejected: map['isRejected'] as bool? ?? false,
      isPendingReview: map['isPendingReview'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'UseSenseResult(sessionId: $sessionId, decision: $decision)';
}

/// Error from the UseSense SDK.
class UseSenseError implements Exception {
  final int code;
  final String? serverCode;
  final String message;
  final bool isRetryable;

  const UseSenseError({
    required this.code,
    this.serverCode,
    required this.message,
    this.isRetryable = false,
  });

  factory UseSenseError.fromDetails(Map<dynamic, dynamic>? details) {
    return UseSenseError(
      code: (details?['code'] as int?) ?? 0,
      serverCode: details?['serverCode'] as String?,
      message: (details?['message'] as String?) ?? 'Unknown error',
      isRetryable: (details?['isRetryable'] as bool?) ?? false,
    );
  }

  @override
  String toString() => 'UseSenseError($code: $message)';
}

/// Verification was cancelled by the user.
class UseSenseCancelledException implements Exception {
  @override
  String toString() => 'UseSenseCancelledException: User cancelled verification';
}

/// SDK lifecycle event types.
enum UseSenseEventType {
  sessionCreated,
  permissionsRequested,
  permissionsGranted,
  permissionsDenied,
  captureStarted,
  frameCaptured,
  captureCompleted,
  audioRecordStarted,
  audioRecordCompleted,
  challengeStarted,
  challengeCompleted,
  uploadStarted,
  uploadProgress,
  uploadCompleted,
  completeStarted,
  decisionReceived,
  imageQualityCheck,
  error,
  unknown;

  static UseSenseEventType fromString(String value) {
    const mapping = {
      'SESSION_CREATED': UseSenseEventType.sessionCreated,
      'PERMISSIONS_REQUESTED': UseSenseEventType.permissionsRequested,
      'PERMISSIONS_GRANTED': UseSenseEventType.permissionsGranted,
      'PERMISSIONS_DENIED': UseSenseEventType.permissionsDenied,
      'CAPTURE_STARTED': UseSenseEventType.captureStarted,
      'FRAME_CAPTURED': UseSenseEventType.frameCaptured,
      'CAPTURE_COMPLETED': UseSenseEventType.captureCompleted,
      'AUDIO_RECORD_STARTED': UseSenseEventType.audioRecordStarted,
      'AUDIO_RECORD_COMPLETED': UseSenseEventType.audioRecordCompleted,
      'CHALLENGE_STARTED': UseSenseEventType.challengeStarted,
      'CHALLENGE_COMPLETED': UseSenseEventType.challengeCompleted,
      'UPLOAD_STARTED': UseSenseEventType.uploadStarted,
      'UPLOAD_PROGRESS': UseSenseEventType.uploadProgress,
      'UPLOAD_COMPLETED': UseSenseEventType.uploadCompleted,
      'COMPLETE_STARTED': UseSenseEventType.completeStarted,
      'DECISION_RECEIVED': UseSenseEventType.decisionReceived,
      'IMAGE_QUALITY_CHECK': UseSenseEventType.imageQualityCheck,
      'ERROR': UseSenseEventType.error,
    };
    return mapping[value] ?? UseSenseEventType.unknown;
  }
}

/// An event emitted during the verification lifecycle.
class UseSenseEvent {
  final UseSenseEventType type;
  final int timestamp;
  final Map<String, dynamic>? data;

  const UseSenseEvent({
    required this.type,
    required this.timestamp,
    this.data,
  });

  factory UseSenseEvent.fromMap(Map<dynamic, dynamic> map) {
    return UseSenseEvent(
      type: UseSenseEventType.fromString(map['type'] as String? ?? ''),
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      data: (map['data'] as Map?)?.cast<String, dynamic>(),
    );
  }
}
