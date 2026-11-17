import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usesense_flutter/usesense_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.usesense.flutter/device_check');
  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  setUp(calls.clear);
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  UseSenseDeviceCheck make() => UseSenseDeviceCheck.forTesting(
        channel,
        deviceCheckId: 'dc_0123456789abcdef',
        token: 'dct_token',
        nonce: 'dn_nonce',
        apiBaseUrl: 'https://staging.api.usesense.ai',
        timeout: const Duration(seconds: 12),
      );

  test('start and finish send the config on one handle and resolve ok',
      () async {
    answer((call) => {'ok': true, 'phase': call.method});
    final check = make();
    final s = await check.start();
    final f = await check.finish();
    expect(s.ok, isTrue);
    expect(s.phase, DeviceCheckPhase.start);
    expect(f.ok, isTrue);
    expect(f.phase, DeviceCheckPhase.finish);
    expect(calls.map((c) => c.method), ['start', 'finish']);
    final a = calls.first.arguments as Map;
    expect(a['deviceCheckId'], 'dc_0123456789abcdef');
    expect(a['token'], 'dct_token');
    expect(a['nonce'], 'dn_nonce');
    expect(a['apiBaseUrl'], 'https://staging.api.usesense.ai');
    expect(a['timeoutMs'], 12000);
    expect((calls.last.arguments as Map)['handle'], a['handle']);
  });

  test('native error codes are normalised across iOS and Android', () async {
    final cases = {
      'token_invalid': DeviceCheckErrorCode.invalidToken, // iOS
      'invalid_token': DeviceCheckErrorCode.invalidToken, // Android
      'network_unavailable': DeviceCheckErrorCode.networkError, // iOS
      'network_error': DeviceCheckErrorCode.networkError, // Android
      'service_unavailable': DeviceCheckErrorCode.unavailable, // Android
      'unavailable': DeviceCheckErrorCode.unavailable, // iOS
      'invalid_request': DeviceCheckErrorCode.invalidInput, // Android
      'out_of_order': DeviceCheckErrorCode.outOfOrder,
      'something_new': DeviceCheckErrorCode.unknown,
    };
    for (final entry in cases.entries) {
      answer(
        (call) => {
          'ok': false,
          'phase': 'start',
          'error': {
            'code': entry.key,
            'message': 'm',
            'retryable': true,
            'serverCode': 'x',
            'httpStatus': 503,
          },
        },
      );
      final r = await make().start();
      expect(r.ok, isFalse, reason: entry.key);
      expect(r.error!.code, entry.value, reason: entry.key);
      expect(r.error!.retryable, isTrue);
      expect(r.error!.httpStatus, 503);
    }
  });

  test('never throws: platform errors and a missing plugin resolve as failures',
      () async {
    answer((call) => throw PlatformException(code: 'timeout', message: 'slow'));
    final r = await make().start();
    expect(r.ok, isFalse);
    expect(r.error!.code, DeviceCheckErrorCode.timeout);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    final missing = await make().finish();
    expect(missing.ok, isFalse);
    expect(missing.error!.code, DeviceCheckErrorCode.unknown);
  });

  test('dispose releases the native check and later calls are cancelled',
      () async {
    answer(
      (call) =>
          call.method == 'dispose' ? null : {'ok': true, 'phase': call.method},
    );
    final check = make();
    await check.start();
    await check.dispose();
    final after = await check.finish();
    expect(calls.map((c) => c.method), ['start', 'dispose']);
    expect(after.error!.code, DeviceCheckErrorCode.cancelled);
  });
}
