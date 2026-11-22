# age_verification

[![pub version](https://img.shields.io/pub/v/age_verification)](https://pub.dev/packages/age_verification)

A Flutter plugin for querying platform-level age signals on Android and iOS.

- **Android** — Google Play Age Signals API (`com.google.android.play:age-signals:0.0.6`)
- **iOS** — Apple DeclaredAgeRange framework (iOS 26.0+, requires entitlement)

| Platform | API | Min version |
|---|---|---|
| Android | Google Play Age Signals | Android 7.0 (API 24) |
| iOS | Apple DeclaredAgeRange | iOS 26.0 |

---

## Platform setup

### Android

No setup is needed — the plugin brings in the Play Age Signals library itself, so you don't add it to your app's `build.gradle`. No permissions or manifest entries are required either. The API only returns data for users in applicable jurisdictions (e.g. US states with age verification laws, Brazil).

### iOS

1. **Entitlement** — request the `com.apple.developer.declared-age-range` entitlement from Apple before submitting to the App Store. Add it to your app's `.entitlements` file once approved:

   ```xml
   <key>com.apple.developer.declared-age-range</key>
   <true/>
   ```

2. **iOS 26.0+** — the DeclaredAgeRange framework requires iOS 26. On older OS versions `verifyAge` returns an `apiNotAvailable` error.

3. **Swift Package Manager** — this plugin uses SPM by default. A CocoaPods podspec is also provided for older Flutter tooling that does not support SPM.

---

## Usage

```dart
import 'package:age_verification/age_verification.dart';

// AgeVerification is a singleton — always use .instance
final plugin = AgeVerification.instance;

// 1. Initialize once (e.g. in initState or app startup)
await plugin.init();

// 2. Query age signals
try {
  final result = await plugin.verifyAge(ageGates: [13, 18]); // ageGates used on iOS only
  print(result.status);   // AgeVerificationStatus
  print(result.ageLower); // e.g. 13
  print(result.ageUpper); // e.g. 17
} on PlatformException catch (e) {
  print(AgeVerification.resolveErrorCode(e.code)); // AgeVerificationErrorCode, e.g. AgeVerificationErrorCode.apiNotAvailable
}
```

### Age gates (iOS only)

Pass 1–3 integer age thresholds to `verifyAge`. The API shows a system prompt asking the user to share their age range relative to those thresholds:

```dart
// Single gate: am I 18 or over?
await plugin.verifyAge(ageGates: [18]);

// Two gates: under 13 / 13–17 / 18+
await plugin.verifyAge(ageGates: [13, 18]);

// Three gates: under 13 / 13–15 / 16–17 / 18+
await plugin.verifyAge(ageGates: [13, 16, 18]);
```

Android ignores `ageGates` — age ranges are determined by Google Play parental controls.

### Skipping the eligibility check (iOS 26.2+)

On iOS 26.2+, `verifyAge` first awaits `AgeRangeService.shared.isEligibleForAgeFeatures` to determine whether the user is in a supported region. If ineligible, the user is never prompted and `unknown` is returned immediately.

Some reports suggest this API can hang indefinitely. If you experience this, pass `skipEligibilityCheck: true` to call `requestAgeRange` directly without the eligibility gate:

```dart
final result = await plugin.verifyAge(
  ageGates: [18],
  skipEligibilityCheck: true, // bypasses isEligibleForAgeFeatures on iOS 26.2+
);
```

The trade-off: users in non-applicable regions will be shown the age-sharing sheet even if the platform would not normally prompt them. Has no effect on Android.

### Requesting age-signal access (Android)

Since age-signals 0.0.4, Google Play only returns the signals a user has agreed to share with your app. Call `requestAgeSignalsAccess()` to show the Play prompt before `verifyAge()`. `getApplicableAgeFeatures()` tells you whether sharing is mandatory for this user:

```dart
final features = await plugin.getApplicableAgeFeatures();
final mandatory = features.contains(ApplicableAgeFeature.mandatorySharing);

final access = await plugin.requestAgeSignalsAccess(); // shows the Play prompt
switch (access) {
  case AgeSignalsAccessStatus.shared:
    final result = await plugin.verifyAge();
    // ...
  case AgeSignalsAccessStatus.notShared:
  case AgeSignalsAccessStatus.verificationRequired:
    // User declined, or must verify their age first. If `mandatory`,
    // restrict age-gated features.
  case AgeSignalsAccessStatus.unspecified:
    // iOS: no prompt is shown here — call verifyAge(), which prompts itself.
}
```

| `AgeSignalsAccessStatus` | Description |
|---|---|
| `shared` | User shared their age signals |
| `notShared` | User did not share their age signals |
| `verificationRequired` | User must verify their age first (regions with mandatory sharing) |
| `unspecified` | No status reported — always returned on iOS |

On iOS, `getApplicableAgeFeatures()` returns an empty list and `requestAgeSignalsAccess()` returns `unspecified` without prompting.

---

## Result

`verifyAge` returns an `AgeVerificationResult`:

| Field | Type | Description |
|---|---|---|
| `status` | `AgeVerificationStatus` | Outcome of the age check |
| `ageLower` | `int?` | Inclusive lower bound of the age range |
| `ageUpper` | `int?` | Inclusive upper bound (`null` for open-ended ranges) |
| `source` | `AgeDeclarationSource?` | Who provided the declaration (iOS only) |
| `installId` | `String?` | Play-generated install identifier (Android only) |

### AgeVerificationStatus values

| Value | Description |
|---|---|
| `verified` | User meets the age requirement |
| `supervised` | User is under parental supervision / below the age gate |
| `supervisedApprovalPending` | Guardian approval requested but not yet responded (Android) |
| `supervisedApprovalDenied` | Guardian denied the request (Android) |
| `declared` | User provided their age to Google themselves; may not be confirmed (Android) |
| `declined` | User declined to share their age range (iOS) |
| `unknown` | Age signal unavailable or user not in an applicable region |

### AgeDeclarationSource values (iOS only)

| Value | Description |
|---|---|
| `selfDeclared` | User declared their own age |
| `guardianDeclared` | A guardian declared via Family Sharing |

---

## Error codes

Errors are thrown as `PlatformException`. The `code` field is the name of an `AgeVerificationErrorCode` value. The Android-specific values mirror Google Play's [`AgeSignalsErrorCode`](https://developer.android.com/google/play/age-signals/reference/com/google/android/play/agesignals/model/AgeSignalsErrorCode) 1:1:

| Code | Description |
|---|---|
| `apiNotAvailable` | API unavailable on this device or region (iOS < 26, sideloaded app, missing entitlement) |
| `notInitialized` | `verifyAge` called before `init` (Android) |
| `initError` | Manager could not be created (Play Services unavailable) |
| `networkError` | No network connection |
| `playStoreNotFound` | No Play Store app found on the device (Android) |
| `playServicesNotFound` | Play Services is not available or too old (Android) |
| `cannotBindToService` | Binding to the Play Store service failed (Android) |
| `playStoreVersionOutdated` | The Play Store app needs to be updated (Android) |
| `playServicesVersionOutdated` | Play Services needs to be updated (Android) |
| `clientTransientError` | Transient error on the client device; retry (Android) |
| `appNotOwned` | App was not installed by Google Play (Android) |
| `sdkVersionOutdated` | Age Signals SDK version no longer supported (Android) |
| `deviceNotSupported` | Device type not supported by Age Signals (Android) |
| `internalError` | Unknown internal error in the Age Signals API (Android) |
| `apiError` | Unclassified error |

```dart
try {
  await plugin.verifyAge();
} on PlatformException catch (e) {
  switch (AgeVerification.resolveErrorCode(e.code)) {
    case AgeVerificationErrorCode.apiNotAvailable:
      // Platform doesn't support age verification
    case AgeVerificationErrorCode.notInitialized:
      // Call init() first
    case AgeVerificationErrorCode.networkError:
      // Ask user to check connectivity
    default:
      // Handle other errors
  }
}
```

---

## How it works

### Android

`init()` creates an `AgeSignalsManager` via `AgeSignalsManagerFactory`. `requestAgeSignalsAccess()` calls `requestAgeSignalsAccess()` on the manager, which shows Google Play's age-sharing prompt over the current Activity. `getApplicableAgeFeatures()` calls `getApplicableAgeFeatures()`. `verifyAge()` calls `checkAgeSignals()` and derives `AgeVerificationStatus` from the returned `ageRangeSource` and `significantChangeStatus`:

| Play signal | `AgeVerificationStatus` |
|---|---|
| `significantChangeStatus` = `PENDING` | `supervisedApprovalPending` |
| `significantChangeStatus` = `DECLINED` | `supervisedApprovalDenied` |
| `ageRangeSource` = `TIER_B` (parent/guardian managed) | `supervised` |
| `ageRangeSource` = `TIER_C` / `TIER_D` (age checked via ID, card, selfie, Digital ID) | `verified` |
| `ageRangeSource` = `TIER_A` (user-provided) | `declared` |
| none | `unknown` |

### iOS

`init()` is a no-op. `verifyAge()` calls `AgeRangeService.shared.requestAgeRange(ageGates:in:)` which presents a system sheet asking the user to share their age range. On iOS 26.2+, `isEligibleForAgeFeatures` is checked first — users in non-applicable regions receive `unknown` status without being prompted. Pass `skipEligibilityCheck: true` to bypass this check and go straight to `requestAgeRange`.

---

## Testing with mock data

Pass an `AgeVerificationMockConfig` to `init()` to bypass the native API entirely on both platforms — no supervised account, no iOS 26 device, no entitlement required.

```dart
await plugin.init(
  mockConfig: AgeVerificationMockConfig(
    status: AgeVerificationStatus.supervised,
    ageLower: 13,
    ageUpper: 15,
    installId: 'test-install-abc',
  ),
);

final result = await plugin.verifyAge(ageGates: [13, 18]);
// result.status == AgeVerificationStatus.supervised
// result.ageLower == 13
```

`verifyAge` returns the mock data instantly — no system sheet is shown on iOS, no Play Services call is made on Android.

To return to real behaviour, call `init()` without `mockConfig`:

```dart
await plugin.init(); // clears mock, uses real native API
```

### Common test scenarios

```dart
// Verified adult
AgeVerificationMockConfig(status: AgeVerificationStatus.verified, ageLower: 18)

// Supervised teen (Android-style)
AgeVerificationMockConfig(
  status: AgeVerificationStatus.supervised,
  ageLower: 13,
  ageUpper: 15,
  installId: 'mock-install-id',
)

// Guardian approval pending
AgeVerificationMockConfig(status: AgeVerificationStatus.supervisedApprovalPending)

// User declined to share (iOS-style)
AgeVerificationMockConfig(status: AgeVerificationStatus.declined)

// Self-declared via iOS (with source)
AgeVerificationMockConfig(
  status: AgeVerificationStatus.verified,
  ageLower: 18,
  source: AgeDeclarationSource.selfDeclared,
)

// Unknown / not in applicable region
AgeVerificationMockConfig(status: AgeVerificationStatus.unknown)

// Mandatory-sharing region where the user declined the Play prompt
AgeVerificationMockConfig(
  status: AgeVerificationStatus.unknown,
  accessStatus: AgeSignalsAccessStatus.notShared,
  applicableAgeFeatures: [ApplicableAgeFeature.mandatorySharing],
)
```

`accessStatus` (default `shared`) is what `requestAgeSignalsAccess()` returns in mock mode, and `applicableAgeFeatures` (default empty) is what `getApplicableAgeFeatures()` returns.

### Android — how mock works internally

On Android, `AgeVerificationMockConfig` is translated into `AgeSignalsResult`, `AgeSignalsAccessResult` and `ApplicableAgeFeaturesResult` values and fed into Google's official `FakeAgeSignalsManager`. Results flow through the real callback paths, so the status-mapping logic is exercised identically to production. No additional gradle dependency is needed.

### Run integration tests

```bash
cd example
flutter test integration_test/plugin_integration_test.dart -d <device-id>
```
