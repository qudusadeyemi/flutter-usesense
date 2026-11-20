import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'usesense_error.dart';
import 'usesense_flutter_method_channel.dart';
import 'usesense_types.dart';

/// The UseSense capture embedded in your own screen, instead of the
/// full-screen UI of [UseSenseFlutter.startVerification].
///
/// It runs the same verification with the same screens: the config,
/// [BrandingConfig] (appearance and copy, code over dashboard) and capture
/// options from [UseSenseFlutter.initialize] apply, and the outcome arrives
/// once, through [onResult], [onError] or [onCancelled]. Remove the widget
/// (for example, pop the route) in the callback.
///
/// ```dart
/// UseSenseView(
///   request: const VerificationRequest(sessionType: SessionType.enrollment),
///   onResult: (result) => Navigator.of(context).pop(result),
///   onError: (error) => showError(error.message),
///   onCancelled: () => Navigator.of(context).pop(),
/// )
/// ```
///
/// Start from a client token with [UseSenseView.withToken] to keep the API
/// key off the device (see [UseSenseFlutter.startVerificationWithToken]).
///
/// Give it the space the camera should fill; full screen works best. A
/// verification starts when the widget is first built and ends when it is
/// disposed: disposing mid-capture stops the camera and the session, and no
/// callback fires.
///
/// Platform notes:
/// - **Android**: the host Activity must be a `FragmentActivity`, so make
///   `MainActivity` extend `FlutterFragmentActivity`. Otherwise [onError]
///   reports `unsupported_activity`. The view uses hybrid composition (the
///   camera preview is a `SurfaceView`). Back navigation goes to the capture
///   while it runs: mid-capture it asks before leaving, otherwise it ends as
///   cancelled ([onCancelled]); the route does not pop by itself.
/// - **iOS**: the capture has its own close button ([onCancelled]). A route
///   pop is not intercepted; it disposes the view.
/// - Camera and microphone permissions are requested by the capture, as in
///   the full-screen flow.
class UseSenseView extends StatefulWidget {
  /// A verification on a session the SDK creates with the API key from
  /// [UseSenseFlutter.initialize], like [UseSenseFlutter.startVerification].
  /// Without `initialize`, [onError] reports
  /// [UseSenseError.sdkNotInitialized].
  const UseSenseView({
    super.key,
    required VerificationRequest this.request,
    required this.onResult,
    this.onError,
    this.onCancelled,
  })  : clientToken = null,
        sessionType = null;

  /// A verification on the session a single-use [clientToken] exchanges for,
  /// like [UseSenseFlutter.startVerificationWithToken]. No API key is needed
  /// on the device; `initialize` is optional. Pass the [sessionType] your
  /// server used for `POST /v1/sessions/create-token`.
  const UseSenseView.withToken({
    super.key,
    required String this.clientToken,
    SessionType this.sessionType = SessionType.authentication,
    required this.onResult,
    this.onError,
    this.onCancelled,
  }) : request = null;

  /// The API key session to run, or null for a token session.
  final VerificationRequest? request;

  /// The single-use client token, or null for an API key session.
  final String? clientToken;

  /// The token session's type (null for an API key session).
  final SessionType? sessionType;

  /// The verification finished with a decision.
  final ValueChanged<UseSenseResult> onResult;

  /// The verification failed. Same errors as the full-screen flow.
  final ValueChanged<UseSenseError>? onError;

  /// The person left the capture.
  final VoidCallback? onCancelled;

  /// The platform view type registered by the native plugin.
  @visibleForTesting
  static const String viewType = 'com.usesense.flutter/view';

  /// The creation parameters the native view reads. A verification is fixed
  /// when the view is created; changing them later has no effect.
  @visibleForTesting
  Map<String, Object?> get creationParams {
    final token = clientToken;
    if (token != null) {
      return <String, Object?>{
        'kind': 'token',
        'clientToken': token.trim(),
        'sessionType': (sessionType ?? SessionType.authentication).name,
      };
    }
    final r = request!;
    return <String, Object?>{
      'kind': 'request',
      'sessionType': r.sessionType.name,
      'externalUserId': r.externalUserId,
      'identityId': r.identityId,
      'metadata': r.metadata,
    };
  }

  @override
  State<UseSenseView> createState() => _UseSenseViewState();

  /// The native result map as a [UseSenseResult].
  @visibleForTesting
  static UseSenseResult parseResult(Object? arguments) {
    final map = (arguments as Map?) ?? const <Object?, Object?>{};
    return UseSenseResult(
      sessionId: map['sessionId'] as String? ?? '',
      sessionType: map['sessionType'] as String?,
      identityId: map['identityId'] as String?,
      decision: map['decision'] as String? ?? 'REJECT',
      timestamp: map['timestamp'] as String? ?? '',
    );
  }

  /// The native error map as a [UseSenseError], mapped as the start methods.
  @visibleForTesting
  static UseSenseError parseError(Object? arguments) {
    final map = (arguments as Map?) ?? const <Object?, Object?>{};
    final details = map['details'];
    return MethodChannelUseSenseFlutter.wrapPlatformError(
      PlatformException(
        code: map['code'] as String? ?? 'sdk_error',
        message: map['message'] as String?,
        details:
            details is Map ? details.map((k, v) => MapEntry('$k', '$v')) : null,
      ),
    );
  }
}

class _UseSenseViewState extends State<UseSenseView> {
  MethodChannel? _channel;
  bool _settled = false;

  /// A local check failed: no native view is created.
  bool _failed = false;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    final token = widget.clientToken;
    if (token != null && token.trim().isEmpty) {
      _failLater('clientToken must not be blank.');
    } else if (!_isAndroid && defaultTargetPlatform != TargetPlatform.iOS) {
      _failLater('UseSenseView supports Android and iOS only.');
    }
  }

  /// Report a local failure after the first frame (never during build).
  void _failLater(String message) {
    _settled = true;
    _failed = true;
    final error = UseSenseError(
      code: UseSenseError.invalidConfig,
      message: message,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onError?.call(error);
    });
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('com.usesense.flutter/view_$id');
    _channel = channel;
    channel.setMethodCallHandler(_handle);
    // Native holds an early result until this arrives.
    channel.invokeMethod<void>('ready').catchError((Object _) {});
  }

  Future<void> _handle(MethodCall call) async {
    if (!mounted || _settled) return;
    switch (call.method) {
      case 'onResult':
        _settle();
        widget.onResult(UseSenseView.parseResult(call.arguments));
      case 'onError':
        _settle();
        widget.onError?.call(UseSenseView.parseError(call.arguments));
      case 'onCancelled':
        _settle();
        widget.onCancelled?.call();
    }
  }

  void _settle() {
    // Let the route pop again once the capture has finished.
    setState(() => _settled = true);
  }

  @override
  void dispose() {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel.invokeMethod<void>('dispose').catchError((Object _) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final Widget view;
    if (_isAndroid) {
      view = PlatformViewLink(
        viewType: UseSenseView.viewType,
        surfaceFactory: (context, controller) => AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        ),
        onCreatePlatformView: (params) {
          // Hybrid composition: the native container joins the Activity's
          // view hierarchy, where the FragmentManager finds it, and the
          // camera's SurfaceView renders.
          return PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: UseSenseView.viewType,
            layoutDirection:
                Directionality.maybeOf(context) ?? TextDirection.ltr,
            creationParams: widget.creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () => params.onFocusChanged(true),
          )
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..addOnPlatformViewCreatedListener(_onPlatformViewCreated)
            ..create();
        },
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      view = UiKitView(
        viewType: UseSenseView.viewType,
        creationParams: widget.creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else {
      return const SizedBox.shrink();
    }
    if (!_isAndroid) return view;
    return PopScope(
      canPop: _settled,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _channel?.invokeMethod<void>('back');
      },
      child: view,
    );
  }
}
