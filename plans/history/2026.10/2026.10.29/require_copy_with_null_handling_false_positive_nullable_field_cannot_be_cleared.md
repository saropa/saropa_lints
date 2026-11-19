# BUG: `require_copy_with_null_handling` — conflicts with `prefer_if_null_operators`; no plain-nullable copyWith can satisfy both

**Status: Resolved (documented)**

Created: 2026-10-29
Rule: `require_copy_with_null_handling`
File: `lib/src/rules/packages/equatable_rules.dart` (line ~903, code at 923, body check 973-993)
Severity: False positive (rule conflict)
Rule version: v2 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

For a `copyWith` whose parameters are plain nullable types (`String? x`) and whose fields are nullable, `x ?? this.x` is flagged by `require_copy_with_null_handling`. The only `??`-free rewrite, `x == null ? this.x : x`, is flagged by the Dart lint `prefer_if_null_operators` ("Use the '??' operator rather than '?:' when testing for 'null'"). No copyWith signature built from plain nullable parameters can satisfy both rules. The only way out is a sentinel or wrapper parameter type (`Optional<T>`, `Object? x = _unset`), which changes the public API of ~70-field models.

---

## Attribution Evidence

```bash
grep -rn "'require_copy_with_null_handling'" lib/src/rules/
# lib/src/rules/packages/equatable_rules.dart:923:    'require_copy_with_null_handling',
```

**Rule class:** `RequireCopyWithNullHandlingRule` (`equatable_rules.dart:903`), registered in `lib/saropa_lints.dart:1868`
**Diagnostics as seen in Problems panel:** `require_copy_with_null_handling` (source: saropa_lints) and `prefer_if_null_operators` (source: dart, https://dart.dev/diagnostics/prefer_if_null_operators)

---

## Reproducer

Standalone pure Dart. Real code: `lib/database/models/schema/user_data/contact_db_model.dart` (`ContactDBModel.copyWith`, about lines 1010-1100, 71 parameters) and `lib/database/models/schema/user_data/personality_quiz_progress_db_model.dart:121-128` in the Saropa contacts app.

```dart
class Example {
  const Example({this.name, this.updatedAt});

  final String? name;
  final DateTime? updatedAt;

  // Form A: flagged by require_copy_with_null_handling (the `??` on a nullable field).
  Example copyWithA({String? name, DateTime? updatedAt}) => Example(
    name: name ?? this.name, // LINT require_copy_with_null_handling
    updatedAt: updatedAt ?? this.updatedAt,
  );

  // Form B: avoids `??`, but flagged by the Dart lint prefer_if_null_operators.
  Example copyWithB({String? name, DateTime? updatedAt}) => Example(
    name: name == null ? this.name : name, // LINT prefer_if_null_operators
    updatedAt: updatedAt == null ? this.updatedAt : updatedAt,
  );
}

void main() => print(const Example().copyWithA(name: 'a').name);
```

**Frequency:** Always, for any copyWith with plain nullable parameters over nullable fields.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | At least one plain-nullable copyWith form produces no diagnostic, or the rules are made consistent |
| **Actual** | Form A: `[require_copy_with_null_handling] copyWith with ?? operator cannot set nullable fields to null...` at the method. Form B: `Use the '??' operator rather than '?:' when testing for 'null'. Try rewriting the code to use '??'.` at each argument (for example `contact_db_model.dart` 1019:27, 1022:22). |

---

## AST Context

```
ClassDeclaration (Example)
  └─ MethodDeclaration (copyWithA)           ← require_copy_with_null_handling reports here (reporter.atNode(node), line 993)
      └─ ExpressionFunctionBody
          └─ InstanceCreationExpression (Example)
              └─ NamedExpression (name:)
                  └─ BinaryExpression (name ?? this.name)   ← matched by regex at line 973

ClassDeclaration (Example)
  └─ MethodDeclaration (copyWithB)
      └─ ExpressionFunctionBody
          └─ InstanceCreationExpression (Example)
              └─ NamedExpression (name:)
                  └─ ConditionalExpression (name == null ? this.name : name)   ← prefer_if_null_operators reports here
```

---

## Root Cause

`RequireCopyWithNullHandlingRule.runWithReporter` (`equatable_rules.dart:935-993`):

1. Collects `copyWith` parameters whose outer type is nullable (lines ~945-960).
2. Flags a parameter when the body source matches `\bparam\s*\?\?` (line 973).
3. Reports only when the same-named class field is nullable (lines 983-993), so a non-nullable field is already exempt (see `plans/history/2026.09/2026.09.05/require_copy_with_null_handling_false_positive_non_nullable_fields.md`).

The rule's correction message asks for "a wrapper type like Optional<T> or generated copyWith from freezed". It does not account for the fact that the ternary rewrite is itself flagged by `prefer_if_null_operators`, which is in the Dart core lint set the project enables. A project that adopts both rules has no compliant plain-nullable form.

---

## Why the code is correct

`x ?? this.x` is the intended semantic for these database model copies: callers never need to clear a field through copyWith (clearing is done by writing the field directly or by building a new model). The class contract is "null means keep the current value".

---

## Suggested Fix

Pick one:

1. Skip the report when the `copyWith` parameter type is a plain nullable type and the project also enables `prefer_if_null_operators` (cannot be known from the AST; use config key `require_copy_with_null_handling: allow_plain_nullable: true`).
2. Downgrade the rule to opt-in (not in any default tier), documenting that it conflicts with `prefer_if_null_operators`.
3. Document the conflict in the rule dartdoc and `correctionMessage`, and add a stated exemption when the class doc says "null means keep".

---

## Fixture Gap

The fixture should include:

1. `copyWith({String? x}) => C(x: x ?? this.x)` over a nullable field — currently expect LINT; expect NO lint when the config option above is set.
2. `copyWith({Object? x = _unset})` sentinel form — expect NO lint.
3. `copyWith({String? x}) => C(x: x == null ? this.x : x)` — expect NO lint from this rule (confirms the ternary form is not matched).

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project/file: Saropa contacts app, `lib/database/models/schema/user_data/contact_db_model.dart` (71 arguments), `personality_quiz_progress_db_model.dart:127-128`. The project reverted the ternary form to `x ?? this.x` and accepts the `require_copy_with_null_handling` finding.

## Additional affected location (2026-10-29)

- `lib/database/models/schema/user_data/connection_db_model.dart:131-143` (`ConnectionDBModel.copyWith`: `createdAt`, `sharedContactDetails`, `lastSharedAt`). The ternary form was flagged by `prefer_if_null_operators`; reverted to `x ?? this.x`.

## Status 2026-10-29

Not a false positive. Owner decision: keep the rule; the conflict with `prefer_if_null_operators` is documented in the rule's doc comment.
