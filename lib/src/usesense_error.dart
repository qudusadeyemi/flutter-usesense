/// Error types for the UseSense Flutter plugin.
library;

/// An error from the UseSense SDK.
///
/// Wraps native SDK errors with structured codes, human-readable messages,
/// and retry guidance.
class UseSenseError implements Exception {
  /// Creates a [UseSenseError].
  const UseSenseError({
    required this.code,
    required this.message,
    this.serverCode,
    this.isRetryable = false,
    this.details,
  });

  /// Creates a [UseSenseError] from a [PlatformException].
  factory UseSenseError.fromPlatformException(Object exception) {
    if (exception is UseSenseError) return exception;
    return UseSenseError(
      code: codeFromString(exception.toString()),
      message: exception.toString(),
    );
  }

  // -- Error codes matching the native SDK --

  /// Camera hardware unavailable.
  static const int cameraUnavailable = 1001;

  /// Camera permission denied by the user.
  static const int cameraPermissionDenied = 1002;

  /// Microphone permission denied by the user.
  static const int microphonePermissionDenied = 1003;

  /// Network communication error.
  static const int networkError = 2001;

  /// Network request timed out.
  static const int networkTimeout = 2002;

  /// Rate limited by the server (429).
  static const int rateLimited = 2003;

  /// Session has expired.
  static const int sessionExpired = 3001;

  /// Frame/data upload failed.
  static const int uploadFailed = 3002;

  /// Nonce validation failed.
  static const int nonceMismatch = 3003;

  /// Client token has expired (past 10-minute TTL).
  static const int tokenExpired = 3004;

  /// Client token was already exchanged.
  static const int tokenAlreadyUsed = 3005;

  /// Client token is invalid or does not exist.
  static const int tokenNotFound = 3006;

  /// Frame capture failed.
  static const int captureFailed = 4001;

  /// Frame encoding failed.
  static const int encodingFailed = 4002;

  /// Invalid SDK configuration.
  static const int invalidConfig = 5001;

  /// Organization quota exceeded.
  static const int quotaExceeded = 6001;

  /// Organization out of verification credits.
  static const int insufficientCredits = 6002;

  /// SDK not initialized.
  static const int sdkNotInitialized = 7001;

  /// Session was cancelled by the user.
  static const int sessionCancelled = 8001;

  /// Numeric error code.
  final int code;

  /// Server-specific error code, if available.
  final String? serverCode;

  /// Human-readable error description.
  final String message;

  /// Whether the operation can be retried.
  final bool isRetryable;

  /// Additional error details.
  final Map<String, String>? details;

  /// Converts a string error code from the native platform to a numeric code.
  static int codeFromString(String code) {
    switch (code) {
      case 'camera_unavailable':
        return cameraUnavailable;
      case 'camera_permission_denied':
        return cameraPermissionDenied;
      case 'microphone_permission_denied':
        return microphonePermissionDenied;
      case 'network_error':
        return networkError;
      case 'network_timeout':
        return networkTimeout;
      case 'rate_limited':
        return rateLimited;
      case 'session_expired':
        return sessionExpired;
      case 'upload_failed':
        return uploadFailed;
      case 'nonce_mismatch':
        return nonceMismatch;
      case 'token_expired':
        return tokenExpired;
      case 'token_already_used':
        return tokenAlreadyUsed;
      case 'token_not_found':
        return tokenNotFound;
      case 'capture_failed':
        return captureFailed;
      case 'encoding_failed':
        return encodingFailed;
      case 'invalid_config':
        return invalidConfig;
      case 'quota_exceeded':
        return quotaExceeded;
      case 'insufficient_credits':
        return insufficientCredits;
      case 'sdk_not_initialized':
        return sdkNotInitialized;
      case 'session_cancelled':
        return sessionCancelled;
      default:
        return -1;
    }
  }

  @override
  String toString() =>
      'UseSenseError(code: $code, message: $message, retryable: $isRetryable)';
}
