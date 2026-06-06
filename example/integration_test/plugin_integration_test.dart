// Integration tests run against the real host platform, so they exercise the
// full native ↔ Dart pigeon channel end-to-end.
//
// Run on a physical device or simulator:
//   flutter test integration_test/plugin_integration_test.dart

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
      final result = await plugin.verifyAge(ageGates: [13, 18]);
      expect(AgeVerificationStatus.values, contains(result.status));
    } on PlatformException catch (e) {
      final knownCodes = AgeVerificationErrorCode.values.map((c) => c.name);
      expect(knownCodes, contains(e.code));
    }
  });

}
