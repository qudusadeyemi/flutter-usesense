# Sense Flutter Example

Demonstrates plugin initialization, enrollment, authentication, event listening,
and error handling.

## Setup

1. Clone this repository
2. `cd flutter-usesense/example`
3. `flutter pub get`
4. `flutter run` on a physical device (camera required)
5. On first launch, paste your sandbox or production API key from
   [watchtower.usesense.ai](https://watchtower.usesense.ai) into the **API Key**
   field at the top of the app. The key is persisted via `shared_preferences`
   and survives subsequent launches. No source editing required.
6. Flip the **Production** toggle if you're using a production key
   (`sk_prod_*`); leave it off for sandbox (`sk_sandbox_*`).
7. Tap **Enroll** to run a first-time enrollment, or paste an existing
   Identity ID and tap **Authenticate** to run an authentication session.
8. Tap **Client token and embedded capture** to try the client-token start
   (no API key on the device) and the embedded `UseSenseView`. Paste a
   `client_token` your server created, or leave the field empty and the
   screen mints one with the key above (demo only: in production your server
   calls `POST /v1/sessions/create-token`).

The `android/` and `ios/` folders are not committed. Generate them with
`tool/setup_platforms.sh` (from this folder). Besides `flutter create`, it
makes the changes your own app needs too: `minSdk = 28` and a
`FlutterFragmentActivity` on Android; the iOS 16 target, static pod linkage,
and the camera and microphone usage strings on iOS (without those, iOS ends
the app as soon as the capture opens the camera).

## What This Demonstrates

- SDK initialization with sandbox configuration
- Enrollment session (first-time face registration)
- Authentication session (returning user verification with identity ID)
- Client-token sessions via `startVerificationWithToken` (full screen) and
  `UseSenseView.withToken` (embedded)
- The capture embedded in an app screen via `UseSenseView`
- Real-time event streaming via `UseSenseFlutter.onEvent`
- Error handling with retry guidance for all error codes
- Result display with decision badge and session details
- Security reminder that SDK results are for UI feedback only
