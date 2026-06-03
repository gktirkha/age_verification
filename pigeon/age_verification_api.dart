import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/pigeon/age_verification_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/gtirkha/age_verification/pigeon/AgeVerificationApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.gtirkha.age_verification.pigeon',
    ),
    swiftOut:
        'ios/age_verification/Sources/age_verification/pigeon/AgeVerificationApi.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'age_verification',
  ),
)
/// Mock result returned by [AgeVerificationApi.verifyAge] during testing.
///
/// Pass to [AgeVerificationApi.initialize] to enable mock mode on both
/// platforms. The native API is not called — [verifyAge] returns this data
/// directly. Pass `null` to [initialize] for real production behaviour.
class AgeVerificationMockConfig {
  /// Creates an [AgeVerificationMockConfig].
  const AgeVerificationMockConfig({
    required this.status,
    this.ageLower,
    this.ageUpper,
    this.source,
    this.installId,
  });

  /// The status to return from [AgeVerificationApi.verifyAge].
  final AgeVerificationStatus status;

  /// Mocked inclusive lower bound of the age range.
  final int? ageLower;

  /// Mocked inclusive upper bound of the age range.
  final int? ageUpper;

  /// Mocked declaration source (iOS field).
  final AgeDeclarationSource? source;

  /// Mocked install identifier (Android field).
  final String? installId;
}

@HostApi()
abstract class AgeVerificationApi {
  /// Initializes the platform age signals manager.
  ///
  /// Pass [mockConfig] to enable mock mode — both platforms will return the
  /// supplied result from [verifyAge] without calling the native API.
  /// Omit [mockConfig] (or pass null) for real production behaviour.
  @async
  void initialize({AgeVerificationMockConfig? mockConfig});

  @async
  AgeVerificationResult verifyAge(List<int>? ageGates);
}

/// Data returned by the platform after querying age signals.
///
/// Wraps the raw response from the native age verification API.
/// Fields vary by platform; expect nulls where a platform does not
/// provide a particular value or when the user withholds consent.
class AgeVerificationResult {
  /// Creates an [AgeVerificationResult].
  const AgeVerificationResult({
    required this.status,
    this.ageLower,
    this.ageUpper,
    this.source,
    this.installId,
  });

  /// The outcome of the age check as reported by the platform.
  final AgeVerificationStatus status;

  /// Inclusive lower bound of the estimated age range.
  ///
  /// iOS: present when the user grants permission to share their age bracket.
  /// Android: present for family-managed accounts via parental controls.
  /// Null when the user opts out (iOS) or the platform cannot supply the value.
  final int? ageLower;

  /// Inclusive upper bound of the estimated age range.
  ///
  /// iOS: present when the user grants permission to share their age bracket.
  /// Android: present for family-managed accounts via parental controls.
  /// Null when the user opts out (iOS) or the platform cannot supply the value.
  final int? ageUpper;

  /// Who provided the age declaration (iOS only).
  ///
  /// Distinguishes between an age declared by the user themselves and one
  /// entered by a guardian through Family Sharing. Null on Android or when
  /// the user has not shared their age.
  final AgeDeclarationSource? source;

  /// Stable identifier for this app install (Android only).
  ///
  /// Intended for compliance logging and audit trails.
  /// Always null on iOS.
  final String? installId;
}

/// Outcome of an age verification request.
enum AgeVerificationStatus {
  /// The platform confirms the user meets the minimum age requirement.
  ///
  /// Android: parental controls indicate the account is above the threshold.
  /// iOS: the declared age range satisfies all configured age gates.
  verified,

  /// The platform could not produce an age signal.
  ///
  /// Common reasons:
  /// - Parental controls are not configured (Android)
  /// - Verification data is unavailable for this account
  /// - The API is unsupported in the user's region
  unknown,

  /// The user chose not to share their age (iOS only).
  ///
  /// The user was prompted but explicitly declined to reveal their age
  /// range to the app.
  declined,

  /// The user is below the age threshold or under parental supervision.
  ///
  /// Android: the account is family-managed and does not meet the age
  /// requirement. iOS: the declared age range falls below the configured gates.
  supervised,

  /// Supervised user — guardian approval is pending (Android only).
  ///
  /// The account is family-managed and an access request has been dispatched
  /// to the guardian. The guardian has not yet responded.
  supervisedApprovalPending,

  /// Supervised user — guardian denied the request (Android only).
  ///
  /// The account is family-managed and the guardian has explicitly
  /// rejected the access request.
  supervisedApprovalDenied,

  /// Age was self-declared through Google Play (Android only).
  ///
  /// The user completed Google Play's age declaration flow.
  /// Requires age-signals 0.0.3 or later.
  declared,
}

/// Who provided the age declaration (iOS only).
enum AgeDeclarationSource {
  /// The user declared their own age.
  selfDeclared,

  /// A guardian declared the age on the user's behalf via Family Sharing.
  guardianDeclared,
}

/// Error codes reported when an age verification call fails.
enum AgeVerificationErrorCode {
  /// The Age Signals API is not available on this device or region.
  apiNotAvailable,

  /// Google Play Services encountered an error.
  playServicesError,

  /// A network error prevented the request from completing.
  networkError,

  /// The installed Play Services SDK is too old to support Age Signals.
  sdkVersionOutdated,

  /// [AgeVerificationApi.verifyAge] was called before [AgeVerificationApi.initialize].
  notInitialized,

  /// An unexpected error occurred during initialisation.
  initError,

  /// An unclassified API error occurred.
  apiError,
}
