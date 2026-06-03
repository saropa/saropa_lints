# avoid_parameter_mutation — False Positive on ValueNotifier/ChangeNotifier `.value` assignment

- **Status:** Fixed
- **Created:** 2026-06-03
- **Rule:** `avoid_parameter_mutation`
- **Rule class:** `AvoidParameterMutationRule` (`lib/src/rules/code_quality/code_quality_variables_rules.dart:422`)
- **Registration:** `lib/saropa_lints.dart:642` (`AvoidParameterMutationRule.new`)
- **Severity:** WARNING
- **Rule version:** v2
- **Reported from:** `D:\src\contacts\lib\utils\share\contact_sharing_workflow_util.dart` (lines 330, 460)

## Summary

The rule flags `notifier.value = x` where `notifier` is a `ValueNotifier<T>` (or any `ChangeNotifier`) passed as a parameter, reporting it as "Parameter object is being mutated. This modifies the caller's data." Mutating a `ValueNotifier.value` is its **entire designed purpose** — a notifier is passed precisely so the callee can update it and notify listeners. This is idiomatic Flutter, not accidental corruption of a caller-owned DTO/collection, which is what the rule targets.

What should happen: `valueNotifier.value = x` on a parameter must NOT fire. `someDto.field = x` (a plain data object) should still fire.

## Attribution Evidence

```
$ grep -rn "'avoid_parameter_mutation'" D:/src/saropa_lints/lib/src/rules/
lib/src/rules/code_quality/code_quality_variables_rules.dart:439:    'avoid_parameter_mutation',
```

Not present as a rule definition in saropa_drift_advisor (only referenced in its `analysis_options.yaml`).

## Reproducer

```dart
import 'package:flutter/foundation.dart';

class Dto { String name = ''; }

// BAD — mutating a caller-owned plain object. Should fire (and does).
void corrupt(Dto dto) {
  dto.name = 'changed'; // LINT (correct)
}

// OK — updating a ValueNotifier passed in for exactly this purpose.
// Currently FIRES (false positive).
void setBusy(ValueNotifier<bool> isBusy) {
  isBusy.value = true; // LINT (should be OK)
}
```

## Expected vs Actual

| Statement | Param type | Expected | Actual |
|---|---|---|---|
| `isBusy.value = true` | `ValueNotifier<bool>` | OK | **LINT (FP)** |
| `dto.name = 'x'` | plain class | LINT | LINT |

## AST Context

```
AssignmentExpression
  leftHandSide: PrefixedIdentifier
    prefix: SimpleIdentifier ('isSharingNotifier')   // a parameter name
    identifier: SimpleIdentifier ('value')
  operator: '='
  rightHandSide: BooleanLiteral
```

Real contacts site (`contact_sharing_workflow_util.dart:330`):

```dart
static Future<void> _handleShare({
  required ValueNotifier<bool> isSharingNotifier,
  ...
}) async {
  isSharingNotifier.value = true;   // line 330 — flagged
  ...
  isSharingNotifier.value = false;  // line 460 — flagged
}
```

## Root Cause

`_ParameterMutationVisitor.visitAssignmentExpression` (lines 504–525) reports any `param.field = value` where the LHS is a `PrefixedIdentifier` whose prefix matches a parameter name. It is purely name-based with no type awareness, so it cannot distinguish:

- a notifier/sink whose mutation is the contract (`ValueNotifier`, `ValueListenable`-backed types, `ChangeNotifier`, `Sink`, `StreamController`, `TextEditingController.text`, etc.), from
- a plain data object whose mutation silently corrupts caller state (the real target).

## Suggested Fix

Make the field-assignment check type-aware (the rule already declares `RuleCost.medium`, so resolved types are acceptable). Skip the report when the parameter's static type is — or implements — a known mutation-by-design type:

- `ValueNotifier`, `ChangeNotifier`, `Listenable`/`ValueListenable` implementers
- `Sink`, `StreamController`
- (optionally) controllers exposing a documented mutable surface

Specifically: in `visitAssignmentExpression`, when `left is PrefixedIdentifier` and the prefix is a parameter, resolve the prefix's `staticType` and return early if it is assignable to one of those types before calling `reporter.atNode`.

## Fixture Gap

`example/lib/code_quality/avoid_parameter_mutation_fixture.dart` covers list/map/set/field/cascade mutation of plain objects, but has **no** ValueNotifier/ChangeNotifier case. Add a GOOD case:

```dart
void setBusy(ValueNotifier<bool> isBusy) {
  isBusy.value = true; // No lint — notifier mutation is by design
}
```

## Environment

- saropa_lints: 13.11.9 (consumed in contacts as `^13.11.9`)
- Dart SDK: `>=3.10.7 <4.0.0`; Flutter `>=3.44.0`
- Plugin mode: native `analysis_server_plugin` (IDE analysis server only)
- Triggering file: `D:\src\contacts\lib\utils\share\contact_sharing_workflow_util.dart`

## Finish Report (2026-06-03)

Fixed in `_ParameterMutationVisitor` (`lib/src/rules/code_quality/code_quality_variables_rules.dart`). The field/index/cascade assignment checks were purely name-based; they now exclude parameters whose type is a mutation-by-design notifier/sink.

Two-layer recognition so it holds in both analysis modes:

1. **Declared type name (syntactic).** `_checkFunction` now records each parameter's declared type annotation name. The directly-typed case from the report — `ValueNotifier<bool> isSharingNotifier` — is matched without type resolution, so it is suppressed under the syntax-only scan CLI as well as the IDE plugin.
2. **Resolved supertype walk.** When `staticType` is available (IDE plugin — where this bug was reported), `_isMutationByDesignType` walks `allSupertypes`, so a custom `class FooNotifier extends ChangeNotifier` parameter is also excluded.

Recognized type names: `ValueNotifier`, `ChangeNotifier`, `Listenable`, `ValueListenable`, `Sink`, `EventSink`, `StreamSink`, `StreamController`.

Plain DTO/collection mutation (`dto.name = x`, `map[k] = v`, `list..add()`) still fires — the rule's real target is unchanged.

**Verification** (scan CLI, `dart run saropa_lints scan`): `dto.name = 'changed'` fires (correct); `isBusy.value = true` on a `ValueNotifier<bool>` param no longer fires (was the FP). The custom-subclass case relies on resolved supertypes, which the syntax-only scan does not provide, so it is verified by the IDE-plugin code path (the supertype walk), not the scan.

**Fixture:** added GOOD cases to `example/lib/code_quality/avoid_parameter_mutation_fixture.dart`. The example package has no Flutter dependency, so local mock `ValueNotifier`/`ChangeNotifier` types (matched by name/supertype, exactly as the rule matches) stand in for the foundation classes.

**Files changed:**
- `lib/src/rules/code_quality/code_quality_variables_rules.dart`
- `example/lib/code_quality/avoid_parameter_mutation_fixture.dart`
- `CHANGELOG.md`
