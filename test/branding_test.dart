// BRAND-v1: appearance and copy reach the native SDK in session mode.
//
// Captures the real pigeon `initialize` message and decodes it with the
// generated codec, so the wire shape the Kotlin / Swift bridges read is
// asserted end to end on the Dart side.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usesense_flutter/src/generated/usesense_api.g.dart';
import 'package:usesense_flutter/src/usesense_flutter_method_channel.dart';
import 'package:usesense_flutter/usesense_flutter.dart';

const _initializeChannel =
    'dev.flutter.pigeon.usesense_flutter.UseSenseHostApi.initialize';

Future<PigeonUseSenseConfig> _captureInitialize(UseSenseConfig config) async {
  const codec = UseSenseHostApi.pigeonChannelCodec;
  PigeonUseSenseConfig? sent;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler(_initializeChannel,
      (ByteData? message) async {
    final args = codec.decodeMessage(message)! as List<Object?>;
    sent = args[0]! as PigeonUseSenseConfig;
    return codec.encodeMessage(<Object?>[null]);
  });
  addTearDown(() => messenger.setMockMessageHandler(_initializeChannel, null));

  await MethodChannelUseSenseFlutter().initialize(config);
  return sent!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('session mode forwards appearance and copy to the native bridge',
      () async {
    final sent = await _captureInitialize(
      const UseSenseConfig(
        apiKey: 'sk_sandbox_test',
        branding: BrandingConfig(
          primaryColor: '#1F7A4D',
          buttonRadius: 8,
          appearance: FlowAppearance(
            mode: 'light',
            colors: AppearanceColors(
              primary: '#1F7A4D',
              dark: AppearanceColors(background: '#0B0B12'),
            ),
            shape: AppearanceShape(buttonRadius: 10, buttonStyle: 'outline'),
            capture: AppearanceCapture(ring: '#248E5A', challenge: '#A878FC'),
          ),
          copy: FlowCopy(
            capture: <String, dynamic>{
              'primer': <String, dynamic>{
                'selfieTitle': 'Quick selfie for {app}',
                'selfieTips': <String>['Good light', 'No hat'],
              },
              'extraCheck': <String, dynamic>{
                'headTurnNext': 'Now to the {side}',
              },
            },
          ),
        ),
      ),
    );

    final branding = sent.branding!;
    expect(branding.primaryColor, '#1F7A4D');
    expect(branding.buttonRadius, 8);
    expect(branding.appearance, <String, Object?>{
      'colors': <String, Object?>{
        'primary': '#1F7A4D',
        'dark': <String, Object?>{'background': '#0B0B12'},
      },
      'shape': <String, Object?>{'buttonRadius': 10, 'buttonStyle': 'outline'},
      'mode': 'light',
      'capture': <String, Object?>{'ring': '#248E5A', 'challenge': '#A878FC'},
    });
    expect(branding.copy, <String, Object?>{
      'capture': <String, Object?>{
        'primer': <String, Object?>{
          'selfieTitle': 'Quick selfie for {app}',
          'selfieTips': <Object?>['Good light', 'No hat'],
        },
        'extraCheck': <String, Object?>{'headTurnNext': 'Now to the {side}'},
      },
    });
  });

  test('legacy-only branding sends no appearance or copy', () async {
    final sent = await _captureInitialize(
      const UseSenseConfig(
        apiKey: 'sk_sandbox_test',
        branding: BrandingConfig(primaryColor: '#4F46E5'),
      ),
    );
    expect(sent.branding!.primaryColor, '#4F46E5');
    expect(sent.branding!.buttonRadius, isNull);
    expect(sent.branding!.appearance, isNull);
    expect(sent.branding!.copy, isNull);
  });

  test('an all-null appearance is sent as null, not an empty map', () async {
    final sent = await _captureInitialize(
      const UseSenseConfig(
        apiKey: 'sk_sandbox_test',
        branding: BrandingConfig(
          appearance: FlowAppearance(capture: AppearanceCapture()),
          copy: FlowCopy(),
        ),
      ),
    );
    expect(sent.branding!.appearance, isNull);
    expect(sent.branding!.copy, isNull);
  });

  test('Flows runFlow carries capture accents and capture copy', () {
    const appearance = FlowAppearance(
      capture: AppearanceCapture(warning: '#FFB84D'),
    );
    const copy = FlowCopy(
      capture: <String, dynamic>{
        'leave': <String, dynamic>{'title': 'Leave the check?'},
      },
    );
    expect(appearance.toMap(), <String, dynamic>{
      'capture': <String, dynamic>{'warning': '#FFB84D'},
    });
    expect(copy.toMap(), <String, dynamic>{
      'capture': <String, dynamic>{
        'leave': <String, dynamic>{'title': 'Leave the check?'},
      },
    });
  });
}
