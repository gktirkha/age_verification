import 'package:flutter_test/flutter_test.dart';
import 'package:age_verification/age_verification.dart';

void main() {
  // ---------------------------------------------------------------------------
  // AgeVerificationStatus
  // ---------------------------------------------------------------------------
  group('AgeVerificationStatus', () {
    test('contains all expected values', () {
      final names = AgeVerificationStatus.values.map((e) => e.name).toList();
      expect(
        names,
        containsAll([
          'verified',
          'unknown',
          'declined',
          'supervised',
          'supervisedApprovalPending',
          'supervisedApprovalDenied',
          'declared',
        ]),
      );
    });

    test('has exactly 7 values', () {
      expect(AgeVerificationStatus.values.length, 7);
    });
  });

  // ---------------------------------------------------------------------------
  // AgeDeclarationSource
  // ---------------------------------------------------------------------------
  group('AgeDeclarationSource', () {
    test('contains all expected values', () {
      final names = AgeDeclarationSource.values.map((e) => e.name).toList();
      expect(names, containsAll(['selfDeclared', 'guardianDeclared']));
    });

    test('has exactly 2 values', () {
      expect(AgeDeclarationSource.values.length, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // AgeVerificationErrorCode
  // ---------------------------------------------------------------------------
  group('AgeVerificationErrorCode', () {
    test('contains all expected values', () {
      final names = AgeVerificationErrorCode.values.map((e) => e.name).toList();
      expect(
        names,
        containsAll([
          'apiNotAvailable',
          'playServicesError',
          'networkError',
          'sdkVersionOutdated',
          'notInitialized',
          'initError',
          'apiError',
        ]),
      );
    });

    test('has exactly 7 values', () {
      expect(AgeVerificationErrorCode.values.length, 7);
    });

    test('enum names are non-empty camelCase strings', () {
      for (final code in AgeVerificationErrorCode.values) {
        expect(code.name, isNotEmpty);
        expect(
          code.name[0],
          equals(code.name[0].toLowerCase()),
          reason: '${code.name} should start with a lowercase letter',
        );
      }
    });
  });
}
