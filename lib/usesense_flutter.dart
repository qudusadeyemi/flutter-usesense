/// Flutter plugin for UseSense — human presence verification.
///
/// Provides cross-platform access to the UseSense native SDKs for identity
/// verification with DeepSense (device integrity), LiveSense (proof-of-life),
/// and Dedupe (identity collision detection).
///
/// ## Getting started
///
/// ```dart
/// import 'package:usesense_flutter/usesense_flutter.dart';
///
/// final useSense = UseSenseFlutter();
/// await useSense.initialize(UseSenseConfig(apiKey: 'your_api_key'));
///
/// final result = await useSense.startVerification(
///   VerificationRequest(sessionType: SessionType.enrollment),
/// );
/// ```
library;

export 'src/usesense_error.dart' show UseSenseError;
export 'src/usesense_flutter_platform_interface.dart'
    show UseSenseFlutterPlatform;
export 'src/usesense_flutter_plugin.dart' show UseSenseFlutter;
export 'src/usesense_types.dart'
    show
        BrandingConfig,
        SessionType,
        UseSenseConfig,
        UseSenseEnvironment,
        UseSenseEvent,
        UseSenseEventType,
        UseSenseResult,
        VerificationRequest;

// Slice 5c: Flows. A parallel surface to Sessions — host apps choose one
// per call. See guides/flows/sessions-vs-flows in the API docs.
export 'src/flows.dart'
    show
        FlowError,
        FlowErrorCode,
        FlowOutcome,
        FlowRunResult,
        FlowRunState,
        UseSenseFlows;

// White-label customization for the Flows runner (appearance + copy).
export 'src/flow_appearance.dart'
    show
        AppearanceBackground,
        AppearanceColors,
        AppearanceIcons,
        AppearanceLoader,
        AppearanceLogo,
        AppearanceShape,
        AppearanceTypography,
        ButtonsCopy,
        DocumentCopy,
        ErrorsCopy,
        FaceCopy,
        FlowAppearance,
        FlowCopy,
        FormCopy,
        IdNumberCopy,
        LoadingCopy,
        PrivacyCopy,
        ResultCopy,
        WelcomeCopy;
