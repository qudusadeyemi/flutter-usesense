#!/usr/bin/env bash
# Generates the example's android/ and ios/ folders (they are gitignored) and
# applies every change an integrator's own app needs, so CI and anyone running
# the example get the same app. Usage, from example/:
#
#   tool/setup_platforms.sh            # both platforms
#   tool/setup_platforms.sh android    # or ios
#
# Each edit mirrors a step in the plugin README. If you add a requirement
# there, add it here too.
set -euo pipefail
cd "$(dirname "$0")/.."

platforms="${1:-android,ios}"
# In-place sed that works with both BSD (macOS) and GNU sed.
sedi() { if sed --version >/dev/null 2>&1; then sed -i "$@"; else sed -i '' "$@"; fi; }

flutter create --org ai.usesense --platforms="$platforms" .
flutter pub get

if [[ "$platforms" == *android* ]]; then
  # The native ai.usesense:sdk requires minSdk 28; flutter's default fails the
  # release manifest merge.
  sedi -E 's/minSdk(Version)? *=? *[a-zA-Z0-9_.().]+/minSdk = 28/' android/app/build.gradle.kts
  # UseSenseView hosts the native UseSenseFragment, which needs a FragmentActivity.
  find android/app/src/main -name MainActivity.kt -exec sed -i.bak \
    -e 's/embedding.android.FlutterActivity/embedding.android.FlutterFragmentActivity/' \
    -e 's/: FlutterActivity()/: FlutterFragmentActivity()/' {} \;
  find android/app/src/main -name 'MainActivity.kt.bak' -delete
fi

if [[ "$platforms" == *ios* ]]; then
  plist=ios/Runner/Info.plist
  # iOS kills the app (TCC privacy violation) the moment the capture opens the
  # camera without these. Found on an iPhone 2026-11-21: the generated example
  # had neither key and crashed on every start.
  for entry in \
    "NSCameraUsageDescription|Sense requires camera access for identity verification." \
    "NSMicrophoneUsageDescription|Sense requires microphone access for audio-based liveness challenges."; do
    key="${entry%%|*}"; value="${entry#*|}"
    /usr/libexec/PlistBuddy -c "Print :$key" "$plist" >/dev/null 2>&1 \
      || /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist"
  done
  # --config-only writes the Podfile, then its pod install fails on the default
  # low platform: tolerate that, then set the platform the plugin needs.
  flutter build ios --no-codesign --config-only || true
  sedi "s/# *platform :ios.*/platform :ios, '16.0'/" ios/Podfile
  # UseSenseSDK vendors static MediaPipe frameworks.
  sedi "s/use_frameworks!.*/use_frameworks! :linkage => :static/" ios/Podfile
  sedi "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;/IPHONEOS_DEPLOYMENT_TARGET = 16.0;/g" ios/Runner.xcodeproj/project.pbxproj
fi
