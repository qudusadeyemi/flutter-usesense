# Contributing

UseSense Flutter is a proprietary plugin. External contributions are not accepted at this time.

If you encounter a bug or have a feature request, please file a report via [GitHub Issues](../../issues) or email support@usesense.ai.

---

## Maintainer notes: plugin architecture and release process

This section is for internal maintainers. External contributors can ignore it.

### Plugin architecture

`usesense_flutter` is a Pigeon-generated Flutter plugin that wraps the native iOS and Android UseSense SDKs. The layout:

```
flutter-usesense/
├── pigeons/
│   └── usesense_api.dart        # Pigeon interface (source of truth)
├── lib/
│   ├── usesense_flutter.dart    # Public Dart API (hand-written)
│   └── src/
│       └── generated/
│           └── usesense_api.g.dart    # Pigeon-generated Dart
├── ios/
│   └── Classes/
│       ├── UseSenseFlutterPlugin.swift  # Hand-written bridge
│       └── UseSenseApi.g.swift          # Pigeon-generated Swift
├── android/
│   └── src/main/kotlin/com/usesense/flutter/
│       ├── UseSenseFlutterPlugin.kt     # Hand-written bridge
│       └── UseSenseApi.g.kt             # Pigeon-generated Kotlin
└── example/
    └── lib/                     # Reference example app
```

### When to regenerate Pigeon code

Any change to `pigeons/usesense_api.dart` requires regenerating the `.g.*` files:

```bash
dart run pigeon --input pigeons/usesense_api.dart
```

This command regenerates `lib/src/generated/usesense_api.g.dart`, `ios/Classes/UseSenseApi.g.swift`, and `android/src/main/kotlin/com/usesense/flutter/UseSenseApi.g.kt` in one pass. All three must be committed together — never commit a Pigeon interface change without the corresponding generated files, or the plugin will fail to build on the platform whose generated file didn't get refreshed.

The pre-commit reminder: **if you edited `pigeons/usesense_api.dart`, run `dart run pigeon ...` and `git add ios/ android/ lib/src/generated/`** before opening the PR.

### Native SDK version management

The plugin depends on specific minimum versions of the native SDKs:

| Platform | Manifest | Current floor | Recent native release notes |
|----------|----------|---------------|----------------------------|
| iOS | `ios/usesense_flutter.podspec` → `s.dependency 'UseSenseSDK', '~> 4.2'` | 4.2.2 | [iOS CHANGELOG](https://github.com/qudusadeyemi/usesense-ios-sdk/blob/main/CHANGELOG.md) |
| Android | `android/build.gradle.kts` → `implementation("ai.usesense:sdk:4.2.1")` | 4.2.1 | [Android CHANGELOG](https://github.com/qudusadeyemi/usesense-android-sdk/blob/main/CHANGELOG.md) |

When the native SDKs ship a new version:

1. Check the CHANGELOG for each native repo and decide whether the plugin needs to bump (bug fixes usually don't; new public API or removed / renamed symbols do).
2. Update the version strings in the two manifests above.
3. If the native SDK public API changed, update `ios/Classes/UseSenseFlutterPlugin.swift` and `android/src/main/kotlin/com/usesense/flutter/UseSenseFlutterPlugin.kt` to match.
4. Run `flutter analyze` and `flutter test` to catch any Dart-side drift.
5. Bump `pubspec.yaml` version, add a CHANGELOG entry, tag, push.

The plugin version is tracked separately from the native SDK versions (plugin SemVer doesn't follow native SemVer), but the plugin is always published with a pinned native floor in each manifest.

### Release process

1. Create a release-prep PR that bumps:
   - `pubspec.yaml` → `version: X.Y.Z`
   - `ios/usesense_flutter.podspec` → `s.version = 'X.Y.Z'`
   - `android/build.gradle.kts` → `version = "X.Y.Z"`
   - `CHANGELOG.md` → new `[X.Y.Z]` entry at the top
2. Merge the PR.
3. Tag the merge commit: `git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z`.
4. `release.yml` takes over: verifies pubspec version matches the tag, runs the full CI suite, publishes to pub.dev via OIDC, and creates a matching GitHub Release.

If the CI publish step fails, check the `Publish to pub.dev` step's log for the specific error. Most failures are:
- **Version already published**: pub.dev is immutable per-version. Bump to the next patch and re-tag.
- **`dart pub publish --force` failed with authentication error**: pub.dev's OIDC setup for this package hasn't been completed yet. See the next section.

### pub.dev OIDC (one-time setup per package)

pub.dev supports GitHub Actions OIDC authentication, which lets the release workflow publish without any long-lived secret. The first publish of a new package still requires a manual `dart pub publish` from a machine authenticated with `dart pub token add https://pub.dev`, but after that first publish you can wire up OIDC:

1. Go to https://pub.dev/packages/usesense_flutter/admin
2. Under **Automated publishing**, click **Enable publishing from GitHub Actions**
3. Set **Repository**: `qudusadeyemi/flutter-usesense`
4. Set **Tag pattern**: `v*`
5. Save

Subsequent `v*` tag pushes will publish automatically via the `release.yml` workflow without any secrets in the repo.

### Cross-checking with iOS and Android SDK releases

The iOS SDK (`qudusadeyemi/usesense-ios-sdk`) and Android SDK (`qudusadeyemi/usesense-android-sdk`) and React Native wrapper (`qudusadeyemi/react-native-usesense`) ship their own coordinated releases. The Flutter plugin version is decoupled — it's bumped only when there's an API change, new feature, or bug fix that affects the Flutter-facing surface. The native SDK floors in the manifests above are what tie a specific plugin version to a specific native version range.
