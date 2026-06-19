# BUG: `require_permission_status_check` — Fires on any method named `startRecording()`, including a plain in-process query recorder

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-19
Rule: `require_permission_status_check`
File: `lib/src/rules/network/api_network_rules.dart` (line ~3197 — `_gatedFeatures` set entry; reported at line ~3222)
Severity: False positive — High (name-only heuristic matches an unrelated domain method; forces `// ignore:` workaround)
Rule version: v4 | Since: v2.3.0 | Updated: v4.13.0

---

## Summary

The rule fires on a call to a method named `startRecording()` on the assumption that it begins audio/video capture requiring a prior OS permission-status check. In the triggering code `startRecording()` is a method on a plain in-process query-recorder object that records executed SQL/query events in memory for a "DVR" / Query-Replay debug feature. It touches no microphone, camera, or any platform permission API. The rule matches on the bare method name alone — it does not check the receiver's resolved static type or whether any permission/media package (`permission_handler`, `camera`, `record`, etc.) is involved.

Expected: no diagnostic. Actual: `[require_permission_status_check]` reported at the call.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`.

```bash
# Positive — rule IS defined here
grep -rn "'require_permission_status_check'" lib/src/rules/
# lib/src/rules/network/api_network_rules.dart:3167:    'require_permission_status_check',

# Negative — rule is NOT defined in the triggering sibling repo
grep -rn "require_permission_status_check" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches (the string appears only in that project's analysis_options.yaml)
```

**Emitter registration:** `lib/src/rules/network/api_network_rules.dart:3166-3172` (the `_code` `LintCode`)
**Rule class:** `RequirePermissionStatusCheckRule` (`lib/src/rules/network/api_network_rules.dart:3151`) — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (saropa_lints `custom_lint` plugin)

---

## Reproducer

Minimal Dart code that triggers the bug. Extracted from `saropa_drift_advisor/lib/src/server/dvr_handler.dart`.

```dart
// _recorder is a QueryRecorder: it records executed SQL/query events in memory.
// No microphone, camera, or platform permission API is involved.
class DvrHandler {
  final QueryRecorder _recorder;

  DvrHandler(this._recorder);

  Future<void> handleStart(HttpResponse response) async {
    _recorder.startRecording(); // LINT require_permission_status_check — but this is DB query recording, not media capture
    // ... writes a JSON response ...
  }
}

class QueryRecorder {
  void startRecording() {
    // begins capturing query events into an in-memory buffer; no OS permission needed
  }
}
```

**Frequency:** Always — for any method named (or matching an exact name in `_gatedFeatures`, including `startRecording`) regardless of the receiver's type.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — no camera/mic/platform permission is involved; the receiver is an app-domain `QueryRecorder` type |
| **Actual** | `[require_permission_status_check] Accessing camera, location, or other gated features without checking permission status ... {v4}` reported at the `startRecording()` call |

---

## AST Context

```
ClassDeclaration (DvrHandler)
  └─ MethodDeclaration (handleStart)
      └─ BlockFunctionBody
          └─ Block
              └─ ExpressionStatement
                  └─ MethodInvocation (_recorder.startRecording())  ← node reported here
                      ├─ target: SimpleIdentifier (_recorder)   staticType: QueryRecorder
                      └─ methodName: SimpleIdentifier (startRecording)
```

The rule registers on `MethodInvocation` and reads only `node.methodName.name`. The `target` (`_recorder`, whose `staticType` is the app-domain `QueryRecorder`) is never consulted.

---

## Root Cause

The detection in `RequirePermissionStatusCheckRule.runWithReporter` (`lib/src/rules/network/api_network_rules.dart:3200-3224`) is a pure method-name match against a hardcoded string set, with no receiver-type or package check.

```dart
context.addMethodInvocation((MethodInvocation node) {
  final methodName = node.methodName.name;       // line 3206

  if (!_gatedFeatures.contains(methodName)) {    // line 3208 — name-only gate
    return;
  }

  // Look for permission check in parent method
  final methodDeclaration = node.thisOrAncestorOfType<MethodDeclaration>(); // 3213
  if (methodDeclaration == null) return;

  final bodySource = methodDeclaration.body.toSource().toLowerCase();       // 3216

  if (_permissionCheckBodyPatterns.any((p) => p.hasMatch(bodySource))) {    // 3218
    return;
  }

  reporter.atNode(node);                          // line 3222
});
```

`_gatedFeatures` (`lib/src/rules/network/api_network_rules.dart:3184-3198`) is:

```dart
static const _gatedFeatures = <String>{
  'getCurrentPosition',
  'getLastKnownPosition',
  'takePicture',
  'pickImage',
  'scanBarcodes',
  'startScan',
  'startListening',
  'requestContactsPermission',
  'getContacts',
  'openCamera',
  'accessMicrophone',
  'recordAudio',
  'startRecording',   // ← line 3197: matches ANY method with this name
};
```

### Hypothesis A: name-only match, no receiver-type resolution (confirmed)

The only gate before reporting is `_gatedFeatures.contains(methodName)`. The rule never inspects `node.target.staticType` and never checks whether the target type originates from a media/permission package. So any call to a method named `startRecording` — or any other name in the set, e.g. `startScan`, `startListening`, `getContacts` — fires regardless of receiver. A `QueryRecorder.startRecording()` (in-memory DB query capture) is indistinguishable to the rule from a media-recorder's `startRecording()`. This is the same class of pitfall the guide lists ("Checking `node.name` instead of resolved element").

### Hypothesis B: body-source escape hatch is the only suppression (confirmed, but insufficient)

The single way to silence the rule short of `// ignore:` is to make the enclosing method body match one of `_permissionCheckBodyPatterns` (`lib/src/rules/network/api_network_rules.dart:3174-3182`, e.g. contains `isgranted`, `haspermission`, `.request()`). Code that legitimately has nothing to do with permissions cannot satisfy that without writing misleading permission-shaped text, so the false positive forces a `// ignore:` workaround.

---

## Suggested Fix

Gate the rule on the receiver's resolved type / originating package so it fires only when the call target resolves to a known media/permission API, instead of on bare method-name match.

In `RequirePermissionStatusCheckRule.runWithReporter` (`lib/src/rules/network/api_network_rules.dart:3205-3223`), after the name gate at line 3208 and before reporting at line 3222, add a receiver-type check:

1. Read `node.target?.staticType` (and/or `node.methodName.staticElement?.enclosingElement` / its library) to resolve the receiver type and the declaring library/package URI.
2. Only continue when the resolved type or its declaring package is one of the known permission/media sources — e.g. types from `camera`, `record`, `image_picker`, `geolocator`, `mobile_scanner` / `barcode_scan`, `speech_to_text`, `flutter_contacts` / `contacts_service`, `permission_handler`. Add a `Set<String>` of recognized package URI prefixes (mirroring the existing `_permissionTypeOrSource` / `_permissionSourceLower` regex approach used by `RequirePermissionRationaleRule` at `lib/src/rules/network/api_network_rules.dart:3109-3114`).
3. If the receiver type cannot be resolved to a known permission/media source, `return` without reporting.

This keeps the genuine cases (a real `CameraController.takePicture()`, a `record` package recorder's `startRecording()`) while excluding app-domain methods that merely share a name. Reuse the package/type matching pattern already present in the sibling `RequirePermissionRationaleRule` (`_permissionTypeOrSource`, `_permissionSourceLower`) rather than introducing a new mechanism.

---

## Fixture Gap

The fixture at `example*/lib/network/require_permission_status_check_fixture.dart` should include:

1. **`QueryRecorder.startRecording()` (in-memory DB query recorder, no permission API)** — expect NO lint
2. **A real `record`-package / media recorder's `startRecording()`** — expect LINT (no preceding permission check)
3. **`startScan()` / `startListening()` / `getContacts()` on an unrelated app-domain object** — expect NO lint (same name-collision class)
4. **`CameraController.takePicture()` without permission check** — expect LINT (positive control still fires after the fix)

---

## Changes Made

`lib/src/rules/network/api_network_rules.dart` — `RequirePermissionStatusCheckRule`:

1. Added a `_gatedFeatureTypeOrSource` regex that matches receiver static types / source tokens from known media/permission packages (camera, geolocator, image picker, scanner, speech, audio recorder, contacts, permission, microphone). Tokens that would collide with unrelated types are word-bounded — `\brecord\b` matches the `record` package's `Record` class but NOT `QueryRecorder`.
2. After the existing name gate and before reporting, the rule now reads `node.target` and requires its `staticType.toString()` OR `toSource()` to match `_gatedFeatureTypeOrSource`; otherwise it returns without reporting. This mirrors the receiver-type gate the sibling `RequireNotificationPermissionAndroid13Rule` already uses.

A call whose receiver type cannot be resolved to a known media/permission source (e.g. `QueryRecorder.startRecording()`) is no longer flagged. Genuine `Geolocator`/`CameraController`/`AudioRecorder` calls without a permission check still fire.

---

## Tests Added

- `test/rules/network/api_network_fp_test.dart` — new `require_permission_status_check` group (resolved-AST harness):
  - PIN positive: `AudioRecorder.startRecording()` in a method, no permission check → still fires.
  - FP: `QueryRecorder.startRecording()` → silent.
  - FP: `getContacts()` / `startScan()` on an unrelated app-domain object → silent.
- `example/lib/api_network/require_permission_status_check_fixture.dart` — added `QueryRecorder` (good: name-collision, no lint) and `AudioRecorder` in `_AudioCaller.capture()` (bad: expect_lint still fires).

Verified: `dart test test/rules/network/api_network_fp_test.dart` — all pass; `dart analyze` of the three changed files — clean.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 14.0.3
- Dart SDK version: 3.12.1
- custom_lint version: via custom_lint CLI
- Triggering project/file: `saropa_drift_advisor` — `lib/src/server/dvr_handler.dart` (`QueryRecorder.startRecording()`)

---

## Finish Report (2026-06-19)

### Defect

`require_permission_status_check` reported any `MethodInvocation` whose method name appeared in a hardcoded `_gatedFeatures` set (`startRecording`, `startScan`, `getContacts`, `takePicture`, and similar), with no inspection of the receiver. The name-only heuristic matched unrelated app-domain methods that merely share a name — e.g. an in-process `QueryRecorder.startRecording()` that buffers SQL events in memory and touches no camera, microphone, or OS permission. The only suppression short of `// ignore:` was making the enclosing method body match a permission-shaped regex, which legitimate non-permission code cannot do without writing misleading text.

### Fix

`RequirePermissionStatusCheckRule.runWithReporter` (`lib/src/rules/network/api_network_rules.dart`) now gates on the receiver after the name match and before reporting:

- A new `_gatedFeatureTypeOrSource` regex matches type/source tokens of known media/permission sources (camera, geolocator, image picker, scanner, speech, audio recorder, contacts, permission, microphone).
- The rule reads `node.target`; if it is null, or neither `target.staticType.toString()` nor `target.toSource()` (lowercased) matches the regex, the rule returns without reporting.
- Collision-prone tokens are word-bounded (`\brecord\b`, `\bpicker\b`, `\bposition\b`, `\bscanner\b`, `\bspeech\b`) so the `record` package's `Record` class matches while `QueryRecorder` does not.

This mirrors the receiver-type gate the sibling `RequireNotificationPermissionAndroid13Rule` already applied in the same file. Genuine `Geolocator`, `CameraController`, `ImagePicker`, and `AudioRecorder` calls without a preceding permission check still fire.

### Verification

- `test/rules/network/api_network_fp_test.dart` gained a `require_permission_status_check` group run through the resolved-AST harness: a media `AudioRecorder.startRecording()` in a class method still fires (positive control); `QueryRecorder.startRecording()` and `getContacts()`/`startScan()` on an unrelated type stay silent.
- The fixture `example/lib/api_network/require_permission_status_check_fixture.dart` documents both the silent name-collision case and the still-firing media-recorder case.
- `dart test` over the three affected api_network test files passes (117 tests). `dart analyze` of the changed source, test, and fixture is clean.

### Known limitation (pre-existing, unchanged)

The rule only reports when the gated call has an enclosing `MethodDeclaration` (`thisOrAncestorOfType<MethodDeclaration>()`); a gated call inside a top-level function is not flagged. This predates the fix and was left unchanged.
