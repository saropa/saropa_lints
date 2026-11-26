# BUG: `require_envied_obfuscation` — fires on boolean developer toggles with explicit `obfuscate: false`

**Status: Fixed**

Created: 2026-11-26
Rule: `require_envied_obfuscation`
File: `lib/src/rules/packages/envied_rules.dart` (line ~67)
Severity: False positive
Rule version: v2 | Since: v2.2.0 | Updated: v4.13.0

---

## Summary

A `bool` field with `defaultValue: false` holds no secret, yet is reported even with an explicit `obfuscate: false`. Obfuscating it also turns the generated `static const bool` into a computed `static final bool`, which removes compile-time constness and defeats release checks that read the literal value.

---

## Attribution Evidence

```bash
grep -rn "'require_envied_obfuscation'" lib/src/rules/
# lib/src/rules/packages/envied_rules.dart:55:    'require_envied_obfuscation',
```

**Emitter registration:** `lib/src/rules/packages/envied_rules.dart:55`
**Rule class:** `RequireEnviedObfuscationRule` — registered in `lib/saropa_lints.dart:1779`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Derived from reading the rule source. Not executed.

```dart
import 'package:envied/envied.dart';

part 'env_toggles.g.dart';

@Envied(path: '.env')
abstract class Toggles {
  @EnviedField(varName: 'demoMode', obfuscate: false, defaultValue: false) // LINT — but should NOT lint
  static const bool demoMode = _Toggles.demoMode;
}
```

**Frequency:** Always

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic |
| **Actual** | `[require_envied_obfuscation]` reported on the line marked LINT |

---

## AST Context

```
ClassDeclaration (Toggles)
  └─ FieldDeclaration (static const bool demoMode)
      └─ Annotation (@EnviedField)  ← reported
```

---

## Root Cause

Lines ~67-99 report any `EnviedField` annotation lacking `obfuscate: true`. The field type is not examined. `_allFieldsHandleObfuscation` (line ~105) accepts an explicit `false` as handled for the class-level annotation, but the field-level check does not.

---

## Suggested Fix

Skip `EnviedField` on a `bool` field (a two-value flag cannot be a secret).

---

## Fixture Gap

1. `bool` field with `obfuscate: false` — expect NO lint
2. `String` field with `obfuscate: false` — expect LINT (current behavior for strings)

---

## Environment

- saropa_lints version: 17.9.1 (rule source read at this version)
- Dart SDK version: not recorded
- Triggering project/file: a private Flutter app

---

## Finish Report (2026-11-26)

**Fix** (`lib/src/rules/packages/envied_rules.dart`, rule version v3): `@EnviedField` on a `bool` / `bool?` field is not reported, and such fields no longer keep the class-level `@Envied` diagnostic alive. `String`, `int` and other types are unchanged.

**Limits:** in the unresolved scan only an explicit `bool` annotation proves the type; an inferred type stays reported.

Tests: `dart test test/rules/packages/envied_bool_toggle_test.dart test/rules/packages/envied_rules_test.dart` - passed.
