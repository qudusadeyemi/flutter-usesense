import 'package:flutter/material.dart';
import 'package:usesense_flutter/usesense_flutter.dart';

import 'result_screen.dart';

/// The capture embedded in the app's own screen (J2): the app keeps its app
/// bar and its own content, and `UseSenseView` fills the rest.
///
/// Android needs `MainActivity` to extend `FlutterFragmentActivity` (see the
/// example README).
class EmbeddedCaptureScreen extends StatelessWidget {
  const EmbeddedCaptureScreen.request({super.key, required this.request})
      : clientToken = null,
        sessionType = SessionType.authentication;

  const EmbeddedCaptureScreen.token({
    super.key,
    required String this.clientToken,
    required this.sessionType,
  }) : request = null;

  final VerificationRequest? request;
  final String? clientToken;
  final SessionType sessionType;

  @override
  Widget build(BuildContext context) {
    void onResult(UseSenseResult result) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ResultScreen(result: result)),
      );
    }

    void onError(UseSenseError error) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: ${error.message}')),
      );
    }

    void onCancelled() => Navigator.of(context).pop();

    final token = clientToken;
    return Scaffold(
      appBar: AppBar(title: const Text('Embedded capture')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              token != null
                  ? 'Your screen. The capture below runs on a client token: '
                      'no API key on the device.'
                  : 'Your screen. The capture below runs on the API key '
                      'session from initialize().',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: token != null
                ? UseSenseView.withToken(
                    clientToken: token,
                    sessionType: sessionType,
                    onResult: onResult,
                    onError: onError,
                    onCancelled: onCancelled,
                  )
                : UseSenseView(
                    request: request!,
                    onResult: onResult,
                    onError: onError,
                    onCancelled: onCancelled,
                  ),
          ),
        ],
      ),
    );
  }
}
