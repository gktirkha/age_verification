import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:age_verification/age_verification.dart';
import 'package:age_verification/src/pigeon/age_verification_api.g.dart'
    show AgeVerificationApi;

const _initChannel =
    'dev.flutter.pigeon.age_verification.AgeVerificationApi.initialize';
const _verifyAgeChannel =
    'dev.flutter.pigeon.age_verification.AgeVerificationApi.verifyAge';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Reuse the pigeon codec so our mock replies are encoded identically to
  // what the real host platform would send.
  final codec = AgeVerificationApi.pigeonChannelCodec;

  void mockSuccess(String channel, {Object? reply}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          channel,
          (message) async => codec.encodeMessage([reply]),
        );
  }

  void mockError(
    String channel, {
    required String code,
    String? message,
    Object? details,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          channel,
          (msg) async => codec.encodeMessage([code, message, details]),
        );
  }

  void clearMock(String channel) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel, null);
  }

  // ---------------------------------------------------------------------------
  // AgeVerificationResult model
  // ---------------------------------------------------------------------------
  group('AgeVerificationResult', () {
    test('encodes and decodes all fields correctly', () {
      final result = AgeVerificationResult(
        status: AgeVerificationStatus.verified,
        ageLower: 18,
        ageUpper: 24,
        source: AgeDeclarationSource.selfDeclared,
        installId: 'install-abc',
      );
      expect(AgeVerificationResult.decode(result.encode()), equals(result));
    });

    test('encodes and decodes with null optional fields', () {
      final result = AgeVerificationResult(
        status: AgeVerificationStatus.unknown,
      );
      final decoded = AgeVerificationResult.decode(result.encode());
      expect(decoded.status, AgeVerificationStatus.unknown);
      expect(decoded.ageLower, isNull);
      expect(decoded.ageUpper, isNull);
      expect(decoded.source, isNull);
      expect(decoded.installId, isNull);
    });

    test('equality holds for identical values', () {
      final a = AgeVerificationResult(
        status: AgeVerificationStatus.supervised,
        ageLower: 13,
        ageUpper: 17,
      );
      final b = AgeVerificationResult(
        status: AgeVerificationStatus.supervised,
        ageLower: 13,
        ageUpper: 17,
      );
      expect(a, equals(b));
    });

    test('equality fails when status differs', () {
      expect(
        AgeVerificationResult(status: AgeVerificationStatus.verified),
        isNot(
          equals(AgeVerificationResult(status: AgeVerificationStatus.declined)),
        ),
      );
    });

    test('equality fails when ageLower differs', () {
      final a = AgeVerificationResult(
        status: AgeVerificationStatus.supervised,
        ageLower: 13,
      );
      final b = AgeVerificationResult(
        status: AgeVerificationStatus.supervised,
        ageLower: 18,
      );
      expect(a, isNot(equals(b)));
    });

    test('guardianDeclared source encodes and decodes', () {
      final result = AgeVerificationResult(
        status: AgeVerificationStatus.verified,
        source: AgeDeclarationSource.guardianDeclared,
      );
      expect(
        AgeVerificationResult.decode(result.encode()).source,
        AgeDeclarationSource.guardianDeclared,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // AgeVerification.resolveErrorCode
  // ---------------------------------------------------------------------------
  group('AgeVerification.resolveErrorCode', () {
    test('resolves a known error code name to its enum value', () {
      expect(
        AgeVerification.resolveErrorCode('apiNotAvailable'),
        AgeVerificationErrorCode.apiNotAvailable,
      );
    });

    test('resolves every AgeVerificationErrorCode value by its name', () {
      for (final code in AgeVerificationErrorCode.values) {
        expect(AgeVerification.resolveErrorCode(code.name), code);
      }
    });

    test('returns null for an unrecognized code', () {
      expect(AgeVerification.resolveErrorCode('notARealCode'), isNull);
    });

    test('returns null for a null code', () {
      expect(AgeVerification.resolveErrorCode(null), isNull);
    });

    test('is case-sensitive', () {
      expect(AgeVerification.resolveErrorCode('APINOTAVAILABLE'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // AgeVerification.init
  // ---------------------------------------------------------------------------
  group('AgeVerification.init', () {
    tearDown(() => clearMock(_initChannel));

    test('sends message to the correct pigeon channel', () async {
      bool called = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(_initChannel, (message) async {
            called = true;
            return codec.encodeMessage([null]);
          });

      await AgeVerification.instance.init();
      expect(called, isTrue);
    });

    test('completes without error on success reply', () async {
      mockSuccess(_initChannel);
      await expectLater(AgeVerification.instance.init(), completes);
    });

    test('throws PlatformException with correct code on error reply', () async {
      mockError(
        _initChannel,
        code: 'INIT_ERROR',
        message: 'Play Services unavailable',
      );

      await expectLater(
        AgeVerification.instance.init(),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'INIT_ERROR')
              .having((e) => e.message, 'message', 'Play Services unavailable'),
        ),
      );
    });

    test(
      'throws PlatformException with apiNotAvailable on unavailable error',
      () async {
        mockError(_initChannel, code: 'API_NOT_AVAILABLE');

        await expectLater(
          AgeVerification.instance.init(),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'API_NOT_AVAILABLE',
            ),
          ),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // AgeVerification.verifyAge
  // ---------------------------------------------------------------------------
  group('AgeVerification.verifyAge', () {
    tearDown(() => clearMock(_verifyAgeChannel));

    test('sends message to the correct pigeon channel', () async {
      bool called = false;
      final reply = AgeVerificationResult(
        status: AgeVerificationStatus.verified,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(_verifyAgeChannel, (message) async {
            called = true;
            return codec.encodeMessage([reply]);
          });

      await AgeVerification.instance.verifyAge();
      expect(called, isTrue);
    });

    test('forwards age gates to the channel', () async {
      List<Object?>? capturedArgs;
      final reply = AgeVerificationResult(
        status: AgeVerificationStatus.verified,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(_verifyAgeChannel, (message) async {
            capturedArgs = codec.decodeMessage(message) as List<Object?>;
            return codec.encodeMessage([reply]);
          });

      await AgeVerification.instance.verifyAge(ageGates: [13, 18]);
      expect(capturedArgs, isNotNull);
      expect(capturedArgs![0], equals([13, 18]));
    });

    test('forwards null age gates to the channel', () async {
      List<Object?>? capturedArgs;
      final reply = AgeVerificationResult(
        status: AgeVerificationStatus.unknown,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(_verifyAgeChannel, (message) async {
            capturedArgs = codec.decodeMessage(message) as List<Object?>;
            return codec.encodeMessage([reply]);
          });

      await AgeVerification.instance.verifyAge();
      expect(capturedArgs![0], isNull);
    });

    test('returns result with correct status', () async {
      final expected = AgeVerificationResult(
        status: AgeVerificationStatus.supervised,
        ageLower: 13,
        ageUpper: 17,
      );
      mockSuccess(_verifyAgeChannel, reply: expected);

      final result = await AgeVerification.instance.verifyAge();
      expect(result.status, AgeVerificationStatus.supervised);
      expect(result.ageLower, 13);
      expect(result.ageUpper, 17);
    });

    test('returns result with source and installId', () async {
      final expected = AgeVerificationResult(
        status: AgeVerificationStatus.verified,
        source: AgeDeclarationSource.guardianDeclared,
        installId: 'device-xyz',
      );
      mockSuccess(_verifyAgeChannel, reply: expected);

      final result = await AgeVerification.instance.verifyAge();
      expect(result.source, AgeDeclarationSource.guardianDeclared);
      expect(result.installId, 'device-xyz');
    });

    test('throws PlatformException on error reply', () async {
      mockError(
        _verifyAgeChannel,
        code: 'NOT_INITIALIZED',
        message: 'Call init() first',
      );

      await expectLater(
        AgeVerification.instance.verifyAge(),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'NOT_INITIALIZED')
              .having((e) => e.message, 'message', 'Call init() first'),
        ),
      );
    });

    test('throws PlatformException with network error code', () async {
      mockError(_verifyAgeChannel, code: 'NETWORK_ERROR');

      await expectLater(
        AgeVerification.instance.verifyAge(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'NETWORK_ERROR',
          ),
        ),
      );
    });
  });
}
