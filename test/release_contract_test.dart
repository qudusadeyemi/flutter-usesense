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

  test('published package requires iOS SDK 4.7.1 and Android SDK 4.8.0', () {
    final podspec = readPackageFile('ios/usesense_flutter.podspec');
    final gradle = readPackageFile('android/build.gradle.kts');

    expect(
      podspec,
      contains("s.dependency 'UseSenseSDK', '~> 4.7.1'"),
      reason: 'The CocoaPods constraint must require 4.7.1 but not 4.8.x.',
    );
    expect(
      gradle,
      contains('implementation("ai.usesense:sdk:4.8.0")'),
      reason: 'The Android artifact must be pinned exactly to 4.8.0, the first '
          'Android SDK that runs face mesh.',
    );
  });
}
