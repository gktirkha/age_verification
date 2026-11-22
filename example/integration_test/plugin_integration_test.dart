// Integration tests run against the real host platform, so they exercise the
// full native ↔ Dart pigeon channel end-to-end.
//
// Run on a physical device or simulator:
//   flutter test integration_test/plugin_integration_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/services.dart';

import 'package:age_verification/age_verification.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final plugin = AgeVerification.instance;

  // ---------------------------------------------------------------------------
  // init
  // ---------------------------------------------------------------------------
  testWidgets('init completes without throwing', (tester) async {
    // On Android this creates the AgeSignalsManager; on iOS it is a no-op.
    // Either way the call must complete successfully.
    await expectLater(plugin.init(), completes);
  });

  // ---------------------------------------------------------------------------
  // verifyAge
  // ---------------------------------------------------------------------------
  testWidgets('verifyAge returns an AgeVerificationResult after init', (
    tester,
  ) async {
    await plugin.init();

    // On Android the result depends on the device's parental-control state.
    // On iOS < 26 it will throw apiNotAvailable.
    // We accept any AgeVerificationResult or a known PlatformException.
    try {
      final result = await plugin.verifyAge();
      expect(AgeVerificationStatus.values, contains(result.status));
    } on PlatformException catch (e) {
      final knownCodes = AgeVerificationErrorCode.values.map((c) => c.name);
      expect(
        knownCodes,
        contains(e.code),
        reason:
            'PlatformException code should be a known AgeVerificationErrorCode',
      );
    }
  });

  testWidgets('verifyAge with iOS age gates returns a result or known error', (
    tester,
  ) async {
    await plugin.init();

    try {
      // isEligibleForAgeFeatures can hang forever on simulators / devices
      // without an Apple account, so skip it in this real-mode smoke test.
      final result = await plugin.verifyAge(
        ageGates: [13, 18],
        skipEligibilityCheck: true,
      );
      expect(AgeVerificationStatus.values, contains(result.status));
    } on PlatformException catch (e) {
      final knownCodes = AgeVerificationErrorCode.values.map((c) => c.name);
      expect(knownCodes, contains(e.code));
    }
  });
  // ---------------------------------------------------------------------------
  // getApplicableAgeFeatures / requestAgeSignalsAccess — real mode
  // ---------------------------------------------------------------------------
  final knownCodes = AgeVerificationErrorCode.values.map((c) => c.name);

  testWidgets('getApplicableAgeFeatures returns a list or known error', (
    tester,
  ) async {
    await plugin.init();
    try {
      final features = await plugin.getApplicableAgeFeatures();
      if (Platform.isIOS) expect(features, isEmpty);
    } on PlatformException catch (e) {
      expect(Platform.isAndroid, isTrue, reason: 'iOS never throws here');
      expect(knownCodes, contains(e.code));
    }
  });

  testWidgets('requestAgeSignalsAccess returns a status or known error', (
    tester,
  ) async {
    await plugin.init();
    try {
      final status = await plugin.requestAgeSignalsAccess();
      if (Platform.isIOS) expect(status, AgeSignalsAccessStatus.unspecified);
    } on PlatformException catch (e) {
      expect(Platform.isAndroid, isTrue, reason: 'iOS never throws here');
      expect(knownCodes, contains(e.code));
    }
  });

  // ---------------------------------------------------------------------------
  // Mock mode — deterministic on both platforms
  // ---------------------------------------------------------------------------
  group('mock mode', () {
    tearDown(() => plugin.init());

    for (final status in AgeVerificationStatus.values) {
      testWidgets('verifyAge round-trips ${status.name}', (tester) async {
        await plugin.init(
          mockConfig: AgeVerificationMockConfig(
            status: status,
            ageLower: 13,
            ageUpper: 15,
            source: AgeDeclarationSource.guardianDeclared,
            installId: 'mock-install',
          ),
        );

        final result = await plugin.verifyAge(ageGates: [13, 18]);

        // Android has no "declined" signal, so it maps to unknown there.
        final expected =
            Platform.isAndroid && status == AgeVerificationStatus.declined
            ? AgeVerificationStatus.unknown
            : status;
        expect(result.status, expected);
        expect(result.ageLower, 13);
        expect(result.ageUpper, 15);
        expect(result.installId, 'mock-install');
        // source is iOS-only.
        expect(
          result.source,
          Platform.isIOS ? AgeDeclarationSource.guardianDeclared : isNull,
        );
      });
    }

    testWidgets('new calls default to shared and no features', (tester) async {
      await plugin.init(
        mockConfig: AgeVerificationMockConfig(
          status: AgeVerificationStatus.verified,
        ),
      );

      expect(await plugin.getApplicableAgeFeatures(), isEmpty);
      expect(
        await plugin.requestAgeSignalsAccess(),
        AgeSignalsAccessStatus.shared,
      );
    });

    testWidgets('getApplicableAgeFeatures returns mocked features', (
      tester,
    ) async {
      await plugin.init(
        mockConfig: AgeVerificationMockConfig(
          status: AgeVerificationStatus.unknown,
          applicableAgeFeatures: [ApplicableAgeFeature.mandatorySharing],
        ),
      );

      expect(await plugin.getApplicableAgeFeatures(), [
        ApplicableAgeFeature.mandatorySharing,
      ]);
    });

    for (final access in AgeSignalsAccessStatus.values) {
      testWidgets('requestAgeSignalsAccess returns ${access.name}', (
        tester,
      ) async {
        await plugin.init(
          mockConfig: AgeVerificationMockConfig(
            status: AgeVerificationStatus.unknown,
            accessStatus: access,
          ),
        );

        expect(await plugin.requestAgeSignalsAccess(), access);
      });
    }
  });
}
