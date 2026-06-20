# BUG: `avoid_parameter_mutation` — fires on Flutter `updateRenderObject` / `setupParentData` overrides where mutating the passed object is the framework contract

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-19
Rule: `avoid_parameter_mutation`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (class line ~483, code line ~500)
Severity: False positive
Rule version: v2 | Since: unknown | Updated: unknown

---

## Summary

`avoid_parameter_mutation` flags the body of `RenderObjectWidget.updateRenderObject(BuildContext, RenderObject)` and `RenderObject.setupParentData(RenderObject child)` overrides, where assigning to a field of the passed render object (`renderObject.foo = ...`) or to `child.parentData` is **mandatory** — it is exactly how the Flutter framework requires these methods to push new configuration. The mutation is the contract, not accidental caller-data mutation. These overrides should be exempt.

This is the same render-object-override blind spot already filed (and closed) for sibling rules:
`avoid_unassigned_late_fields_false_positive_parent_data_render_object.md` and
`avoid_unsafe_cast_false_positive_render_object_parent_data_cast.md`. `avoid_parameter_mutation` was not covered by those.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
$ grep -rn "'avoid_parameter_mutation'" lib/src/rules/
lib/src/rules/code_quality/code_quality_variables_rules.dart:500:    'avoid_parameter_mutation',

$ grep -rn "AvoidParameterMutationRule" lib/src/
lib/src/rules/code_quality/code_quality_variables_rules.dart:483:class AvoidParameterMutationRule extends SaropaLintRule {
lib/src/rules/code_quality/code_quality_variables_rules.dart:484:  AvoidParameterMutationRule() : super(code: _code);
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:483` (`AvoidParameterMutationRule`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#2`

---

## Reproducer

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

class MyWidget extends SingleChildRenderObjectWidget {
  const MyWidget({super.key, required this.flag, super.child});
  final bool flag;

  @override
  RenderMyBox createRenderObject(BuildContext context) => RenderMyBox(flag);

  @override
  void updateRenderObject(BuildContext context, RenderMyBox renderObject) {
    // LINT (avoid_parameter_mutation) — but this is REQUIRED by the framework:
    // updateRenderObject's sole purpose is to push the widget's new config
    // onto the existing render object. There is no copy alternative.
    renderObject.flag = flag; // should be OK
  }
}

class RenderMyBox extends RenderProxyBox {
  RenderMyBox(this._flag);
  bool _flag;
  set flag(bool v) => _flag = v;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! MyParentData) {
      // LINT (avoid_parameter_mutation) — but setupParentData's contract is to
      // assign the child's parentData. This is the documented Flutter pattern.
      child.parentData = MyParentData(); // should be OK
    }
  }
}

class MyParentData extends ParentData {}
```

**Frequency:** Always, for any `updateRenderObject` override that pushes config, and any `setupParentData` override.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — mutating the passed render object is the framework contract for these two override signatures |
| **Actual** | `[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data.` reported on each `renderObject.x = ...` / `child.parentData = ...` |

---

## AST Context

```
ClassDeclaration (MyWidget extends RenderObjectWidget)
  └─ MethodDeclaration (updateRenderObject)   ← signature is the signal
      └─ Block
          └─ ExpressionStatement
              └─ AssignmentExpression (renderObject.flag = flag)  ← reported here

ClassDeclaration (RenderMyBox extends RenderObject)
  └─ MethodDeclaration (setupParentData)      ← signature is the signal
      └─ Block
          └─ IfStatement
              └─ ExpressionStatement
                  └─ AssignmentExpression (child.parentData = MyParentData())  ← reported here
```

---

## Root Cause

`_ParameterMutationVisitor` flags field assignments / cascade field assignments on any parameter object, with exemptions only for collection method calls and index-assignment into List/Map output buffers. It does not recognize the two Flutter override signatures whose entire purpose is to mutate the passed object:

- `RenderObjectWidget.updateRenderObject(BuildContext, covariant RenderObject renderObject)` — the second positional parameter is the live render object the framework hands back to receive the widget's new configuration.
- `RenderObject.setupParentData(covariant RenderObject child)` — the override must set `child.parentData`.

There is no copy alternative for either; the framework owns the object and expects in-place mutation.

---

## Suggested Fix

In `_checkFunction` (or the visitor), skip mutation reporting when the enclosing `MethodDeclaration` is one of these framework overrides. Detect by method name + signature (cheap, syntactic — keeps the scan CLI working):

- name `updateRenderObject` with a `BuildContext` first parameter and a second object parameter → exempt mutations of that second parameter.
- name `setupParentData` with a single object parameter → exempt mutations of that parameter (notably `child.parentData = ...`).

Optionally tighten with a resolved-type check that the enclosing class is a `RenderObjectWidget` / `RenderObject` subtype when resolution is available, falling back to the name+signature heuristic under syntactic parse. This mirrors the exemption already added for `avoid_unassigned_late_fields` and `avoid_unsafe_cast` on the same override surface.

---

## Fixture Gap

The fixture at `example*/lib/code_quality/avoid_parameter_mutation_fixture.dart` should include:

1. `updateRenderObject(BuildContext, RenderX ro)` body assigning `ro.field = ...` — expect NO lint
2. `setupParentData(RenderObject child)` body assigning `child.parentData = ...` — expect NO lint
3. A non-override method that mutates a passed DTO field — expect LINT (guards against over-broad exemption)

---

## Environment

- saropa_lints version: 14.0.4
- Dart SDK version: (Flutter stable, analyzer ^12)
- Triggering project/file: Saropa Contacts — `lib/components/primitive/deferred_loading/visibility_detector_widget.dart` (updateRenderObject), `lib/components/primitive/sticky_group/multi_sliver.dart` (updateRenderObject), `lib/components/primitive/sticky_group/render_multi_sliver.dart` (setupParentData)

---

## Finish Report (2026-06-19)

### Defect

`avoid_parameter_mutation` flagged field/`parentData` assignments inside the two
Flutter render-object override signatures whose entire contract is to mutate the
framework-supplied object: `updateRenderObject(BuildContext, RenderObject)` and
`setupParentData(RenderObject child)`. There is no copy alternative for either —
the framework owns the object and requires in-place mutation — so the diagnostic
was a false positive on every such override.

### Fix

In `lib/src/rules/code_quality/code_quality_variables_rules.dart`:

- Added `AvoidParameterMutationRule._renderObjectOverrideMutationTargets(MethodDeclaration)`.
  It recognizes the two override signatures syntactically (method name plus
  parameter shape) so it works under the syntax-only scan CLI where static types
  are unavailable, and returns the parameter name whose mutation is the contract:
  - `updateRenderObject` with a `BuildContext` first parameter and a second
    parameter → the second parameter (the render object receiving new config).
  - `setupParentData` with a single parameter → that parameter (its `parentData`
    assignment is the documented pattern).
- `_checkFunction` now accepts an `exemptParamNames` set and omits those names
  from the parameter map before the mutation visitor runs, so the exempt
  parameter is never seen as a mutation target. The `addMethodDeclaration`
  callback supplies the set; the `addFunctionDeclaration` (top-level/local
  function) path passes none, since these overrides are always class methods.
- The `BuildContext`-first-parameter requirement keeps the `updateRenderObject`
  match specific enough that a coincidental same-named method (different
  signature) is not exempted.

Rule message tag bumped `{v2}` → `{v3}`; dartdoc header updated to
`Updated: v14.0.5 | Rule version: v3` with an added Exemptions note.

### Verification

- Fixture `example/lib/code_quality/avoid_parameter_mutation_fixture.dart`
  extended with: a `setupParentData` override assigning `child.parentData`
  (expect no lint), an `updateRenderObject(BuildContext, RenderMyBox)` override
  assigning `renderObject.flag` (expect no lint), and an over-broad-exemption
  guard `updateRenderObject2(User)` (wrong signature → still flagged).
- Scan CLI (`dart run saropa_lints scan ... --tier comprehensive`) on the
  fixture confirms the two override mutations are not reported while the guard
  and all pre-existing DTO/cascade mutations still are.
- `dart analyze` on the changed rule file: no issues.

This mirrors the render-object exemption previously added for
`avoid_unassigned_late_fields` and `avoid_unsafe_cast`.
