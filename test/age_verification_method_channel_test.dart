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
  // AgeVerificationMockConfig access fields
  // ---------------------------------------------------------------------------
  group('AgeVerificationMockConfig', () {
    test('encodes and decodes access and feature fields', () {
      final config = AgeVerificationMockConfig(
        status: AgeVerificationStatus.unknown,
        accessStatus: AgeSignalsAccessStatus.verificationRequired,
        applicableAgeFeatures: [ApplicableAgeFeature.mandatorySharing],
      );
      expect(AgeVerificationMockConfig.decode(config.encode()), equals(config));
    });

    test('access and feature fields default to null', () {
      final config = AgeVerificationMockConfig(
        status: AgeVerificationStatus.verified,
      );
      expect(config.accessStatus, isNull);
      expect(config.applicableAgeFeatures, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // AgeSignalsAccessStatus / ApplicableAgeFeature
  // ---------------------------------------------------------------------------
  group('AgeSignalsAccessStatus', () {
    test('mirrors Play AgeSignalsStatus', () {
      expect(AgeSignalsAccessStatus.values.map((e) => e.name), [
        'unspecified',
        'shared',
        'notShared',
        'verificationRequired',
      ]);
    });
  });

  group('ApplicableAgeFeature', () {
    test('mirrors Play ApplicableAgeFeature', () {
      expect(ApplicableAgeFeature.values.map((e) => e.name), [
        'mandatorySharing',
      ]);
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
          'playStoreNotFound',
          'networkError',
          'playServicesNotFound',
          'cannotBindToService',
          'playStoreVersionOutdated',
          'playServicesVersionOutdated',
          'clientTransientError',
          'appNotOwned',
          'sdkVersionOutdated',
          'deviceNotSupported',
          'internalError',
          'notInitialized',
          'initError',
          'apiError',
        ]),
      );
    });

    test('has exactly 15 values', () {
      expect(AgeVerificationErrorCode.values.length, 15);
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
