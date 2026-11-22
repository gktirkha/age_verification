import 'package:flutter/services.dart';

import './pigeon/age_verification_api.g.dart';

/// Entry point for querying platform age signals.
///
/// Call [init] once — typically during app startup — before calling [verifyAge].
/// Both methods communicate with the native platform via Pigeon and may throw
/// a [PlatformException] whose `code` maps to an [AgeVerificationErrorCode] value.
class AgeVerification {
  AgeVerification._();

  /// The singleton instance of [AgeVerification].
  ///
  /// Created lazily on first access. Use this to call [init] and [verifyAge].
  static AgeVerification get instance => _instance ??= ._();

  static AgeVerification? _instance;

  final _api = AgeVerificationApi();

  /// Initializes the underlying platform age signals manager.
  ///
  /// Pass [mockConfig] to enable mock mode — [verifyAge] will return the
  /// supplied data on both platforms without touching any native API.
  /// Omit [mockConfig] for real production behaviour.
  ///
  /// Must be called before [verifyAge]. On Android this sets up the
  /// Play Age Signals manager; on iOS no additional setup is required
  /// but the call still completes successfully.
  ///
  /// Throws a [PlatformException] with code [AgeVerificationErrorCode.initError]
  /// if the manager cannot be created (e.g. Play Services unavailable).
  Future<void> init({AgeVerificationMockConfig? mockConfig}) async {
    return await _api.initialize(mockConfig: mockConfig);
  }

  /// Queries the platform for age signals and returns the result.
  ///
  /// [ageGates] is an optional list of age thresholds (e.g. `[13, 18]`) used
  /// on iOS to determine which age bracket the user falls into. Android ignores
  /// this parameter — age ranges are determined by Google Play parental controls.
  ///
  /// [skipEligibilityCheck] bypasses the `isEligibleForAgeFeatures` check on
  /// iOS 26.2+. Set to `true` to skip the eligibility gate and call
  /// `requestAgeRange` directly — useful if you find `isEligibleForAgeFeatures`
  /// hangs or is unreliable in your region. Has no effect on Android.
  ///
  /// Returns an [AgeVerificationResult] whose [AgeVerificationResult.status]
  /// indicates the outcome. Other fields are platform-specific and may be null.
  ///
  /// Throws a [PlatformException] if the check fails. The `code` field will be
  /// one of the [AgeVerificationErrorCode] names (e.g. `"networkError"`).
  /// Call [init] first or a `notInitialized` error is thrown.
  Future<AgeVerificationResult> verifyAge({
    List<int>? ageGates,
    bool skipEligibilityCheck = false,
  }) async {
    return await _api.verifyAge(
      ageGates: ageGates,
      skipEligibilityCheck: skipEligibilityCheck,
    );
  }

  /// Returns the age-related features that apply to the current user.
  ///
  /// **Android:** contains [ApplicableAgeFeature.mandatorySharing] when the
  /// user is in a region where sharing age signals is mandatory (e.g. US-TX);
  /// empty otherwise. Use this to decide whether to call
  /// [requestAgeSignalsAccess] before [verifyAge].
  ///
  /// **iOS:** always returns an empty list (or the mocked value in mock mode).
  ///
  /// Throws a [PlatformException] whose `code` is an [AgeVerificationErrorCode]
  /// name. Call [init] first or a `notInitialized` error is thrown.
  Future<List<ApplicableAgeFeature>> getApplicableAgeFeatures() async {
    return await _api.getApplicableAgeFeatures();
  }

  /// Shows the Google Play prompt asking the user to share their age range
  /// with this app, and returns the resulting [AgeSignalsAccessStatus].
  ///
  /// **Android:** since age-signals 0.0.4, `verifyAge` only returns signals
  /// the user has agreed to share — call this first. Returns
  /// [AgeSignalsAccessStatus.shared] once the user shares,
  /// [AgeSignalsAccessStatus.notShared] if they decline, or
  /// [AgeSignalsAccessStatus.verificationRequired] if they must verify their
  /// age first (regions with mandatory sharing). Needs a foreground Activity.
  ///
  /// **iOS:** returns [AgeSignalsAccessStatus.unspecified] without prompting;
  /// the iOS age-range prompt is shown by [verifyAge] itself.
  ///
  /// Throws a [PlatformException] whose `code` is an [AgeVerificationErrorCode]
  /// name. Call [init] first or a `notInitialized` error is thrown.
  Future<AgeSignalsAccessStatus> requestAgeSignalsAccess() async {
    return await _api.requestAgeSignalsAccess();
  }

  /// Resolves a raw [PlatformException.code] string into an
  /// [AgeVerificationErrorCode], or `null` if it doesn't match a known value.
  static AgeVerificationErrorCode? resolveErrorCode(String? code) {
    if (code == null) {
      return null;
    }
    return AgeVerificationErrorCode.values
        .cast<AgeVerificationErrorCode?>()
        .firstWhere((value) => code == value?.name, orElse: () => null);
  }
}
