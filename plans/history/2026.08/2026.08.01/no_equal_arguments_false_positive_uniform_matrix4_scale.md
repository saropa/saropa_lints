# BUG: `no_equal_arguments` — false positive on uniform `Matrix4.scaleByDouble(s, s, 1, 1)`

**Status: Fixed**

Created: 2026-08-01
Rule: `no_equal_arguments`
File: `lib/src/rules/data/equality_rules.dart` (line ~466, `_equalArgIdiomaticCallees`)
Severity: False positive
Rule version: v4

---

## Summary

A uniform 2D scale is expressed as `Matrix4.identity()..scaleByDouble(s, s, 1, 1)` — the x and y factors MUST be the same identifier, or the scale is not uniform. The rule flags the second `s` as a suspected copy-paste error. This is the same class of exemption already granted to `Size`, `Offset`, `fromRGBO`, `fromARGB` and `fromLTRB`: a callee whose contract makes equal positional arguments meaningful rather than accidental.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'no_equal_arguments'" lib/src/rules/
# lib/src/rules/data/equality_rules.dart:409:    'no_equal_arguments',
```

**Emitter registration:** `lib/src/rules/data/equality_rules.dart:409`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dartAnalysisLSP` / `saropa_lints`

---

## Reproducer

```dart
import 'package:vector_math/vector_math_64.dart';

/// Uniform scale — sx and sy are required to be equal.
Matrix4 scale(double s) => Matrix4.identity()..scaleByDouble(s, s, 1, 1); // LINT — but should NOT lint
```

**Frequency:** Always, on any uniform `scaleByDouble` where the factor is a named variable rather than a numeric literal. (Literal factors — `scaleByDouble(2, 2, 1, 1)` — are already skipped by the `IntegerLiteral`/`DoubleLiteral` guard at line ~444, so the FP only shows up with identifiers.)

Real-world trigger: `d:\src\contacts\lib\components\contact\reaction\reaction_motion_animation.dart:81`, reported at line 81 col 66 (the second `s`) on 2026-08-01.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — a uniform scale requires `sx == sy` |
| **Actual** | `[no_equal_arguments] The same identifier is passed as multiple positional arguments...` WARNING on the second argument |

---

## Root Cause

`_equalArgIdiomaticCallees` (line ~466) enumerates callees where equal positional arguments are semantically required. The Matrix4 scaling family is missing from that set, even though it is the canonical case: uniform scaling is the common usage, non-uniform the exception.

---

## Suggested Fix

Add the Matrix4 scaling entry points to `_equalArgIdiomaticCallees`:

```dart
static const Set<String> _equalArgIdiomaticCallees = <String>{
  'fromRGBO',
  'fromARGB',
  'fromLTRB',
  'Size',
  'Offset',
  'scaleByDouble',   // Matrix4..scaleByDouble(sx, sy, sz, sw) — uniform: sx == sy
  'scale',           // Matrix4..scale(sx, sy, sz)             — uniform: sx == sy
  'diagonal3Values', // Matrix4.diagonal3Values(x, y, z)       — uniform: x == y
};
```

Note `_calleeName` resolves the callee for `MethodInvocation` and `InstanceCreationExpression`. `..scaleByDouble(...)` is a cascade section, whose `MethodInvocation.target` is null — verify `_calleeName` returns `scaleByDouble` for a cascade section (it reads `methodName`, so it should, but the fixture below pins it).

---

## Fixture Gap

The fixture for this rule should include:

1. **Cascaded uniform scale** — `Matrix4.identity()..scaleByDouble(s, s, 1, 1);` — expect NO lint
2. **Plain-invocation uniform scale** — `m.scale(s, s, 1);` — expect NO lint
3. **Genuine copy-paste on a non-exempt callee (existing)** — `setPosition(x, x);` — expect LINT

Item 1 also covers the cascade-section path through `_calleeName`.

---

## Changes Made

- `lib/src/rules/data/equality_rules.dart` — split `_equalArgIdiomaticCallees` into two structures: `_unconditionalIdiomaticCallees` (unique names like `scaleByDouble`, `diagonal3Values`) and `_guardedIdiomaticCallees` (generic names like `scale` that require a receiver-type check against `Matrix4`). Added `_isIdiomaticCallee`, `_receiverName` methods. The receiver check uses resolved `staticType` when available and falls back to syntactic name extraction for unresolved contexts (cascade targets, constructors).
- `example/lib/flutter_mocks.dart` — added `Matrix4` stub with `identity()`, `diagonal3Values()`, `scale()`, and `scaleByDouble()`.

---

## Tests Added

- `example/lib/equality/no_equal_arguments_fixture.dart` — added `_goodMatrix4Scale` (cascaded `scaleByDouble`, plain `scale`, `diagonal3Values` — expect NO lint) and `_badNonMatrix4Scale` (`_FakeWidget().scale(s, s)` — expect LINT, proving the receiver guard works).

---

## Finish Report (2026-08-01)

The `no_equal_arguments` rule flagged `Matrix4..scaleByDouble(s, s, 1, 1)` as a copy-paste error. A uniform 2D scale requires `sx == sy` by definition — the equal arguments are the correct API usage, not a mistake.

**Root cause:** The allowlist in `NoEqualArgumentsRule` exempted `fromRGBO`, `fromARGB`, `fromLTRB`, `Size`, and `Offset` but omitted the Matrix4 scaling family.

**Fix:** Added `scaleByDouble` and `diagonal3Values` to an unconditional allowlist (names unique to Matrix4). Added `scale` to a guarded allowlist that checks the receiver type — `_FakeWidget().scale(s, s)` still fires, but `Matrix4.identity()..scale(s, s, 1)` does not. The receiver check uses resolved `InterfaceType` when available and falls back to syntactic target name extraction for unresolved scan contexts.

**Verification:** Integrity test (`saropa_lints_test.dart`), equality rules unit test, and anti-pattern detection test all pass. Fixture includes both GOOD (Matrix4 uniform scale) and BAD (non-Matrix4 `.scale()`) cases.

---

## Environment

- saropa_lints version: per `d:\src\contacts` pubspec pin as of 2026-08-01
- Dart SDK version: Flutter stable toolchain in use by `d:\src\contacts`
- Triggering project/file: `d:\src\contacts\lib\components\contact\reaction\reaction_motion_animation.dart:81`
