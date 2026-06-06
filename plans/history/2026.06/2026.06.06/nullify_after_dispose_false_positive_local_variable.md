# BUG: `nullify_after_dispose` — flags `.dispose()` on a LOCAL variable, not a class field

**Status: Fixed**

Created: 2026-06-06
Rule: `nullify_after_dispose`
File: `lib/src/rules/widget/widget_lifecycle_rules.dart` (line ~1867, `runWithReporter`)
Severity: False positive
Rule version: v7

---

## Summary

`nullify_after_dispose` is meant to flag a *nullable disposable field* that is
disposed but not set to null. Its finality/nullability guard only inspects
CLASS FIELDS (`_findContainingClass` + `_isFieldFinalOrNonNullable`). When the
disposal target is a **local variable** (e.g. `final ui.Codec codec`), no
matching field is found, the "final/non-nullable → skip" guard returns false,
and the rule reports — even though a local going out of scope needs no
nullification (and a `final` local cannot be nulled at all).

## Attribution Evidence

```
$ grep -rn "'nullify_after_dispose'" lib/src/rules/
lib/src/rules/widget/widget_lifecycle_rules.dart:1844:    'nullify_after_dispose',
```

The guard consults only class fields:

```dart
final String fieldName = target.name;           // e.g. "codec" (a LOCAL)
final ClassDeclaration? classNode = _findContainingClass(node);
if (classNode != null && _isFieldFinalOrNonNullable(classNode, fieldName)) {
  return;                                        // never taken: no field named "codec"
}
```

`_isFieldFinalOrNonNullable` iterates `classNode.bodyMembers` looking for a
`FieldDeclaration` named `fieldName`; a local variable is not a field, so it
falls through to `return false`, and the rule reports. The disposal-method
match (`_getDisposedType('dispose')`) also keys purely on the method name, not
the resolved type of the target, so any local `x.dispose()` qualifies.

## Reproducer

```dart
Future<void> _resolve() async {
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  frame.image.dispose();   // OK — target is a PropertyAccess (skipped)
  codec.dispose();         // LINT (false positive) — local final var, not a field
}
```

## Expected vs Actual

| Disposal target | Expected | Actual |
|---|---|---|
| local `final ui.Codec codec` → `codec.dispose()` | OK | LINT |
| nullable field `Timer? _t` → `_t?.cancel()` w/o `_t = null` | LINT | LINT |
| `final` field `final FocusNode _n` → `_n.dispose()` | OK (already skipped) | OK |

## Root Cause

The rule resolves the target name against class fields only. A
`SimpleIdentifier` target that is actually a *local variable declaration*
(or a parameter) is mis-treated as a non-final, nullable field, so it is
neither skipped nor satisfiable (you can't null a `final` local, and a local
needs no nulling — it dies at scope exit).

## Suggested Fix

Before reporting, resolve the target and confirm it is a class field of the
enclosing State:

- Use `target.staticElement` and check it is a `FieldElement` (not
  `LocalVariableElement` / `ParameterElement`); OR
- Confirm a `FieldDeclaration` named `fieldName` actually exists on the
  containing class before flagging (today its absence is treated as
  "non-final nullable field"). If no such field exists, the target is a local
  — return without reporting.

## Fixture Gap

Add fixtures: `.dispose()`/`.cancel()`/`.close()` on a local `final`
variable (no lint) and on a local `var` (no lint); keep the existing
positive case (nullable field disposed without nullification still lints).

## Affected site in Saropa Contacts (inline-ignored pending this fix)

- `lib/views/contact/contact_avatar_crop_screen.dart:83` — `codec.dispose()` on the local `final ui.Codec codec`

---

## Finish Report (2026-06-06)

Fixed by resolving the disposal target against the enclosing class's declared
fields before reporting (suggested-fix option 2).

`runWithReporter` now requires a containing `ClassDeclaration` and a
`FieldDeclaration` named the target identifier; when no such field exists the
target is a local variable or parameter and the rule returns without reporting.
`_isFieldFinalOrNonNullable` was refactored to take the already-located
`FieldDeclaration` (a new `_findField` helper performs the lookup once), so the
finality/nullability skip is unchanged for genuine fields. Rule message bumped
`{v7}` → `{v8}`.

Verified with the scan CLI (`dart run saropa_lints scan ... --tier comprehensive`)
on a reproducer State class: only the nullable-field `_timer?.cancel()` (no
nullification) flags; `codec.dispose()` on a local `final ui.Codec` and
`_node.dispose()` on a `final` field are both silent.

Fixture `example/lib/widget_lifecycle/nullify_after_dispose_fixture.dart`
rewritten into a real `State` subclass — the previous BAD case relied on this
very bug (a top-level `_timer?.cancel()` with no enclosing class was treated as
a field). Added regression guards for local `final` and local `var` disposables.

- Rule: `lib/src/rules/widget/widget_lifecycle_rules.dart`
- Fixture: `example/lib/widget_lifecycle/nullify_after_dispose_fixture.dart`
- Changelog: `[Unreleased]` → Fixed
