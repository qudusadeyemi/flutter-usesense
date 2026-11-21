import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageRoot = Directory.current;

  String readPackageFile(String path) =>
      File('${packageRoot.path}/$path').readAsStringSync();

  test('published package version declarations stay aligned', () {
    final pubspec = readPackageFile('pubspec.yaml');
    final podspec = readPackageFile('ios/usesense_flutter.podspec');
    final gradle = readPackageFile('android/build.gradle.kts');
    final packageVersion = RegExp(
      r'^version:\s*(\S+)$',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);

    expect(packageVersion, isNotNull);
    expect(podspec, contains("s.version          = '$packageVersion'"));
    expect(gradle, contains('version = "$packageVersion"'));
  });

  // Which native versions are pinned is checked against Maven Central and
  // CocoaPods by scripts/native_pins.py (CI: native-pins.yml), so no version
  // number is repeated here to drift. This only checks the pins' shape.
  test('native SDK pins have the shape the release relies on', () {
    final podspec = readPackageFile('ios/usesense_flutter.podspec');
    final gradle = readPackageFile('android/build.gradle.kts');

    expect(
      RegExp(r"s\.dependency 'UseSenseSDK', '~> \d+\.\d+\.\d+'")
          .hasMatch(podspec),
      isTrue,
      reason: 'iOS: pin with ~> A.B.C so the patch range is explicit.',
    );
    expect(
      RegExp(r'implementation\("ai\.usesense:sdk:\d+\.\d+\.\d+"\)')
          .hasMatch(gradle),
      isTrue,
      reason: 'Android: pin an exact version.',
    );
  });
}
