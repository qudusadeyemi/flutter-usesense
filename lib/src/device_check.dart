/// Headless silent device check for "Your KYC".
///
/// Keep your own KYC provider's SDK and run this next to it. No UI, no camera
/// and no permission prompt. Sense scores the device and links the result to
/// your provider's result when it reaches your Your KYC connection.
///
/// ```dart
/// // Your server: POST /v1/device-checks with your API key (never ship the key)
/// // and "platform": "android" or "ios"; pass the three values to the app.
/// final check = UseSenseDeviceCheck(
///   deviceCheckId: created.deviceCheckId,
///   token: created.token,
///   nonce: created.nonce,
/// );
/// final started = await check.start(); // before your provider's SDK opens
/// if (!started.ok) debugPrint('device check start: ${started.error!.code}');
/// await provider.start(metadata: {'device_check_id': created.deviceCheckId});
/// await check.finish(); // after it closes
/// check.dispose();
/// ```
///
/// [start] and [finish] never throw: they resolve to a [DeviceCheckResult].
/// The device is never told the score; read it on your server with
/// `GET /v1/device-checks/:id`.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

/// Which call a [DeviceCheckResult] answers.
enum DeviceCheckPhase {
  start,
  finish;

  static DeviceCheckPhase fromWire(String? wire, DeviceCheckPhase fallback) {
    switch (wire) {
      case 'start':
        return DeviceCheckPhase.start;
      case 'finish':
        return DeviceCheckPhase.finish;
    }
    return fallback;
  }
}

/// One error taxonomy on both platforms. The native SDKs name a few codes
/// differently (iOS `token_invalid`, Android `service_unavailable`); they are
/// normalised here so an app handles one set.
enum DeviceCheckErrorCode {
  /// 401: wrong token. Create a new check on your server.
  invalidToken,

  /// 401: more than 15 minutes after the check was created. Create a new one.
  tokenExpired,

  /// 400: the nonce does not belong to this check.
  nonceMismatch,

  /// 400: the request body was refused.
  invalidInput,

  /// 409: start once, then finish once, in that order.
  outOfOrder,

  /// 404: unknown device check id.
  notFound,

  /// 503 after the SDK's own retry.
  unavailable,

  /// No connection, after the SDK's own retry.
  networkError,

  /// No response in time, after the SDK's own retry.
  timeout,

  /// deviceCheckId, token or nonce is empty or malformed; nothing was sent.
  invalidConfig,

  /// The check was cancelled or disposed while a call was in flight.
  cancelled,
  unknown;

  static DeviceCheckErrorCode fromWire(String? wire) {
    switch (wire) {
      case 'invalid_token':
      case 'token_invalid':
        return DeviceCheckErrorCode.invalidToken;
      case 'token_expired':
        return DeviceCheckErrorCode.tokenExpired;
      case 'nonce_mismatch':
        return DeviceCheckErrorCode.nonceMismatch;
      case 'invalid_input':
      case 'invalid_request':
      case 'invalid_phase':
        return DeviceCheckErrorCode.invalidInput;
      case 'out_of_order':
      case 'already_started':
      case 'not_started':
      case 'already_finished':
        return DeviceCheckErrorCode.outOfOrder;
      case 'not_found':
        return DeviceCheckErrorCode.notFound;
      case 'unavailable':
      case 'service_unavailable':
      case 'scoring_failed':
        return DeviceCheckErrorCode.unavailable;
      case 'network_error':
      case 'network_unavailable':
        return DeviceCheckErrorCode.networkError;
      case 'timeout':
        return DeviceCheckErrorCode.timeout;
      case 'invalid_config':
        return DeviceCheckErrorCode.invalidConfig;
      case 'cancelled':
        return DeviceCheckErrorCode.cancelled;
    }
    return DeviceCheckErrorCode.unknown;
  }
}

/// Why a device check call did not go through.
class DeviceCheckError {
  const DeviceCheckError({
    required this.code,
    required this.message,
    this.retryable = false,
    this.serverCode,
    this.httpStatus,
  });

  final DeviceCheckErrorCode code;
  final String message;

  /// True when calling again may succeed (unavailable, network, timeout).
  final bool retryable;

  /// The server's own `code`, when the server answered.
  final String? serverCode;
  final int? httpStatus;

  factory DeviceCheckError.fromMap(Map<dynamic, dynamic> map) {
    final code = DeviceCheckErrorCode.fromWire(map['code'] as String?);
    return DeviceCheckError(
      code: code,
      message: (map['message'] as String?) ?? 'Device check failed',
      retryable: (map['retryable'] as bool?) ??
          (code == DeviceCheckErrorCode.unavailable ||
              code == DeviceCheckErrorCode.networkError ||
              code == DeviceCheckErrorCode.timeout),
      serverCode: map['serverCode'] as String?,
      httpStatus: (map['httpStatus'] as num?)?.toInt(),
    );
  }

  @override
  String toString() => 'DeviceCheckError(${code.name}): $message';
}

/// The outcome of [UseSenseDeviceCheck.start] or [UseSenseDeviceCheck.finish].
class DeviceCheckResult {
  const DeviceCheckResult._({required this.phase, this.error});

  /// The signals were received by Sense (HTTP 202).
  const DeviceCheckResult.received(DeviceCheckPhase phase)
      : this._(phase: phase);

  /// The call did not go through; see [error].
  const DeviceCheckResult.failed(DeviceCheckPhase phase, DeviceCheckError error)
      : this._(phase: phase, error: error);

  final DeviceCheckPhase phase;
  final DeviceCheckError? error;

  bool get ok => error == null;

  factory DeviceCheckResult.fromMap(
    Map<dynamic, dynamic> map,
    DeviceCheckPhase called,
  ) {
    final phase = DeviceCheckPhase.fromWire(map['phase'] as String?, called);
    if (map['ok'] == true) return DeviceCheckResult.received(phase);
    final err = map['error'];
    return DeviceCheckResult.failed(
      phase,
      err is Map
          ? DeviceCheckError.fromMap(err)
          : const DeviceCheckError(
              code: DeviceCheckErrorCode.unknown,
              message: 'Device check failed',
            ),
    );
  }

  @override
  String toString() => ok
      ? 'DeviceCheckResult.received(${phase.name})'
      : 'DeviceCheckResult.failed(${phase.name}, $error)';
}

/// A headless silent device check. Create one per `POST /v1/device-checks`.
class UseSenseDeviceCheck {
  UseSenseDeviceCheck({
    required this.deviceCheckId,
    required String token,
    required String nonce,
    this.apiBaseUrl,
    this.timeout,
  })  : _token = token,
        _nonce = nonce,
        _channel = _defaultChannel,
        _handle = _nextHandle();

  /// Construct with an injected [MethodChannel]. For testing only.
  @visibleForTesting
  UseSenseDeviceCheck.forTesting(
    MethodChannel channel, {
    required this.deviceCheckId,
    required String token,
    required String nonce,
    this.apiBaseUrl,
    this.timeout,
  })  : _token = token,
        _nonce = nonce,
        _channel = channel,
        _handle = _nextHandle();

  static const MethodChannel _defaultChannel =
      MethodChannel('com.usesense.flutter/device_check');
  static int _counter = 0;
  static String _nextHandle() =>
      'dc${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  /// The `deviceCheckId` your server got from `POST /v1/device-checks`.
  final String deviceCheckId;

  /// Defaults to `https://api.usesense.ai` (or the base URL the native SDK was
  /// initialised with on Android).
  final String? apiBaseUrl;

  /// Per-request timeout. Defaults to the native SDK's own.
  final Duration? timeout;

  final String _token;
  final String _nonce;
  final MethodChannel _channel;
  final String _handle;
  bool _disposed = false;

  /// Send the integrity signals. Call before your provider's SDK opens.
  Future<DeviceCheckResult> start() => _call(DeviceCheckPhase.start);

  /// Send the closing signals. Call after your provider's SDK closes.
  Future<DeviceCheckResult> finish() => _call(DeviceCheckPhase.finish);

  /// Release the native check. Calls after this resolve as cancelled.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _channel.invokeMethod<void>('dispose', {'handle': _handle});
    } on PlatformException {
      // Nothing to release.
    } on MissingPluginException {
      // Platform without the native plugin.
    }
  }

  Future<DeviceCheckResult> _call(DeviceCheckPhase phase) async {
    if (_disposed) {
      return DeviceCheckResult.failed(
        phase,
        const DeviceCheckError(
          code: DeviceCheckErrorCode.cancelled,
          message: 'This device check was disposed',
        ),
      );
    }
    try {
      final map = await _channel.invokeMapMethod<dynamic, dynamic>(
        phase.name,
        <String, dynamic>{
          'handle': _handle,
          'deviceCheckId': deviceCheckId,
          'token': _token,
          'nonce': _nonce,
          if (apiBaseUrl != null) 'apiBaseUrl': apiBaseUrl,
          if (timeout != null) 'timeoutMs': timeout!.inMilliseconds,
        },
      );
      if (map == null) {
        return DeviceCheckResult.failed(
          phase,
          const DeviceCheckError(
            code: DeviceCheckErrorCode.unknown,
            message: 'Empty result from the native device check',
          ),
        );
      }
      return DeviceCheckResult.fromMap(map, phase);
    } on PlatformException catch (e) {
      return DeviceCheckResult.failed(
        phase,
        DeviceCheckError(
          code: DeviceCheckErrorCode.fromWire(e.code),
          message: e.message ?? 'Device check failed',
        ),
      );
    } on MissingPluginException {
      return DeviceCheckResult.failed(
        phase,
        const DeviceCheckError(
          code: DeviceCheckErrorCode.unknown,
          message: 'The device check is not available on this platform',
        ),
      );
    }
  }
}
