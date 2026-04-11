// Minimal smoke tests for the public Dart API of `usesense_flutter`.
//
// These tests deliberately DO NOT exercise the platform channel — every
// method that crosses into native code requires a running Flutter engine
// with the plugin registered, which is only available in a real app or
// an integration test harness. This file exists so that `flutter test`
// exits 0 in CI (the command exits 1 when no `test/` directory is
// present, and pub.dev's automated publishing guide specifically warns
// that packages without tests get dinged in the scoring).
//
// The real end-to-end coverage of the platform channel lives in:
//   * the Pigeon-generated type-safe IPC glue (which runs a compile-
//     time check of every message shape across Dart / Swift / Kotlin);
//   * the example/ app, which is smoke-tested on simulator in CI once
//     per release via the native build jobs in release-ios.yml /
//     release-android.yml on the upstream SDK repos;
//   * the example app's runtime UI, which integrators drive manually
//     to verify a real enrollment flow.
//
// If you add genuine unit tests (e.g. for local-only helpers that don't
// touch the platform channel), drop them in this directory. Each file
// matching `test/**_test.dart` gets picked up by `flutter test`.

import 'package:flutter_test/flutter_test.dart';
import 'package:usesense_flutter/usesense_flutter.dart';

void main() {
  group('UseSenseConfig', () {
    test('requires an apiKey', () {
      const config = UseSenseConfig(apiKey: 'sk_sandbox_test');
      expect(config.apiKey, 'sk_sandbox_test');
    });

    test('defaults environment to auto', () {
      const config = UseSenseConfig(apiKey: 'sk_sandbox_test');
      expect(config.environment, UseSenseEnvironment.auto);
    });

    test('accepts explicit environment overrides', () {
      const sandbox = UseSenseConfig(
        apiKey: 'sk_sandbox_test',
        environment: UseSenseEnvironment.sandbox,
      );
      const production = UseSenseConfig(
        apiKey: 'sk_prod_test',
        environment: UseSenseEnvironment.production,
      );
      expect(sandbox.environment, UseSenseEnvironment.sandbox);
      expect(production.environment, UseSenseEnvironment.production);
    });

    test('baseUrl and branding are nullable and default to null', () {
      const config = UseSenseConfig(apiKey: 'sk_sandbox_test');
      expect(config.baseUrl, isNull);
      expect(config.branding, isNull);
      expect(config.googleCloudProjectNumber, isNull);
    });
  });

  group('VerificationRequest', () {
    test('defaults everything except sessionType', () {
      const request = VerificationRequest(
        sessionType: SessionType.enrollment,
      );
      expect(request.sessionType, SessionType.enrollment);
      expect(request.externalUserId, isNull);
      expect(request.identityId, isNull);
      expect(request.metadata, isNull);
    });

    test('accepts authentication with identityId', () {
      const request = VerificationRequest(
        sessionType: SessionType.authentication,
        identityId: 'idn_abc123',
      );
      expect(request.sessionType, SessionType.authentication);
      expect(request.identityId, 'idn_abc123');
    });
  });

  group('UseSenseEnvironment', () {
    test('has the three expected cases', () {
      expect(UseSenseEnvironment.values, [
        UseSenseEnvironment.sandbox,
        UseSenseEnvironment.production,
        UseSenseEnvironment.auto,
      ]);
    });
  });
}
