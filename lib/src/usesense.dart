import 'dart:async';
import 'package:flutter/services.dart';
import 'types.dart';

/// Main entry point for the UseSense Flutter plugin.
///
/// ```dart
/// // Initialize
/// await UseSense.initialize(UseSenseConfig(apiKey: 'your_key'));
///
/// // Start verification
/// final result = await UseSense.startVerification(
///   VerificationRequest(sessionType: SessionType.enrollment),
/// );
/// ```
class UseSense {
  static const MethodChannel _method = MethodChannel('com.usesense/method');
  static const EventChannel _events = EventChannel('com.usesense/events');

  static Stream<UseSenseEvent>? _eventStream;

  UseSense._();

  /// Initialize the SDK. Must be called before [startVerification].
  static Future<void> initialize(UseSenseConfig config) async {
    await _method.invokeMethod('initialize', config.toMap());
  }

  /// Launch the verification flow.
  ///
  /// Returns a [UseSenseResult] on success.
  /// Throws [UseSenseError] on failure or [UseSenseCancelledException]
  /// if the user cancels.
  static Future<UseSenseResult> startVerification(
    VerificationRequest request,
  ) async {
    try {
      final result = await _method.invokeMethod<Map>(
        'startVerification',
        request.toMap(),
      );
      if (result == null) {
        throw const UseSenseError(code: 0, message: 'Null result from SDK');
      }
      return UseSenseResult.fromMap(result);
    } on PlatformException catch (e) {
      if (e.code == 'CANCELLED') {
        throw UseSenseCancelledException();
      }
      throw UseSenseError.fromDetails(
        e.details is Map ? e.details as Map<dynamic, dynamic> : null,
      );
    }
  }

  /// Stream of SDK lifecycle events.
  ///
  /// ```dart
  /// UseSense.events.listen((event) {
  ///   print('${event.type}: ${event.data}');
  /// });
  /// ```
  static Stream<UseSenseEvent> get events {
    _eventStream ??= _events
        .receiveBroadcastStream()
        .map((dynamic event) => UseSenseEvent.fromMap(event as Map));
    return _eventStream!;
  }

  /// Check if the SDK has been initialized.
  static Future<bool> isInitialized() async {
    final result = await _method.invokeMethod<bool>('isInitialized');
    return result ?? false;
  }

  /// Reset the SDK state.
  static Future<void> reset() async {
    await _method.invokeMethod('reset');
  }
}
