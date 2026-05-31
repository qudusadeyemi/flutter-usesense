/// Flutter wrapper for the UseSense Flows runner.
///
/// Coexists with the existing Sessions API ([UseSenseFlutter.startVerification],
/// etc.); this is a parallel surface, not a replacement. See
/// `guides/flows/sessions-vs-flows` in the API docs for when to use which.
///
/// Usage:
///
/// ```dart
/// final result = await UseSenseFlows.instance.runFlow(
///   flowRunId: id,
///   sdkToken: token,
/// );
/// if (result.outcome == FlowOutcome.approve) { ... }
/// ```
library;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

/// Server-driven flow run state. Host apps see only the terminal ones via
/// [FlowRunResult].
enum FlowRunState {
  pending,
  inProgress,
  stalled,
  awaitingReview,
  completed,
  errored,
  abandoned,
  cancelled;

  static FlowRunState fromWire(String? wire) {
    switch (wire) {
      case 'pending':
        return FlowRunState.pending;
      case 'in_progress':
        return FlowRunState.inProgress;
      case 'stalled':
        return FlowRunState.stalled;
      case 'awaiting_review':
        return FlowRunState.awaitingReview;
      case 'completed':
        return FlowRunState.completed;
      case 'errored':
        return FlowRunState.errored;
      case 'abandoned':
        return FlowRunState.abandoned;
      case 'cancelled':
        return FlowRunState.cancelled;
    }
    return FlowRunState.pending;
  }
}

/// Terminal outcome of a flow run.
enum FlowOutcome {
  approve,
  reject,
  manualReview;

  static FlowOutcome? fromWire(String? wire) {
    switch (wire) {
      case 'APPROVE':
        return FlowOutcome.approve;
      case 'REJECT':
        return FlowOutcome.reject;
      case 'MANUAL_REVIEW':
        return FlowOutcome.manualReview;
    }
    return null;
  }
}

/// Result returned to the host app's `runFlow` future on success or cancel.
class FlowRunResult {
  const FlowRunResult({
    required this.flowRunId,
    required this.state,
    this.outcome,
  });

  final String flowRunId;
  final FlowRunState state;
  final FlowOutcome? outcome;

  factory FlowRunResult.fromMap(Map<dynamic, dynamic> map) => FlowRunResult(
        flowRunId: map['flowRunId'] as String,
        state: FlowRunState.fromWire(map['state'] as String?),
        outcome: FlowOutcome.fromWire(map['outcome'] as String?),
      );
}

/// Uniform error taxonomy across every SDK. See `guides/flows/errors`
/// in the API docs for per-code recovery patterns.
enum FlowErrorCode {
  tokenExpired,
  tokenInvalid,
  networkUnavailable,
  permissionDenied,
  providerUnavailable,
  cancelled,
  unsupportedAction,

  /// Server form validation failed. The native runner handles this inline
  /// (per-field highlights) and never reports terminal — but if a host app
  /// drives advance() outside the runner, the 422 surfaces with this code.
  invalidInput,
  unknown;

  static FlowErrorCode fromWire(String? wire) {
    switch (wire) {
      case 'token_expired':
        return FlowErrorCode.tokenExpired;
      case 'token_invalid':
        return FlowErrorCode.tokenInvalid;
      case 'network_unavailable':
        return FlowErrorCode.networkUnavailable;
      case 'permission_denied':
        return FlowErrorCode.permissionDenied;
      case 'provider_unavailable':
        return FlowErrorCode.providerUnavailable;
      case 'cancelled':
        return FlowErrorCode.cancelled;
      case 'unsupported_action':
        return FlowErrorCode.unsupportedAction;
      case 'invalid_input':
        return FlowErrorCode.invalidInput;
    }
    return FlowErrorCode.unknown;
  }
}

/// Thrown from `runFlow` when the native runner reports a failure. The
/// [code] mirrors the web / iOS / Android SDKs so host apps catch one taxonomy
/// regardless of platform.
class FlowError implements Exception {
  FlowError(this.code, this.message);
  final FlowErrorCode code;
  final String message;

  @override
  String toString() => 'FlowError(${code.name}): $message';
}

/// Public entry point for the Flows runner.
///
/// The native iOS and Android runners are reached via a single MethodChannel
/// (`com.usesense.flutter/flows`). Sessions APIs are untouched; this is a
/// parallel surface exposed through `usesense_flutter.dart`.
class UseSenseFlows {
  UseSenseFlows._(this._channel);

  static final UseSenseFlows instance = UseSenseFlows._(
    const MethodChannel('com.usesense.flutter/flows'),
  );

  /// Construct an instance with an injected [MethodChannel]. For testing only.
  @visibleForTesting
  factory UseSenseFlows.forTesting(MethodChannel channel) =>
      UseSenseFlows._(channel);

  final MethodChannel _channel;

  /// Run an operator-authored Flow inside the host app. Resolves with a
  /// [FlowRunResult] when the run reaches a terminal state (completed,
  /// cancelled, errored, abandoned). Throws [FlowError] on transport / token /
  /// unsupported-action faults.
  Future<FlowRunResult> runFlow({
    required String flowRunId,
    required String sdkToken,
    String apiBaseUrl = 'https://api.usesense.ai',
  }) async {
    try {
      final result = await _channel.invokeMapMethod<dynamic, dynamic>(
        'runFlow',
        <String, dynamic>{
          'flowRunId': flowRunId,
          'sdkToken': sdkToken,
          'apiBaseUrl': apiBaseUrl,
        },
      );
      if (result == null) {
        throw FlowError(
          FlowErrorCode.unknown,
          'Empty result from native runner',
        );
      }
      return FlowRunResult.fromMap(result);
    } on PlatformException catch (e) {
      throw FlowError(
        FlowErrorCode.fromWire(e.code),
        e.message ?? 'Flow failed',
      );
    }
  }
}
