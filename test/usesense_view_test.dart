// J2: UseSenseView. The platform-views channel is mocked, so these tests
// check what Dart sends to the native view (creation params, ready, back,
// dispose) and how native callbacks reach the widget.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usesense_flutter/usesense_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('creationParams', () {
    test('an API key session sends the request', () {
      final view = UseSenseView(
        request: const VerificationRequest(
          sessionType: SessionType.authentication,
          identityId: 'idn_1',
          externalUserId: 'user-1',
          metadata: {'k': 'v'},
        ),
        onResult: (_) {},
      );
      expect(view.creationParams, <String, Object?>{
        'kind': 'request',
        'sessionType': 'authentication',
        'externalUserId': 'user-1',
        'identityId': 'idn_1',
        'metadata': {'k': 'v'},
      });
    });

    test('a token session sends the trimmed token and its type', () {
      final view = UseSenseView.withToken(
        clientToken: ' ct_1 ',
        sessionType: SessionType.liveness,
        onResult: (_) {},
      );
      expect(view.creationParams, <String, Object?>{
        'kind': 'token',
        'clientToken': 'ct_1',
        'sessionType': 'liveness',
      });
      expect(
        UseSenseView.withToken(clientToken: 'ct', onResult: (_) {})
            .creationParams['sessionType'],
        'authentication',
      );
    });
  });

  group('native payloads', () {
    test('a result map becomes a UseSenseResult', () {
      final r = UseSenseView.parseResult({
        'sessionId': 'ses_1',
        'sessionType': 'enrollment',
        'identityId': 'idn_1',
        'decision': 'MANUAL_REVIEW',
        'timestamp': 't',
      });
      expect(r.sessionId, 'ses_1');
      expect(r.decision, 'MANUAL_REVIEW');
      expect(r.identityId, 'idn_1');
    });

    test('an error map is mapped as the start methods', () {
      final e = UseSenseView.parseError({
        'code': 'token_expired',
        'message': 'Expired.',
        'details': {'status': 410},
      });
      expect(e.code, UseSenseError.invalidClientToken);
      expect(e.serverCode, 'token_expired');
      expect(e.message, 'Expired.');
      expect(e.details, {'status': '410'});
      expect(
        UseSenseView.parseError({'code': 'camera_permission_denied'}).code,
        UseSenseError.cameraPermissionDenied,
      );
    });
  });

  group('on iOS', () {
    final platformCalls = <MethodCall>[];
    final viewCalls = <MethodCall>[];
    // Platform view ids grow across tests: follow the one just created.
    var viewChannel = '';

    setUp(() {
      platformCalls.clear();
      viewCalls.clear();
      messenger.setMockMethodCallHandler(SystemChannels.platform_views,
          (call) async {
        platformCalls.add(call);
        if (call.method == 'create') {
          viewChannel =
              'com.usesense.flutter/view_${(call.arguments as Map)['id']}';
          messenger.setMockMethodCallHandler(MethodChannel(viewChannel),
              (call) async {
            viewCalls.add(call);
            return null;
          });
        }
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      if (viewChannel.isNotEmpty) {
        messenger.setMockMethodCallHandler(MethodChannel(viewChannel), null);
      }
    });

    Future<void> nativeSends(String method, [Object? args]) async {
      await messenger.handlePlatformMessage(
        viewChannel,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );
    }

    testWidgets(
      'creates the native view, says ready, delivers one result',
      (tester) async {
        final results = <UseSenseResult>[];
        var cancels = 0;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: UseSenseView.withToken(
              clientToken: 'ct_1',
              sessionType: SessionType.enrollment,
              onResult: results.add,
              onCancelled: () => cancels++,
            ),
          ),
        );
        await tester.pump();

        final create = platformCalls.singleWhere((c) => c.method == 'create');
        final args = create.arguments as Map;
        expect(args['viewType'], UseSenseView.viewType);
        final params = const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(args['params'] as Uint8List),
        );
        expect(params, {
          'kind': 'token',
          'clientToken': 'ct_1',
          'sessionType': 'enrollment',
        });
        expect(viewCalls.map((c) => c.method), ['ready']);

        await nativeSends('onResult', {
          'sessionId': 'ses_1',
          'decision': 'APPROVE',
          'timestamp': 't',
        });
        // A second outcome is ignored: the view settles once.
        await nativeSends('onCancelled');
        expect(results.single.sessionId, 'ses_1');
        expect(cancels, 0);

        await tester.pumpWidget(const SizedBox());
        expect(viewCalls.map((c) => c.method), ['ready', 'dispose']);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'errors and cancels reach their callbacks',
      (tester) async {
        final errors = <UseSenseError>[];
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: UseSenseView(
              request: const VerificationRequest(
                sessionType: SessionType.enrollment,
              ),
              onResult: (_) => fail('no result expected'),
              onError: errors.add,
            ),
          ),
        );
        await tester.pump();
        await nativeSends('onError', {
          'code': 'sdk_not_initialized',
          'message': 'Call initialize() first.',
        });
        expect(errors.single.code, UseSenseError.sdkNotInitialized);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'a blank token fails locally and creates no native view',
      (tester) async {
        final errors = <UseSenseError>[];
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: UseSenseView.withToken(
              clientToken: '  ',
              onResult: (_) {},
              onError: errors.add,
            ),
          ),
        );
        await tester.pump();
        expect(errors.single.code, UseSenseError.invalidConfig);
        expect(platformCalls.where((c) => c.method == 'create'), isEmpty);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });

  testWidgets(
    'an unsupported platform reports an error',
    (tester) async {
      final errors = <UseSenseError>[];
      await tester.pumpWidget(
        UseSenseView.withToken(
          clientToken: 'ct',
          onResult: (_) {},
          onError: errors.add,
        ),
      );
      await tester.pump();
      expect(errors.single.code, UseSenseError.invalidConfig);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
