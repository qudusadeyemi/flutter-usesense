import 'dart:async';

import 'usesense_flutter_platform_interface.dart';
import 'usesense_types.dart';

/// The main entry point for the UseSense Flutter plugin.
///
/// Provides human presence verification with three core pillars:
///
/// - **DeepSense**: Channel & device integrity
/// - **LiveSense**: Multimodal proof-of-life
/// - **Dedupe**: Identity collision detection
///
/// ## Quick start
///
/// ```dart
/// final useSense = UseSenseFlutter();
///
/// // 1. Initialize once
/// await useSense.initialize(UseSenseConfig(apiKey: 'your_api_key'));
///
/// // 2. Listen for events (optional)
/// useSense.onEvent.listen((event) => print(event));
///
/// // 3. Run verification
/// final result = await useSense.startVerification(
///   VerificationRequest(sessionType: SessionType.enrollment),
/// );
/// print(result.decision); // APPROVE, REJECT, or MANUAL_REVIEW
/// ```
class UseSenseFlutter {
  /// Creates a [UseSenseFlutter] instance.
  UseSenseFlutter();

  UseSenseFlutterPlatform get _platform => UseSenseFlutterPlatform.instance;

  StreamController<UseSenseEvent>? _eventController;
  void Function(UseSenseEvent)? _eventForwarder;

  StreamController<void>? _cancelledController;
  void Function()? _cancelledForwarder;

  /// A broadcast stream of [UseSenseEvent]s emitted during a verification
  /// session.
  ///
  /// Events include session creation, permission requests, capture progress,
  /// upload progress, and the final decision. Subscribe before calling
  /// [startVerification] to receive all events.
  Stream<UseSenseEvent> get onEvent {
    _eventController ??= StreamController<UseSenseEvent>.broadcast(
      onListen: _startListeningEvents,
      onCancel: _stopListeningEvents,
    );
    return _eventController!.stream;
  }

  /// A broadcast stream that emits when the user cancels the verification
  /// session.
  Stream<void> get onCancelled {
    _cancelledController ??= StreamController<void>.broadcast(
      onListen: _startListeningCancelled,
      onCancel: _stopListeningCancelled,
    );
    return _cancelledController!.stream;
  }

  /// Initialize the UseSense SDK with the given [config].
  ///
  /// Must be called once before [startVerification] or any remote flow.
  /// Calling again after a successful initialization is a no-op.
  ///
  /// Throws [UseSenseError] if initialization fails (e.g. invalid API key).
  Future<void> initialize(UseSenseConfig config) {
    return _platform.initialize(config);
  }

  /// Start a verification session.
  ///
  /// The native SDK presents a full-screen camera UI. The returned future
  /// resolves when the session completes with a [UseSenseResult], or throws
  /// a [UseSenseError] if the session fails.
  ///
  /// For enrollment sessions, set [VerificationRequest.sessionType] to
  /// [SessionType.enrollment]. For authentication, use
  /// [SessionType.authentication] and provide [VerificationRequest.identityId].
  /// For a liveness-only check (no enrolment, no duplicate search), use
  /// [SessionType.liveness] without an identity id.
  Future<UseSenseResult> startVerification(VerificationRequest request) {
    return _platform.startVerification(request);
  }

  /// Start a verification session from a single-use [clientToken], so your
  /// API key never ships in the app (server-side init).
  ///
  /// Your server calls `POST /v1/sessions/create-token` with its secret key
  /// and the session type, then hands the returned `client_token` to the app.
  /// The native SDK exchanges it (`POST /v1/sessions/exchange-token`) and runs
  /// the same full-screen capture as [startVerification], with the same
  /// result and errors. Pass the [sessionType] your server used.
  ///
  /// [initialize] is optional here. When it was called, its environment,
  /// base URL, branding and capture options apply; a token-only app can pass
  /// `apiKey: ''` to set those without a key.
  ///
  /// A rejected token throws [UseSenseError] with code
  /// [UseSenseError.invalidClientToken] and the reason in
  /// [UseSenseError.serverCode]. Tokens are single use, so fetch a new one to
  /// try again.
  Future<UseSenseResult> startVerificationWithToken({
    required String clientToken,
    SessionType sessionType = SessionType.authentication,
  }) {
    return _platform.startVerificationWithToken(
      clientToken: clientToken,
      sessionType: sessionType,
    );
  }

  /// Start a remote enrollment flow using a pre-created [remoteEnrollmentId].
  ///
  /// The enrollment ID should be obtained from your backend via the UseSense
  /// Server API.
  Future<UseSenseResult> startRemoteEnrollment(String remoteEnrollmentId) {
    return _platform.startRemoteEnrollment(remoteEnrollmentId);
  }

  /// Start a remote verification flow using a pre-created [remoteSessionId].
  ///
  /// The session ID should be obtained from your backend via the UseSense
  /// Server API.
  Future<UseSenseResult> startRemoteVerification(String remoteSessionId) {
    return _platform.startRemoteVerification(remoteSessionId);
  }

  /// Whether the SDK has been initialized successfully.
  Future<bool> isInitialized() {
    return _platform.isInitialized();
  }

  /// Reset the SDK, releasing all resources and clearing cached state.
  ///
  /// After calling this, [initialize] must be called again before starting
  /// any new sessions.
  Future<void> reset() {
    return _platform.reset();
  }

  /// Start a LiveSense v4 zoom-motion verification session.
  ///
  /// Phase 1 ticket F-1.
  ///
  /// The session must have been created on your backend; pass the
  /// session_id, session_token, nonce, and apiBaseUrl received from
  /// the Server API. The native SDK presents a full-screen zoom
  /// capture UI, signs the frame hash chain with the platform-attested
  /// key, uploads, and returns the opaque [V4Verdict].
  ///
  /// Sub-scores and pillar verdicts never reach this method; consume
  /// detail via the signed webhook delivered to your backend.
  Future<V4Verdict> startV4Verification(V4VerificationRequest request) {
    return _platform.startV4Verification(request);
  }

  /// Release resources held by this instance.
  ///
  /// Call this when you no longer need the plugin (e.g. on widget disposal).
  void dispose() {
    _stopListeningEvents();
    _stopListeningCancelled();
    _eventController?.close();
    _eventController = null;
    _cancelledController?.close();
    _cancelledController = null;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _startListeningEvents() {
    _eventForwarder = (event) => _eventController?.add(event);
    _platform.addEventListener(_eventForwarder!);
  }

  void _stopListeningEvents() {
    if (_eventForwarder != null) {
      _platform.removeEventListener(_eventForwarder!);
      _eventForwarder = null;
    }
  }

  void _startListeningCancelled() {
    _cancelledForwarder = () => _cancelledController?.add(null);
    _platform.addCancelledListener(_cancelledForwarder!);
  }

  void _stopListeningCancelled() {
    if (_cancelledForwarder != null) {
      _platform.removeCancelledListener(_cancelledForwarder!);
      _cancelledForwarder = null;
    }
  }
}
