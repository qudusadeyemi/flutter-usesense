import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usesense_flutter/usesense_flutter.dart';

/// Dart-side tests for the Flows MethodChannel bridge. Two load-bearing
/// concerns are covered:
///   1. Success path: a Map from native is decoded into FlowRunResult with the
///      right enum mapping for wire values.
///   2. Error path: a PlatformException from native maps to a FlowError with
///      the right FlowErrorCode, so host apps catch one taxonomy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.usesense.flutter/flows');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('runFlow decodes a success Map into FlowRunResult', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'runFlow');
      final args = call.arguments as Map<dynamic, dynamic>;
      expect(args['flowRunId'], 'fr_1');
      expect(args['sdkToken'], 'tok_a');
      expect(args['apiBaseUrl'], 'https://api.usesense.ai');
      return <String, Object?>{
        'flowRunId': 'fr_1',
        'state': 'completed',
        'outcome': 'APPROVE',
      };
    });

    final result = await UseSenseFlows.forTesting(channel).runFlow(
      flowRunId: 'fr_1',
      sdkToken: 'tok_a',
    );

    expect(result.flowRunId, 'fr_1');
    expect(result.state, FlowRunState.completed);
    expect(result.outcome, FlowOutcome.approve);
  });

  test('runFlow surfaces a cancelled run as FlowOutcome null', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <String, Object?>{
        'flowRunId': 'fr_2',
        'state': 'cancelled',
        'outcome': null,
      };
    });

    final result = await UseSenseFlows.forTesting(channel).runFlow(
      flowRunId: 'fr_2',
      sdkToken: 'tok_b',
    );

    expect(result.state, FlowRunState.cancelled);
    expect(result.outcome, isNull);
  });

  test('runFlow translates a PlatformException into a typed FlowError', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'token_expired',
        message: 'SDK token has expired',
      );
    });

    Object? thrown;
    try {
      await UseSenseFlows.forTesting(channel).runFlow(
        flowRunId: 'fr_3',
        sdkToken: 'tok_c',
      );
    } catch (e) {
      thrown = e;
    }

    expect(thrown, isA<FlowError>());
    expect((thrown as FlowError).code, FlowErrorCode.tokenExpired);
    expect(thrown.message, 'SDK token has expired');
  });

  test('runFlow maps every documented PlatformException code', () async {
    final cases = <String, FlowErrorCode>{
      'token_expired': FlowErrorCode.tokenExpired,
      'token_invalid': FlowErrorCode.tokenInvalid,
      'network_unavailable': FlowErrorCode.networkUnavailable,
      'permission_denied': FlowErrorCode.permissionDenied,
      'provider_unavailable': FlowErrorCode.providerUnavailable,
      'cancelled': FlowErrorCode.cancelled,
      'unsupported_action': FlowErrorCode.unsupportedAction,
      // Server form validation: the native runner handles this inline, but
      // host apps driving advance() outside the runner still see it.
      'invalid_input': FlowErrorCode.invalidInput,
      // Anything unknown collapses to FlowErrorCode.unknown.
      'lol_what': FlowErrorCode.unknown,
    };
    for (final entry in cases.entries) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: entry.key, message: 'm');
      });
      Object? thrown;
      try {
        await UseSenseFlows.forTesting(channel)
            .runFlow(flowRunId: 'fr', sdkToken: 't');
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<FlowError>(), reason: 'wire=${entry.key}');
      expect(
        (thrown as FlowError).code,
        entry.value,
        reason: 'wire=${entry.key}',
      );
    }
  });
}
