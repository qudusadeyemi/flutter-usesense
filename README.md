# flutter_usesense

Flutter plugin wrapping the [UseSense Android SDK](https://github.com/qudusadeyemi/usesense-android-sdk) for identity verification and liveness detection.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_usesense: ^0.1.0
```

### Android Setup

1. Ensure your `minSdkVersion` is at least **24** in `android/app/build.gradle`.

2. Add the UseSense SDK dependency (when the Maven artifact is published):

```groovy
// android/build.gradle
allprojects {
    repositories {
        // maven { url 'https://maven.usesense.ai/releases' }
    }
}
```

## Usage

```dart
import 'package:flutter_usesense/flutter_usesense.dart';

// 1. Initialize (once, e.g. in main)
await UseSense.initialize(UseSenseConfig(
  apiKey: 'your_api_key',
  environment: UseSenseEnvironment.sandbox,
));

// 2. Listen to events (optional)
final subscription = UseSense.events.listen((event) {
  print('[${event.type}] ${event.data}');
});

// 3. Start verification
try {
  final result = await UseSense.startVerification(
    VerificationRequest(
      sessionType: SessionType.enrollment,
      externalUserId: 'user_123',
      metadata: {'source': 'onboarding'},
    ),
  );

  if (result.isApproved) {
    print('Verified! Session: ${result.sessionId}');
  } else if (result.isPendingReview) {
    print('Under review');
  } else {
    print('Rejected');
  }
} on UseSenseCancelledException {
  print('User cancelled');
} on UseSenseError catch (e) {
  print('Error ${e.code}: ${e.message}');
  if (e.isRetryable) {
    // Safe to retry
  }
} finally {
  subscription.cancel();
}
```

### Authentication Sessions

```dart
final result = await UseSense.startVerification(
  VerificationRequest(
    sessionType: SessionType.authentication,
    identityId: 'identity_abc123', // required for authentication
    externalUserId: 'user_123',
  ),
);
```

### Branding

```dart
await UseSense.initialize(UseSenseConfig(
  apiKey: 'your_api_key',
  branding: BrandingConfig(
    primaryColor: '#4F63F5',
    buttonRadius: 12,
    logoUrl: 'https://example.com/logo.png',
    fontFamily: 'Inter',
  ),
));
```

## API Reference

### `UseSense.initialize(config)`

Initialize the SDK with your API key and optional configuration.

### `UseSense.startVerification(request)` → `Future<UseSenseResult>`

Launch the verification flow. Throws `UseSenseError` on failure or `UseSenseCancelledException` if cancelled.

### `UseSense.events` → `Stream<UseSenseEvent>`

Stream of SDK lifecycle events (session created, capture started, etc.).

### `UseSense.isInitialized()` → `Future<bool>`

### `UseSense.reset()` → `Future<void>`

## Platform Support

| Platform | Supported |
| -------- | --------- |
| Android  | ✅        |
| iOS      | Planned   |

## License

MIT
