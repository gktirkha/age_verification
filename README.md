# age_verification

[![pub version](https://img.shields.io/pub/v/age_verification)](https://pub.dev/packages/age_verification)

A Flutter plugin for querying platform-level age signals on Android and iOS.

- **Android** — Google Play Age Signals API (`com.google.android.play:age-signals:0.0.3`)
- **iOS** — Apple DeclaredAgeRange framework (iOS 26.0+, requires entitlement)

| Platform | API | Min version |
|---|---|---|
| Android | Google Play Age Signals | Android 6.0 (API 23) |
| iOS | Apple DeclaredAgeRange | iOS 26.0 |

---

## Platform setup

### Android

Add the Play Age Signals dependency to your app's `build.gradle`:

```groovy
implementation("com.google.android.play:age-signals:0.0.3")
```

No permissions or manifest entries are required. The API only returns data for users in applicable jurisdictions (e.g. US states with age verification laws, Brazil).

### iOS

1. **Entitlement** — request the `com.apple.developer.declared-age-range` entitlement from Apple before submitting to the App Store. Add it to your app's `.entitlements` file once approved:

   ```xml
   <key>com.apple.developer.declared-age-range</key>
   <true/>
   ```

2. **iOS 26.0+** — the DeclaredAgeRange framework requires iOS 26. On older OS versions `verifyAge` returns an `apiNotAvailable` error.

3. **Swift Package Manager** — this plugin uses SPM. CocoaPods is not supported.

---

## Usage

```dart
import 'package:age_verification/age_verification.dart';

final plugin = AgeVerification();

// 1. Initialize once (e.g. in initState or app startup)
await plugin.init();

// 2. Query age signals
try {
  final result = await plugin.verifyAge([13, 18]); // ageGates used on iOS only
  print(result.status);   // AgeSignalsStatus
  print(result.ageLower); // e.g. 13
  print(result.ageUpper); // e.g. 17
} on PlatformException catch (e) {
  print(e.code); // AgeVerificationErrorCode name, e.g. "apiNotAvailable"
}
```

### Age gates (iOS only)

Pass 1–3 integer age thresholds to `verifyAge`. The API shows a system prompt asking the user to share their age range relative to those thresholds:

```dart
// Single gate: am I 18 or over?
await plugin.verifyAge([18]);

// Two gates: under 13 / 13–17 / 18+
await plugin.verifyAge([13, 18]);

// Three gates: under 13 / 13–15 / 16–17 / 18+
await plugin.verifyAge([13, 16, 18]);
```

Android ignores `ageGates` — age ranges are determined by Google Play parental controls.

---

## Result

`verifyAge` returns an `AgeVerificationResult`:

| Field | Type | Description |
|---|---|---|
| `status` | `AgeSignalsStatus` | Outcome of the age check |
| `ageLower` | `int?` | Inclusive lower bound of the age range |
| `ageUpper` | `int?` | Inclusive upper bound (`null` for open-ended ranges) |
| `source` | `AgeDeclarationSource?` | Who provided the declaration (iOS only) |
| `installId` | `String?` | Play-generated install identifier (Android only) |

### AgeSignalsStatus values

| Value | Description |
|---|---|
| `verified` | User meets the age requirement |
| `supervised` | User is under parental supervision / below the age gate |
| `supervisedApprovalPending` | Guardian approval requested but not yet responded (Android) |
| `supervisedApprovalDenied` | Guardian denied the request (Android) |
| `declared` | Age self-declared through Google Play (Android) |
| `declined` | User declined to share their age range (iOS) |
| `unknown` | Age signal unavailable or user not in an applicable region |

### AgeDeclarationSource values (iOS only)

| Value | Description |
|---|---|
| `selfDeclared` | User declared their own age |
| `guardianDeclared` | A guardian declared via Family Sharing |

---

## Error codes

Errors are thrown as `PlatformException`. The `code` field is the name of an `AgeVerificationErrorCode` value:

| Code | Description |
|---|---|
| `apiNotAvailable` | API unavailable on this device or region (iOS < 26, sideloaded app, missing entitlement) |
| `notInitialised` | `verifyAge` called before `init` (Android) |
| `initError` | Manager could not be created (Play Services unavailable) |
| `networkError` | No network connection |
| `playServicesError` | Play Services or Play Store issue |
| `sdkVersionOutdated` | Age Signals SDK version no longer supported |
| `apiError` | Unclassified error |

```dart
try {
  await plugin.verifyAge(null);
} on PlatformException catch (e) {
  switch (e.code) {
    case 'apiNotAvailable':
      // Platform doesn't support age verification
    case 'notInitialised':
      // Call init() first
    case 'networkError':
      // Ask user to check connectivity
    default:
      // Handle other errors
  }
}
```

---

## How it works

### Android

`init()` creates an `AgeSignalsManager` via `AgeSignalsManagerFactory`. `verifyAge()` calls `checkAgeSignals()` which queries Google Play for the account's parental control status. Results reflect the device's Google account configuration — no UI is shown by the plugin. The age verification dialog (if any) is presented by Google Play separately.

### iOS

`init()` is a no-op. `verifyAge()` calls `AgeRangeService.shared.requestAgeRange(ageGates:in:)` which presents a system sheet asking the user to share their age range. On iOS 26.2+, `isEligibleForAgeFeatures` is checked first — users in non-applicable regions receive `unknown` status without being prompted.

---

## Testing with mock data

Pass an `AgeVerificationMockConfig` to `init()` to bypass the native API entirely on both platforms — no supervised account, no iOS 26 device, no entitlement required.

```dart
await plugin.init(
  mockConfig: AgeVerificationMockConfig(
    status: AgeSignalsStatus.supervised,
    ageLower: 13,
    ageUpper: 15,
    installId: 'test-install-abc',
  ),
);

final result = await plugin.verifyAge([13, 18]);
// result.status == AgeSignalsStatus.supervised
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
AgeVerificationMockConfig(status: AgeSignalsStatus.verified, ageLower: 18)

// Supervised teen (Android-style)
AgeVerificationMockConfig(
  status: AgeSignalsStatus.supervised,
  ageLower: 13,
  ageUpper: 15,
  installId: 'mock-install-id',
)

// Guardian approval pending
AgeVerificationMockConfig(status: AgeSignalsStatus.supervisedApprovalPending)

// User declined to share (iOS-style)
AgeVerificationMockConfig(status: AgeSignalsStatus.declined)

// Self-declared via iOS (with source)
AgeVerificationMockConfig(
  status: AgeSignalsStatus.verified,
  ageLower: 18,
  source: AgeDeclarationSource.selfDeclared,
)

// Unknown / not in applicable region
AgeVerificationMockConfig(status: AgeSignalsStatus.unknown)
```

### Android — how mock works internally

On Android, `AgeVerificationMockConfig` is translated into an `AgeSignalsResult` and fed into Google's official `FakeAgeSignalsManager`. The result flows through the real `checkAgeSignals()` callback path, so the status-mapping logic is exercised identically to production. No additional gradle dependency is needed.

### Run integration tests

```bash
cd example
flutter test integration_test/plugin_integration_test.dart -d <device-id>
```
