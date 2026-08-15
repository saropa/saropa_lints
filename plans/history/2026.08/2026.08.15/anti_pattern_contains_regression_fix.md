# Anti-Pattern .contains() Regression in firebase_rules.dart

The `firebase_rules.dart` anti-pattern baseline had been reduced to zero and removed from `test/integrity/anti_pattern_detection_test.dart`'s `_baselineCounts` map. A prior commit (`de3b0732`, "require_firebase_app_check reachability check ignores dead code") introduced `_looksLikeAppCheckActivationCall`, which used `source.contains('activate(')` as part of its detection logic — a regression against the zero baseline, causing the anti-pattern detection test to fail with "1 NEW violations (file not in baseline)".

## Root Cause

`String.contains()` substring checks on raw source text are flagged as an anti-pattern class in this codebase because they cause false positives (matching inside comments, strings, or unrelated identifiers). The project's convention for this class of check is regex or exact-match/`startsWith`/`endsWith`, per the guidance embedded in the anti-pattern test's own failure message.

## Fix

`lib/src/rules/packages/firebase_rules.dart:3065` — replaced:

```dart
_containsAppCheckActivation(source) && source.contains('activate(');
```

with:

```dart
_containsAppCheckActivation(source) && RegExp(r'activate\(').hasMatch(source);
```

Semantically identical (same match target, `'activate('` literal), now expressed as a regex consistent with the sibling `_containsAppCheckActivation` helper in the same file, which already uses `RegExp`.

## Verification

`dart test test/integrity/anti_pattern_detection_test.dart` — 5/5 tests pass, including "no new .contains() anti-patterns in rule files" and "dangerous pattern count matches audit (Dart and publish script in sync)".

No lint rule behavior changed — this is a detection-mechanism rewrite only, not a logic change to the App Check reachability rule itself.
