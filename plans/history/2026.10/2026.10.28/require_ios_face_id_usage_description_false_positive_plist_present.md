# BUG: `require_ios_face_id_usage_description` — flags although `NSFaceIDUsageDescription` is in Info.plist

**Status: Open**

Created: 2026-10-28
Rule: `require_ios_face_id_usage_description`
File: `lib/src/rules/platforms/ios_capabilities_permissions_rules.dart` (line ~710)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: 17.0.1-beta.1

---

## Summary

The rule flags every `LocalAuthentication` use. `ios/Runner/Info.plist:143` already contains `NSFaceIDUsageDescription`. The rule's plist check does not detect it. The contacts app source already carries a comment pointing to this file name.

---

## Attribution Evidence

```bash
grep -rn "'require_ios_face_id_usage_description'" lib/src/rules/
# lib/src/rules/platforms/ios_capabilities_permissions_rules.dart:710:    'require_ios_face_id_usage_description',
```

---

## Reproducer

Project with `ios/Runner/Info.plist` containing:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Uses Face ID to unlock protected items.</string>
```

and a Dart file:

```dart
import 'package:local_auth/local_auth.dart';

final LocalAuthentication auth = LocalAuthentication(); // LINT — but should NOT lint
Future<bool> go() => auth.authenticate(localizedReason: 'Unlock'); // LINT — but should NOT lint
```

**Frequency:** Always in this project.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the plist has the key |
| **Actual** | `[require_ios_face_id_usage_description]` on each `LocalAuthentication` expression |

---

## Root Cause

### Hypothesis A: plist lookup fails

The `InfoPlistChecker` early-return guard does not find `ios/Runner/Info.plist`. Likely path resolution from `context.filePath` (Windows paths, package URIs, or the project root not being found from a file in a nested `lib/` folder). On the macOS analysis host the failure still occurs, so check root discovery rather than separators.

---

## Suggested Fix

Walk up from the analyzed file to the first `pubspec.yaml` and read `ios/Runner/Info.plist` from there. Cache per root. Add a fixture with the key present.

---

## Environment

- saropa_lints version: 17.0.1-beta.1
- Triggering project/file: saropa contacts app — `lib/utils/user/security/biometrics.dart:16,54,57,62`
