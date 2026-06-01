# BUG: `prefer_layout_builder_for_constraints` — false positive on static utility method that takes `BuildContext`

**Status: Fixed**

Created: 2026-05-31
Fixed: 2026-05-31
Rule: `prefer_layout_builder_for_constraints`
File: `lib/src/rules/widget/widget_layout_constraints_rules.dart` (line ~2588, scope check ~2699)
Severity: False positive
Rule version: v5 / current

---

## Summary

The rule fires inside `static` utility methods that take a `BuildContext`
parameter and use `MediaQuery.sizeOf(context).height` (or `.width`) to compute
**absolute viewport-fraction dimensions** for non-widget return types like
`BoxConstraints`. The suggested fix — replace with `LayoutBuilder` — is
structurally inapplicable: a static utility has no incoming `BoxConstraints`
to consult, and the caller is precisely trying to bound a widget BY a fraction
of the viewport, not by its parent's constraints.

The existing `non_build_method` FP report (2026-04-28) gated out methods that
**do not** declare a `BuildContext` parameter. This case slips through
because the static utility **does** take `BuildContext` (it has to, to call
`MediaQuery`), so the rule treats it as a build-phase context.

---

## Attribution Evidence

```bash
# Positive — rule IS defined in saropa_lints
grep -rn "'prefer_layout_builder_for_constraints'" D:/src/saropa_lints/lib/src/rules/
# D:/src/saropa_lints/lib/src/rules/widget/widget_layout_constraints_rules.dart:2588: 'prefer_layout_builder_for_constraints',

# Negative — rule is NOT in saropa_drift_advisor
grep -rn "'prefer_layout_builder_for_constraints'" D:/src/saropa_drift_advisor/lib/src D:/src/saropa_drift_advisor/extension/src
# (zero matches)
```

**Emitter registration:** `lib/src/rules/widget/widget_layout_constraints_rules.dart:2588`
**Rule class:** `PreferLayoutBuilderForConstraintsRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (custom_lint)
**Related closed report:** `plans/history/2026.04/2026.04.28/prefer_layout_builder_for_constraints_false_positive_non_build_method.md`
**Why this report is not a duplicate:** the 2026-04-28 fix added a non-build
scope gate that excludes methods that **don't take a `BuildContext`
parameter**. The pattern in this report **does** take a `BuildContext` (because
`MediaQuery.sizeOf(context)` requires one), so it slips through the same
gate. Different sub-case, different fix needed.

---

## Reproducer

The smallest reproducer is a static utility that computes a max-height
`BoxConstraints` for a popup menu, capped at a viewport fraction:

```dart
import 'package:flutter/widgets.dart';

abstract final class MenuUtils {
  MenuUtils._();

  static const double popupMenuViewportFraction = 0.90;
  static const double popupMenuMinHeight = 320.0;
  static const double popupMenuMaxHeight = 700.0;

  /// Compute max-height constraints for a popup menu as a fraction of
  /// the viewport, clamped to min/max.
  static BoxConstraints popupMenuConstraints(BuildContext context) {
    // expect_lint: prefer_layout_builder_for_constraints (FALSE POSITIVE)
    final double viewportHeight = MediaQuery.sizeOf(context).height;
    final double height = (viewportHeight * popupMenuViewportFraction)
        .clamp(popupMenuMinHeight, popupMenuMaxHeight);
    return BoxConstraints(maxHeight: height);
  }
}
```

The result of `popupMenuConstraints(context)` is then passed as the
`constraints:` parameter to a `PopupMenuButton` or similar surface — there is
no widget tree at this call site, no parent `BoxConstraints` to derive from,
and `LayoutBuilder` cannot be used because we're not building a widget here.

**Frequency:** Always — fires on any static method that takes `BuildContext`
and reads `MediaQuery.sizeOf(context).height`/`.width` for absolute sizing.

**Downstream site this surfaced on (real codebase):**

- `saropa_contacts/lib/components/primitive/menu/menu_utils.dart`, line 55
  inside `MenuUtils.popupMenuConstraints(BuildContext context)`. The site is
  silenced with `// ignore: prefer_layout_builder_for_constraints -- static
  utility computing absolute viewport-fraction max-height; LayoutBuilder is
  inapplicable; see upstream bug` pointing at this report.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. The method is a `static` utility computing absolute viewport-fraction dimensions for a non-widget return type (`BoxConstraints`). `LayoutBuilder` is structurally inapplicable — there are no incoming constraints, and the caller is intentionally bounding a widget BY viewport-fraction, not BY parent constraints. |
| **Actual** | `[prefer_layout_builder_for_constraints] Use LayoutBuilder for constraint-aware layout instead of MediaQuery for widget sizing. MediaQuery-based sizing rebuilds on any MediaQuery change.` |

The "rebuilds on any MediaQuery change" concern is also misplaced for this
shape: the method runs ONCE per popup-menu open (not in a `build` method that
re-runs on every MediaQuery tick). MediaQuery rebuild cost is paid by the
caller's widget context, not by this utility.

---

## AST Context

```
ClassDeclaration (MenuUtils — abstract final)
  └─ MethodDeclaration (isStatic, name='popupMenuConstraints')
      ├─ returnType: NamedType('BoxConstraints', nullable: false)
      ├─ parameters: [SimpleFormalParameter(BuildContext context)]
      └─ BlockFunctionBody
          └─ VariableDeclarationStatement
              └─ VariableDeclaration (viewportHeight)
                  └─ PropertyAccess (.height)            ← rule fires here
                      └─ MethodInvocation (MediaQuery.sizeOf(context))
```

`_isInNonBuildScope` walks the AST and hits `MethodDeclaration
(popupMenuConstraints)`. The method name is not `'build'` and not a lifecycle
method, so the rule falls to `_declaresBuildContextParameter(cur.parameters)`
(line 2705), which returns `true` because `BuildContext context` is declared.
`_isInNonBuildScope` then returns `false` (= "in build scope"), and the rule
fires.

---

## Root Cause

### Hypothesis A: `BuildContext` parameter is a leaky proxy for "build scope"

The existing scope gate (`_isInNonBuildScope`, line 2699) uses
`_declaresBuildContextParameter` as the discriminator: a method that takes
`BuildContext` is assumed to be a builder callback or `build()` itself, and
the rule fires. This is correct for `Widget build(BuildContext)` and for
`builder: (BuildContext context, ...) => ...` callbacks — but it is **not**
correct for `static` utility methods that take `BuildContext` only to call
`MediaQuery`. The proxy is true for "widget builders" but leaky for "non-widget
utilities".

The 2026-04-28 fix added the BuildContext-parameter check to **expand** the
non-build skip set, but the converse (methods that take BuildContext yet are
NOT build-scope) is still uncovered.

### Hypothesis B: `static` modifier is the missing discriminator

A `static` method on a class cannot be a `build()` override (which must be
instance-level on a `Widget` subclass) and cannot be a builder-callback body
(callbacks are anonymous closures, not static methods). The simplest precise
fix is: when the enclosing `MethodDeclaration` is `static`, treat the scope
as non-build regardless of `BuildContext` parameter presence.

### Hypothesis C: Return-type discriminator is also viable

A method that returns `BoxConstraints`, `EdgeInsets`, `double`, `Size`, etc.
(not `Widget` or a `Widget` subclass) cannot be a builder — its return is
plumbed as data, not painted. But this is harder to evaluate reliably (return
types can be generic, aliases, or unresolved at lint time), and the `static`
discriminator already catches the high-traffic case.

**Recommended:** Hypothesis B. Cheap, precise, no element-model lookup needed.

---

## Suggested Fix

In `_isInNonBuildScope` (line 2699), short-circuit on `static`:

```dart
static bool _isInNonBuildScope(AstNode node) {
  for (AstNode? cur = node; cur != null; cur = cur.parent) {
    if (cur is MethodDeclaration) {
      // STATIC methods are utilities, not widget builders. They cannot
      // override `build()` (which is an instance method) and cannot
      // host the body of a `WidgetBuilder` callback (which is an
      // anonymous closure, not a method). Treat as non-build regardless
      // of whether `BuildContext` is in the parameter list — static
      // helpers like `MenuUtils.popupMenuConstraints(BuildContext)` are
      // computing absolute viewport-fraction dimensions on demand, and
      // `LayoutBuilder` is structurally inapplicable to them.
      if (cur.isStatic) return true;

      final String methodName = cur.name.lexeme;
      if (methodName == 'build') return false;
      if (_nonBuildLifecycleMethods.contains(methodName)) return true;
      return !_declaresBuildContextParameter(cur.parameters);
    }
    if (cur is FunctionExpression) {
      final FormalParameterList? parameters = cur.parameters;
      if (!_declaresBuildContextParameter(parameters)) return true;
    }
  }
  return false;
}
```

`MethodDeclaration.isStatic` is a documented getter on the analyzer's AST
node — no element resolution needed, so the cost is the same one-token
inspection as the existing checks.

---

## Fixture Gap

The fixture at
`example/lib/widget_layout/prefer_layout_builder_for_constraints_fixture.dart`
should include:

1. **Static utility computing BoxConstraints from viewport fraction —
   expect NO lint**
   ```dart
   abstract final class _MenuUtils {
     _MenuUtils._();
     static BoxConstraints popupConstraints(BuildContext context) {
       final double h = MediaQuery.sizeOf(context).height; // NO lint
       return BoxConstraints(maxHeight: h * 0.9);
     }
   }
   ```

2. **Static utility returning a `Size` from viewport — expect NO lint**
   ```dart
   abstract final class _SizeUtils {
     _SizeUtils._();
     static Size halfScreen(BuildContext context) {
       final Size s = MediaQuery.sizeOf(context);     // NO lint
       return Size(s.width / 2, s.height / 2);
     }
   }
   ```

3. **Negative guard: instance `build` still fires** — the existing
   true-positive guard from the prior fix.
   ```dart
   class _MyWidget extends StatelessWidget {
     @override
     Widget build(BuildContext context) {
       final double h = MediaQuery.sizeOf(context).height; // EXPECT LINT
       return SizedBox(height: h);
     }
   }
   ```

4. **Negative guard: instance helper that takes BuildContext STILL fires**
   — a non-static method on a widget that takes BuildContext is still
   treated as part of the build phase (this preserves the 2026-04-28
   behavior precisely).
   ```dart
   class _Helper extends StatelessWidget {
     double _readHeight(BuildContext context) =>
         MediaQuery.sizeOf(context).height;          // EXPECT LINT
     @override
     Widget build(BuildContext context) =>
         SizedBox(height: _readHeight(context));
   }
   ```

---

## Changes Made

**Implementation (Hypothesis B — `static` short-circuit):**

- `lib/src/rules/widget/widget_layout_constraints_rules.dart` — `_isInNonBuildScope` now returns `true` immediately when the enclosing `MethodDeclaration.isStatic` is true, before the `build` / lifecycle / `BuildContext`-parameter checks. The check uses the analyzer AST's `isStatic` getter (no element resolution), so the cost is the same one-token inspection as the existing checks. A multi-line `// Why` comment cites this report and the failure mode (`MenuUtils.popupMenuConstraints(BuildContext)`) so the rationale survives at the call site.

**Fixture additions** (`example/lib/widget_layout/prefer_layout_builder_for_constraints_fixture.dart`):

- `BadInstanceBuildContextHelper` — instance helper that takes `BuildContext`; expect-lint marker preserves the 2026-04-28 true-positive case (only `static` short-circuits).
- `OkStaticMenuConstraintsUtils.popupConstraints(BuildContext)` — static utility returning `BoxConstraints` from `MediaQuery.sizeOf(context).height`; expect NO lint.
- `OkStaticSizeUtils.halfScreen(BuildContext)` — static utility returning `Size` from `MediaQuery.sizeOf(context)`; expect NO lint.

**Test updates** (`test/rules/widget/prefer_layout_builder_for_constraints_fixture_test.dart`):

- Bumped expected `// expect_lint:` marker count from 7 to 8 (added one for the instance-helper guard).
- New test `static-utility classes appear AFTER OkScreenFraction with no markers` asserts both static fixture classes exist; the existing "no expect_lint after `OkScreenFraction`" test continues to cover the no-marker requirement on those classes.

**Verification:**

- Repro project at `d:/tmp/lint_repro/` with `dart run saropa_lints scan ... --tier comprehensive --format json`:
  - Static `popupMenuConstraints` / `halfScreen` utilities — no `prefer_layout_builder_for_constraints` hits (was: 2 false positives).
  - Instance `BadWidget.build` (lines 37, 38) — still fires (true positive preserved).
  - Instance `HelperWidget._readHeight` — still fires (2026-04-28 case preserved).
- All 6 fixture tests pass: `dart test test/rules/widget/prefer_layout_builder_for_constraints_fixture_test.dart` → `+6 All tests passed!`
- `dart analyze --fatal-infos lib/src/rules/widget/widget_layout_constraints_rules.dart` → `No issues found!`

**Changelog entry:** `CHANGELOG.md` [Unreleased] § Fixed.

**Related closed report:** `plan/history/2026.04/2026.04.28/prefer_layout_builder_for_constraints_false_positive_non_build_method.md` (the `BuildContext`-parameter scope gate this report extends).

---

## Finish Report (2026-05-31)

**Scope:** (A) Dart lint rule — one-branch patch to `PreferLayoutBuilderForConstraintsRule._isInNonBuildScope` so static utility methods that take `BuildContext` no longer get treated as widget-build scope. Fixture, unit test, CHANGELOG, and bug-archive updates land in the same commit.

**Files changed:**

- `lib/src/rules/widget/widget_layout_constraints_rules.dart` — added `if (cur.isStatic) return true;` short-circuit at the top of the `MethodDeclaration` arm of `_isInNonBuildScope` (line ~2711). Multi-line `// Why` comment cites this report and names the failure mode. After moving the bug file to `plan/history/...`, the comment's report-path reference was repointed in the same commit.
- `example/lib/widget_layout/prefer_layout_builder_for_constraints_fixture.dart` — added three fixture classes:
  - `BadInstanceBuildContextHelper` (BAD, before `OkScreenFraction`) — pins the instance-method-with-BuildContext true-positive case from 2026-04-28.
  - `OkStaticMenuConstraintsUtils` (OK, after `OkScreenFraction`) — static `BoxConstraints` utility; expect no lint.
  - `OkStaticSizeUtils` (OK, after `OkScreenFraction`) — static `Size` utility; expect no lint.
- `test/rules/widget/prefer_layout_builder_for_constraints_fixture_test.dart` — marker count 7 → 8; new `static-utility classes appear AFTER OkScreenFraction with no markers` test asserts both static fixture classes exist (the existing `no expect_lint after OkScreenFraction` test continues to enforce the no-marker requirement on them). Report-path reference repointed.
- `CHANGELOG.md` — new `[Unreleased] § Fixed` bullet: "`prefer_layout_builder_for_constraints` no longer fires inside `static` utility methods that take a `BuildContext`."
- `bugs/prefer_layout_builder_for_constraints_false_positive_static_utility_with_buildcontext.md` → `plan/history/2026.05/2026.05.31/prefer_layout_builder_for_constraints_false_positive_static_utility_with_buildcontext.md` — `git mv`; `Status:` flipped to `Fixed`; `Fixed: 2026-05-31` date added.

**Diff summary of core logic change:**

```diff
   static bool _isInNonBuildScope(AstNode node) {
     for (AstNode? cur = node; cur != null; cur = cur.parent) {
       if (cur is MethodDeclaration) {
+        // Static methods are utilities, not widget builders … [9-line Why]
+        if (cur.isStatic) return true;
         final String methodName = cur.name.lexeme;
         if (methodName == 'build') return false;
         if (_nonBuildLifecycleMethods.contains(methodName)) return true;
         return !_declaresBuildContextParameter(cur.parameters);
       }
```

No other code paths modified. `MethodDeclaration.isStatic` is an analyzer AST getter — same one-token cost as the existing `methodName` check.

**Test results:**

- `dart test test/rules/widget/prefer_layout_builder_for_constraints_fixture_test.dart` → `+6 All tests passed!`
- `dart test test/rules/widget/widget_layout_rules_test.dart` → `+132 All tests passed!`
- `dart test test/scan/rule_quick_fix_presence_test.dart` → `+188 All tests passed!`
- `dart analyze --fatal-infos lib/src/rules/widget/widget_layout_constraints_rules.dart` → `No issues found!`

**External verification (scan CLI repro at `d:/tmp/lint_repro/`):**

| Code shape | Before (rule v5) | After (this patch) |
|---|---|---|
| `static BoxConstraints popupMenuConstraints(BuildContext)` | LINT (FP) | no lint ✓ |
| `static Size halfScreen(BuildContext)` | LINT (FP) | no lint ✓ |
| `Widget build(BuildContext) { MediaQuery.of(context).size.width … }` | LINT | LINT ✓ |
| `double _readHeight(BuildContext)` (instance method on Widget) | LINT | LINT ✓ (2026-04-28 case preserved) |

**Test-audit notes:**

- `_isInNonBuildScope` is private — no test pins it directly.
- `test/scan/rule_quick_fix_presence_test.dart` only imports the rule's containing file; it does not pin any behavior of this rule. No update needed.
- `test/rules/widget/widget_layout_rules_test.dart` carries a registration smoke test and a registry list assertion for `prefer_layout_builder_for_constraints`. No update needed — name, class, and tier are unchanged.
- `test/rules/widget/avoid_builder_index_out_of_bounds_behavior_test.dart` matched only on a dartdoc comment mentioning `widget_layout_constraints_rules.dart`; no behavior assertion involved.

**Bug archived:** `bugs/prefer_layout_builder_for_constraints_false_positive_static_utility_with_buildcontext.md` → `plan/history/2026.05/2026.05.31/prefer_layout_builder_for_constraints_false_positive_static_utility_with_buildcontext.md`.

**Finish report appended:** `plan/history/2026.05/2026.05.31/prefer_layout_builder_for_constraints_false_positive_static_utility_with_buildcontext.md`.

**Outstanding work:** None for this task. The downstream silencing comment in `saropa_contacts/lib/components/primitive/menu/menu_utils.dart` (referenced in the bug's "Downstream site this surfaced on") can be removed once the next `saropa_lints` release ships — out of scope for this repo.
