# BUG: `avoid_undisposed_instances` + `require_field_dispose` — Cascade Dispose Not Traced

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `avoid_undisposed_instances` / `require_field_dispose`
File: `lib/src/rules/widget/widget_lifecycle_rules.dart` (lines ~3036, ~1277)
Severity: False positive (both rules, same root cause)
Rule version: v7 (`avoid_undisposed_instances`) / v3 (`require_field_dispose`) | Updated: v4.13.0

---

## Summary

Both `avoid_undisposed_instances` and `require_field_dispose` fire on a controller field whose
`dispose()` call is reached through a **cascade section** — `_c?..removeListener(x)..dispose()`.
The field IS disposed; it is simply done in a single null-safe cascade expression that also removes
a listener in the same step. The `_DisposeVisitor` used by `avoid_undisposed_instances` handles
`CascadeExpression` as a target of a method invocation, but the visitor's
`visitMethodInvocation` receives each cascade section's `MethodInvocation` node individually and
checks `node.target` — for the `.dispose()` section of `_c?..removeListener(..)..dispose()`, the
`target` is the `CascadeExpression` itself (the root cascade), not a `SimpleIdentifier`. Whether
`_extractFieldName` descends correctly into that `CascadeExpression` target depends on which
invocation node fires first and how the AST represents chained cascades.

For `require_field_dispose`, the check is entirely string-based: `_isFieldDisposed` searches the
normalized `disposeBody.toSource()` string with a set of `RegExp` patterns (lines 1515–1527). The
patterns cover `_c.dispose(`, `_c?.dispose(`, `_c..dispose(`, and a whitespace-tolerant variant of
`_c ..dispose(`, but they do NOT match the chained form `_c?..removeListener(..)..dispose()` where
the `.dispose()` segment is not the first cascade section.

Both worked around on 2026-06-09 with
`// ignore: avoid_undisposed_instances` and `// ignore: require_field_dispose` on affected
`AnimationController?` fields in Saropa Contacts.

---

## Attribution Evidence

Grep proof that both rules live in `saropa_lints`. Positive attribution confirmed by parent session;
the diagnostic owner in the IDE Problems panel is `_generated_diagnostic_collection_name_#N` (the
analysis-server plugin — negative attribution against sibling repos is not required).

```bash
# Positive — avoid_undisposed_instances IS defined here
grep -rn "'avoid_undisposed_instances'" lib/src/rules/
# Result: lib/src/rules/widget/widget_lifecycle_rules.dart:3036: ... 'avoid_undisposed_instances' ...

# Positive — require_field_dispose IS defined here
grep -rn "'require_field_dispose'" lib/src/rules/
# Result: lib/src/rules/widget/widget_lifecycle_rules.dart:1277: ... 'require_field_dispose' ...
```

**Emitter registration:**
- `lib/src/rules/widget/widget_lifecycle_rules.dart:3036` (`avoid_undisposed_instances`)
- `lib/src/rules/widget/widget_lifecycle_rules.dart:1277` (`require_field_dispose`)

**Rule classes:** `AvoidUndisposedInstancesRule`, `RequireDisposeRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `_generated_diagnostic_collection_name_#N`

---

## Reproducer

Minimal Dart code that triggers the bug.

```dart
class _MyWidgetState extends State<MyWidget>
    with SingleTickerProviderStateMixin {

  AnimationController? _c; // LINT (avoid_undisposed_instances + require_field_dispose)
                           // — but _c IS disposed below via cascade

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _c!.addListener(_tick);
  }

  void _tick() { /* ... */ }

  @override
  void dispose() {
    // Removes the listener and disposes in one null-safe cascade.
    // Both rules fail to see .dispose() here because it trails a
    // removeListener() cascade section.
    _c?..removeListener(_tick)..dispose(); // OK — disposed via cascade
    super.dispose();
  }
}
```

**Frequency:** Always — fires whenever `dispose()` in the cascade is not the first (and only)
section, i.e. any time a listener-removal or other setup step precedes the `.dispose()` call in the
same cascade expression.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `_c` is disposed in `dispose()` via a cascade |
| **Actual (avoid_undisposed_instances)** | `[avoid_undisposed_instances] Disposable object (e.g., TextEditingController, AnimationController, StreamController) created but no matching dispose() call found. Undisposed instances retain listeners…` reported at the `_c` field declaration |
| **Actual (require_field_dispose)** | `[require_field_dispose] Disposable field may not be properly disposed. {v3}` reported at the `AnimationController? _c` field declaration |

---

## AST Context

```
ClassDeclaration (_MyWidgetState)
  └─ FieldDeclaration                         ← reported node (both rules)
      └─ VariableDeclarationList
          └─ VariableDeclaration (_c)

  └─ MethodDeclaration (dispose)
      └─ Block
          └─ ExpressionStatement
              └─ CascadeExpression             ← root of the cascade
                  target: PostfixExpression (_c?)
                  cascadeSections:
                    [0] MethodInvocation (removeListener(_tick))
                    [1] MethodInvocation (dispose())   ← disposal is here
```

For `_DisposeVisitor.visitMethodInvocation`:
- Section [0] fires with `node.methodName = 'removeListener'`; `node.target = CascadeExpression`.
  Not a disposal method — ignored.
- Section [1] fires with `node.methodName = 'dispose'`; `node.target = CascadeExpression`.
  `_extractFieldName(CascadeExpression)` recurses into the `CascadeExpression.target` (the `_c?`
  `PostfixExpression`), but `PostfixExpression` is not handled by `_extractFieldName` (which only
  handles `SimpleIdentifier`, `PrefixedIdentifier`, `PropertyAccess`, `ParenthesizedExpression`,
  and `CascadeExpression`) — so the field name is never extracted and `disposedFields` is not
  populated.

For `RequireDisposeRule._isFieldDisposed` (string-based):
- `normalized` = `"{ _c?..removeListener(_tick)..dispose(); super.dispose(); }"` (whitespace-
  collapsed).
- Pattern `_c\?\.\.dispose\(` does NOT match because `..dispose(` does not appear adjacent to
  `_c?`; there is `..removeListener(_tick)` in between.
- Pattern `_c\s+\.\.\s*dispose\s*\(` also does NOT match for the same reason.
- None of the other patterns match either. Result: `_isFieldDisposed` returns `false`.

---

## Root Cause

### `avoid_undisposed_instances` — `_extractFieldName` does not handle `PostfixExpression`

`_DisposeVisitor._extractFieldName` (lines 3187–3210) handles these expression types for the method
target:
- `SimpleIdentifier` — `_c.dispose()`
- `PrefixedIdentifier` — `this._c.dispose()`
- `PropertyAccess` — `this._c.dispose()` (alternate AST)
- `ParenthesizedExpression` — `(_c).dispose()`
- `CascadeExpression` — recurses into `CascadeExpression.target`

When the cascade is `_c?..removeListener(..)..dispose()`, the `CascadeExpression.target` is the
`PostfixExpression` `_c?` (a null-assertion or null-aware postfix). `PostfixExpression` is NOT one
of the handled cases, so `_extractFieldName` returns without adding anything to `disposedFields`.
The field therefore fails the "was it disposed?" check and the diagnostic fires.

Even if `CascadeExpression` recursion does reach the right level, the `target` of the `dispose()`
invocation in a multi-section cascade is the entire root `CascadeExpression` node, not the
individual identifier — so the extraction still depends on correctly unwrapping the target chain.

### `require_field_dispose` — regex patterns do not match mid-chain cascade `dispose()`

`_isFieldDisposed` (lines 1506–1533) normalizes whitespace and checks the full `disposeBody`
string against six patterns. All patterns require `_c` (the field name) to appear either
immediately before `.dispose(`, `?.dispose(`, or `..dispose(` — or with optional whitespace before
`..dispose(`. In `_c?..removeListener(_tick)..dispose()`, the text `_c` is separated from
`..dispose()` by `..removeListener(_tick)`, so none of the patterns match.

The root cause is that the regex family was written for single-section cascades
(`_c?..dispose()`) and does not generalize to multi-section cascades where `dispose()` is not the
first section.

---

## Suggested Fix

### `avoid_undisposed_instances` (`_DisposeVisitor._extractFieldName`, ~line 3187)

Add a `PostfixExpression` branch that strips the postfix operator and recurses into the operand:

```dart
// Before (no PostfixExpression branch):
else if (target is CascadeExpression) {
  _extractFieldName(target.target);
}

// After — handle null-aware postfix (_c?) by recursing into its operand:
else if (target is PostfixExpression) {
  _extractFieldName(target.operand);
}
else if (target is CascadeExpression) {
  _extractFieldName(target.target);
}
```

This makes `_c?..removeListener(..)..dispose()` correctly extract `_c` when the disposal section
fires.

### `require_field_dispose` (`_isFieldDisposed`, ~line 1508)

Add a pattern that allows any number of cascade sections between the field name and `..dispose()`:

```dart
// Add after the existing patterns — matches dispose() as any cascade section,
// not necessarily the first one:
RegExp('$name\\??(?:\\.\\.[^;]+)+\\.\\.$method\\('),
```

A simpler alternative: after building `normalized`, check whether it contains BOTH `$name` (or
`$name?`) AND `..${method}(` anywhere in the body — treating the two substrings as independently
present. This is less precise but eliminates the false positive for all multi-section cascades with
a terminal `dispose()`.

---

## Fixture Gap

The fixture at
`example*/lib/widget/avoid_undisposed_instances_fixture.dart` and
`example*/lib/widget/require_field_dispose_fixture.dart` should include:

1. **Single-section cascade (currently passing)** — `_c?..dispose();` — expect NO lint.
2. **Two-section cascade, dispose last** — `_c?..removeListener(_tick)..dispose();` — expect NO lint.
3. **Three-section cascade, dispose last** — `_c?..removeListener(_tick)..removeListener(_tock)..dispose();` — expect NO lint.
4. **Multi-section cascade, dispose NOT present** — `_c?..removeListener(_tick)..reset();` with no other disposal — expect LINT.
5. **Null-aware postfix target** — `_c?..dispose();` (the `?` makes the cascade target a `PostfixExpression`) — expect NO lint (may already pass; add as regression guard).
6. **Mixed direct + cascade in dispose()** — `_a.dispose(); _b?..removeListener(_f)..dispose();` with two fields — expect NO lint on either field.

---

## Changes Made

Both rules in `widget_lifecycle_rules.dart`:

- **`avoid_undisposed_instances` (`_DisposeVisitor`)**: the real fix is using
  `node.realTarget` instead of `node.target` for disposal-method detection. In
  a cascade section (`_c?..removeListener(f)..dispose()`) the `.dispose()`
  invocation's *syntactic* `target` is null (the receiver is implicit), so
  `_extractFieldName(null)` recorded nothing and the field read as undisposed.
  `realTarget` resolves to the cascade receiver `_c`. Also added a
  `PostfixExpression` branch to `_extractFieldName` for the null-assertion
  cascade form `_c!..dispose()`.
- **`require_field_dispose` (`_isFieldDisposed`)**: added two regex patterns
  matching `dispose()`/`disposeSafe()` in any cascade section, not just the
  first — `$name\??(?:\.\.[^;]+)*\.\.$method\(`. The `*` also covers the
  single-section null-aware form `_c?..dispose()`. `[^;]+` confines each match
  to one cascade statement so it cannot bridge to a different field's disposal.

The report's suggested PostfixExpression-only fix for `avoid_undisposed` was
insufficient on its own — the section target is null, not a PostfixExpression,
so `realTarget` was the actual root cause.

---

## Tests Added

- `example/lib/widget_lifecycle/avoid_undisposed_instances_fixture.dart`: added
  `_CascadeState` disposing `AnimationController? _c` via
  `_c?..removeListener(_tick)..dispose()` (NO lint).
- `example/lib/widget_lifecycle/require_field_dispose_fixture.dart`: added
  `_CascadeDisposeState` (two-section, dispose last — NO lint),
  `_ThreeSectionState` (three-section — NO lint), and `_NoDisposeState`
  (cascade with `..reset()` but no dispose — LINT).
- Scan CLI verified: both rules now fire ONLY on `_NoDisposeState` (the genuine
  leak); every cascade-disposed field is clean. Unit suites
  `widget_lifecycle_rules_test.dart` and `state_lifecycle_dispose_scan_test.dart`
  pass.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Finish Report (2026-06-09)

**Scope:** (A) Dart lint rules / analyzer plugin.

**Deep review:** The `avoid_undisposed` change swaps `target` for
`realTarget ?? target` — a strict superset (realTarget equals target for
non-cascade calls), so no existing detection is lost. The `require_field_dispose`
regexes are statement-bounded (`[^;]+`) to avoid cross-field bridging. Disposal
detection is name/string based (no type resolution needed), so the scan CLI
exercises it fully. Rule files, tiers, severities, `LintImpact` unchanged.

**Tests:** scan CLI + `widget_lifecycle_rules_test.dart` +
`state_lifecycle_dispose_scan_test.dart` all pass, verified as above.

**Maintenance:** CHANGELOG `[Unreleased]` Fixed bullet added. README/ROADMAP
unchanged (false-positive fix).

**Bug archived:** bugs/avoid_undisposed_instances_and_require_field_dispose_false_positive_cascade_dispose.md
→ plans/history/2026.06/2026.06.09/avoid_undisposed_instances_and_require_field_dispose_false_positive_cascade_dispose.md

**Finish report appended:** this file.

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: (project default — see pubspec.lock)
- custom_lint version: N/A — saropa_lints is a native analyzer plugin
- Triggering project/file: Saropa Contacts 2026-06-09 — `AnimationController?` fields disposed via
  `_c?..removeListener(_tick)..dispose()` in `State.dispose()` methods across multiple animation
  widgets
