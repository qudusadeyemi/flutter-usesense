<!--
  Thanks for contributing to the UseSense Flutter plugin.

  External code contributions are not accepted at this time; this
  template is primarily for internal maintainers and sanctioned
  partners. If you're filing a bug report or feature request,
  please open an issue instead.
-->

## Summary

<!-- 1-3 sentences: what does this PR change and why? -->

## Type of change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that changes existing public API)
- [ ] Documentation or tooling only
- [ ] Release prep (version bump + CHANGELOG entry)

## Checklist

- [ ] `flutter analyze --fatal-infos --fatal-warnings` passes locally
- [ ] `dart format --set-exit-if-changed .` passes (no reformatting needed)
- [ ] `flutter test` passes
- [ ] `flutter pub publish --dry-run` passes (no publishing warnings)
- [ ] Example app (`cd example && flutter run`) still launches and runs enrollment + authentication flows
- [ ] Any new public Dart API has doc comments
- [ ] `CHANGELOG.md` has been updated for user-visible changes
- [ ] `pubspec.yaml` version has been bumped if this is a release PR
- [ ] If Pigeon interface (`pigeons/usesense_api.dart`) was changed, the generated `.g.dart`, `.g.swift`, and `.g.kt` files have been regenerated via `dart run pigeon --input pigeons/usesense_api.dart`
- [ ] No secrets, API keys, or signing identities committed

## Testing notes

<!--
  Describe how you tested this locally. Note which iOS / Android
  versions you smoke-tested on, and whether native SDK versions
  needed to be updated in the podspec / Gradle alongside this PR.
-->

## Related issues

<!-- Closes #123, relates to #456 -->
