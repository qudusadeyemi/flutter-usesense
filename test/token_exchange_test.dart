// J1: startVerificationWithToken crosses the real pigeon channel. The host
// side is mocked with the generated codec, so the wire shape the Kotlin and
// Swift bridges read (clientToken, sessionType raw int) is asserted here.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usesense_flutter/src/generated/usesense_api.g.dart';
import 'package:usesense_flutter/src/usesense_flutter_method_channel.dart';
import 'package:usesense_flutter/usesense_flutter.dart';

const _channel =
    'dev.flutter.pigeon.usesense_flutter.UseSenseHostApi.startVerificationWithToken';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const codec = UseSenseHostApi.pigeonChannelCodec;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final sent = <List<Object?>>[];

  void reply(List<Object?> Function(List<Object?> args) answer) {
    messenger.setMockMessageHandler(_channel, (ByteData? message) async {
      final args = codec.decodeMessage(message)! as List<Object?>;
      sent.add(args);
      return codec.encodeMessage(answer(args));
    });
  }

  setUp(sent.clear);
  tearDown(() => messenger.setMockMessageHandler(_channel, null));

  test('sends the trimmed token and the session type, returns the result',
      () async {
    reply(
      (_) => <Object?>[
        PigeonUseSenseResult(
          sessionId: 'ses_1',
          sessionType: 'enrollment',
          identityId: 'idn_1',
          decision: 'APPROVE',
          timestamp: '2026-11-20T10:00:00Z',
        ),
      ],
    );

    final result =
        await MethodChannelUseSenseFlutter().startVerificationWithToken(
      clientToken: '  ct_abc  ',
      sessionType: SessionType.enrollment,
    );

    expect(
      sent.single,
      <Object?>['ct_abc', PigeonSessionType.enrollment.index],
    );
    expect(result.sessionId, 'ses_1');
    expect(result.decision, 'APPROVE');
    expect(result.identityId, 'idn_1');
  });

  test('every session type maps to its pigeon raw value', () async {
    reply(
      (_) => <Object?>[
        PigeonUseSenseResult(
          sessionId: 's',
          decision: 'APPROVE',
          timestamp: 't',
        ),
      ],
    );
    for (final type in SessionType.values) {
      await MethodChannelUseSenseFlutter()
          .startVerificationWithToken(clientToken: 'ct', sessionType: type);
    }
    expect(sent.map((a) => a[1]), [0, 1, 2]);
    expect(
      PigeonSessionType.values.map((t) => t.name),
      SessionType.values.map((t) => t.name),
    );
  });

  test('the facade defaults to an authentication session', () async {
    reply(
      (_) => <Object?>[
        PigeonUseSenseResult(
          sessionId: 's',
          decision: 'REJECT',
          timestamp: 't',
        ),
      ],
    );
    await UseSenseFlutter().startVerificationWithToken(clientToken: 'ct');
    expect(sent.single[1], PigeonSessionType.authentication.index);
  });

  test('a blank token fails locally without a native call', () async {
    reply((_) => <Object?>[null]);
    await expectLater(
      MethodChannelUseSenseFlutter().startVerificationWithToken(
        clientToken: '   ',
        sessionType: SessionType.authentication,
      ),
      throwsA(
        isA<UseSenseError>()
            .having((e) => e.code, 'code', UseSenseError.invalidConfig),
      ),
    );
    expect(sent, isEmpty);
  });

  for (final code in [
    'token_not_found',
    'token_expired',
    'token_already_used',
    'invalid_token',
  ]) {
    test('a rejected token ($code) maps to invalidClientToken', () async {
      reply((_) => <Object?>[code, 'Token rejected.', null]);
      await expectLater(
        MethodChannelUseSenseFlutter().startVerificationWithToken(
          clientToken: 'ct',
          sessionType: SessionType.authentication,
        ),
        throwsA(
          isA<UseSenseError>()
              .having((e) => e.code, 'code', UseSenseError.invalidClientToken)
              .having((e) => e.serverCode, 'serverCode', code)
              .having((e) => e.message, 'message', 'Token rejected.'),
        ),
      );
    });
  }

  test('cancel and network errors map as the other start methods', () async {
    reply((_) => <Object?>['session_cancelled', 'User cancelled.', null]);
    await expectLater(
      MethodChannelUseSenseFlutter().startVerificationWithToken(
        clientToken: 'ct',
        sessionType: SessionType.liveness,
      ),
      throwsA(
        isA<UseSenseError>()
            .having((e) => e.code, 'code', UseSenseError.sessionCancelled)
            .having((e) => e.serverCode, 'serverCode', isNull),
      ),
    );

    reply((_) => <Object?>['network_error', 'Offline.', null]);
    await expectLater(
      MethodChannelUseSenseFlutter().startVerificationWithToken(
        clientToken: 'ct',
        sessionType: SessionType.liveness,
      ),
      throwsA(
        isA<UseSenseError>()
            .having((e) => e.code, 'code', UseSenseError.networkError)
            .having((e) => e.isRetryable, 'isRetryable', isTrue),
      ),
    );
  });

  test('a platform implementation without the method throws Unimplemented', () {
    expect(
      () => _LegacyPlatform().startVerificationWithToken(
        clientToken: 'ct',
        sessionType: SessionType.enrollment,
      ),
      throwsUnimplementedError,
    );
  });
}

/// A platform implementation written before startVerificationWithToken.
class _LegacyPlatform extends UseSenseFlutterPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
