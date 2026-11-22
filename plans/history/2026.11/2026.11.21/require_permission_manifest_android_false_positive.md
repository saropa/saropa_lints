# BUG: `require_permission_manifest_android` — fires although the manifest declares the permission (rule cannot read the manifest)

**Status: Fixed**

Rule: `require_permission_manifest_android`
File: `lib/src/rules/widget/widget_patterns_require_rules.dart`
Severity: False positive
Sites in downstream app: 1 site in 1 file

---

## Summary

The import is reported. The code is correct; each site carries an `// ignore:` workaround.

---

## Attribution Evidence

```bash
grep -rn "'require_permission_manifest_android'" lib/src/rules/
# Expected: lib/src/rules/widget/widget_patterns_require_rules.dart:NN
```

---

## Reproducer

```dart
import 'package:permission_handler/permission_handler.dart'; // LINT, but should NOT lint
// android/app/src/main/AndroidManifest.xml declares <uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

**Frequency:** Only with the pattern above.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the project AndroidManifest.xml already declares the permission. |
| **Actual** | The import is reported. |

---

## Suggested Fix

Read `android/app/src/main/AndroidManifest.xml` from the project root and skip when the matching `uses-permission` exists. Add a fixture for the pattern above to the rule's example fixtures.


Status: Fixed (2026-11-21)
