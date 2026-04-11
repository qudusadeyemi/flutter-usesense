# UseSense Flutter Example

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

## What This Demonstrates

- SDK initialization with sandbox configuration
- Enrollment session (first-time face registration)
- Authentication session (returning user verification with identity ID)
- Real-time event streaming via `UseSenseFlutter.onEvent`
- Error handling with retry guidance for all error codes
- Result display with decision badge and session details
- Security reminder that SDK results are for UI feedback only
