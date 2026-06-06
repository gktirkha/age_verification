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
  /// Returns an [AgeVerificationResult] whose [AgeVerificationResult.status]
  /// indicates the outcome. Other fields are platform-specific and may be null.
  ///
  /// Throws a [PlatformException] if the check fails. The `code` field will be
  /// one of the [AgeVerificationErrorCode] names (e.g. `"networkError"`).
  /// Call [init] first or a `notInitialized` error is thrown.
  Future<AgeVerificationResult> verifyAge({List<int>? ageGates}) async {
    return await _api.verifyAge(ageGates: ageGates);
  }

  /// Releases native resources and resets the singleton.
  ///
  /// On Android this tears down the Play Age Signals manager. On iOS there
  /// is no native resource to release, but the call still completes successfully.
  ///
  /// After this returns, [instance] will create a fresh, uninitialized instance
  /// on next access — call [init] again before calling [verifyAge].
  ///
  /// Throws a [PlatformException] if the native teardown fails; in that case
  /// the singleton is preserved and can be used or disposed again.
  Future<void> dispose() async {
    await _api.dispose();
    _instance = null;
  }
}
