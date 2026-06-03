## 0.2.1

### iOS
* Added CocoaPods podspec (`ios/age_verification.podspec`) for compatibility with older Flutter tooling that does not support Swift Package Manager

### Example
* Fixed example iOS Xcode project to correctly reference the `age_verification` Swift Package Manager package

## 0.2.0

### Breaking changes
* Renamed `AgeSignalsStatus` → `AgeVerificationStatus` for naming consistency across the public API

## 0.1.0

Initial working release.

### Android
* Integrated Google Play Age Signals API (`com.google.android.play:age-signals:0.0.3`)
* Implements `AgeSignalsManagerFactory`, `AgeSignalsManager.checkAgeSignals()`, and full `AgeSignalsVerificationStatus` mapping
* Reports `ageLower`, `ageUpper`, and `installId` from `AgeSignalsResult`
* Maps all `AgeSignalsException` error codes to typed `AgeVerificationErrorCode` values
* Mock mode uses Google's official `FakeAgeSignalsManager` for accurate simulation

### iOS
* Integrated Apple DeclaredAgeRange framework (iOS 26.0+)
* Calls `AgeRangeService.shared.requestAgeRange(ageGates:in:)` with 1–3 age gates
* Checks `isEligibleForAgeFeatures` on iOS 26.2+ to skip prompt for non-applicable regions
* Maps `AgeRangeDeclaration` (`.selfDeclared`, `.guardianDeclared`) to `AgeDeclarationSource`
* Catches `AgeRangeService.Error.notAvailable` and `.invalidRequest` as typed errors
* Returns `apiNotAvailable` on iOS < 26.0 or when DeclaredAgeRange is not linked
* Uses Swift Package Manager (CocoaPods podspec added in 0.2.1)

### Dart
* Type-safe pigeon channel: `AgeVerificationApi`, `AgeVerificationResult`, `AgeVerificationStatus`, `AgeDeclarationSource`, `AgeVerificationErrorCode`
* Public API: `AgeVerification.init({mockConfig})` and `AgeVerification.verifyAge(ageGates)`
* `AgeVerificationMockConfig` — pass to `init()` to bypass native APIs on both platforms for testing

## 0.0.1

* Initial plugin scaffold.
