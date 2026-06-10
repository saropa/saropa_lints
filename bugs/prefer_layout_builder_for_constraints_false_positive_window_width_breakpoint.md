# BUG: `prefer_layout_builder_for_constraints` — Fires on window-width responsive breakpoint fed to a boolean, not a dimension

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `prefer_layout_builder_for_constraints`
File: `lib/src/rules/widget/widget_layout_constraints_rules.dart` (line ~2588)
Severity: False positive
Rule version: v2 | Since: v4.13.0 | Updated: v4.13.0

---

## Summary

The rule fires on `MediaQuery.sizeOf(context).width` when the width value is passed to
`ResponsiveLayout.isWide(...)` — a device-class breakpoint helper that returns a `bool`. The
result is never used as a widget dimension; it selects a font-size step (`ThemeCommonFontSize`)
or a boolean branch. `LayoutBuilder` gives the LOCAL box width, which is the wrong signal for
this use case: a narrow sidebar panel on a wide screen would read as "not wide" and choose the
compact font size, which is incorrect. These sites required `// ignore: prefer_layout_builder_for_constraints`
workarounds on 2026-06-09.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`:

```bash
# Positive — rule IS defined here
grep -rn "'prefer_layout_builder_for_constraints'" lib/src/rules/
# lib/src/rules/widget/widget_layout_constraints_rules.dart:2588:     'prefer_layout_builder_for_constraints',
```

The diagnostic owner is `_generated_diagnostic_collection_name_#N` (the IDE analysis-server
plugin). Negative attribution against sibling repos is not required — this is a direct plugin
registration, not an ambiguous label.

**Emitter registration:** `lib/src/rules/widget/widget_layout_constraints_rules.dart:2588`
**Rule class:** `PreferLayoutBuilderForConstraintsRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `prefer_layout_builder_for_constraints`

---

## Reproducer

```dart
// Inside a StatelessWidget build() method.
// ResponsiveLayout.isWide() takes a double and returns bool.
// ThemeCommonFontSize.wide() uses that bool to pick a font step.

@override
Widget build(BuildContext context) {
  // LINT — but this reads window width for a device-class boolean, not a widget dimension.
  // LayoutBuilder would give the panel's box width, which is the wrong input.
  final bool isWide = ResponsiveLayout.isWide(
    MediaQuery.sizeOf(context).width,   // ← flagged here
  );

  return CommonText(
    'Hello',
    fontSizeCommon: ThemeCommonFontSize.wide(isWide),
  );
}
```

**Frequency:** Always — every call to `ResponsiveLayout.isWide(MediaQuery.sizeOf(context).width)`
inside a `build` method (or `WidgetBuilder` callback) is flagged, regardless of how the width
value is consumed downstream.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `MediaQuery.sizeOf(context).width` fed to a boolean breakpoint helper is not widget sizing and `LayoutBuilder` is structurally the wrong replacement |
| **Actual** | `[prefer_layout_builder_for_constraints] Use LayoutBuilder for constraint-aware layout instead of MediaQuery for widget sizing. MediaQuery-based sizing rebuilds on any MediaQuery change.` reported at the `.width` property access |

---

## AST Context

```
MethodDeclaration (build)
  └─ Block
      └─ VariableDeclarationStatement
          └─ VariableDeclaration (isWide)
              └─ MethodInvocation (ResponsiveLayout.isWide)
                  └─ ArgumentList
                      └─ PropertyAccess (.width)           ← node reported here
                          └─ MethodInvocation (MediaQuery.sizeOf(context))
```

The rule's `context.addPropertyAccess` visitor sees `.width` on a `MediaQuery.sizeOf(...)` result
and calls `reporter.atNode(node, _code)` (line ~2619). The exemption at line ~2618 —
`_isMediaQuerySizeDimensionInLiteralScaleOrBreakpoint` — only exempts `.width` when the
**immediate parent** `BinaryExpression` operator is `*`, `/`, `>`, `<`, `>=`, or `<=` with a
numeric literal on the other side. Here the immediate parent is `ArgumentList`
(`MethodInvocation` argument), so the exemption does not trigger.

---

## Root Cause

### Hypothesis A: Exemption only covers literal-operand binary expressions, not method-argument positions

`_isMediaQuerySizeDimensionInLiteralScaleOrBreakpoint` (line ~2663) walks from the `PropertyAccess`
node upward, unwrapping parentheses, then checks whether the immediate parent is a
`BinaryExpression` with a numeric literal on the opposite side. This exempts patterns like:

```dart
MediaQuery.sizeOf(context).width * 0.9   // fraction → exempt
MediaQuery.sizeOf(context).width > 600   // inline compare → exempt
```

But the project's canonical responsive pattern delegates the comparison into a helper:

```dart
ResponsiveLayout.isWide(MediaQuery.sizeOf(context).width)
```

Here the `.width` node's immediate parent is an `ArgumentList` node (inside a
`MethodInvocation`), not a `BinaryExpression`. The exemption function returns `false` and
the diagnostic fires (line ~2619 `reporter.atNode(node, _code)`).

The rule's docstring (line ~2544) explicitly acknowledges that "a dialog width as a fraction
of screen width, or a `PageView` page that should leave a peek of the next page" are
intentional window-relative reads. A boolean breakpoint helper is an equally intentional
window-relative read — the distinction the docstring draws is between "sizing a widget" and
"deciding a layout strategy", and the latter is exactly what `isWide(...)` does.

### Hypothesis B: `_isInNonBuildScope` does not help here

The method is `build` (not a lifecycle override), so `_isInNonBuildScope` (line ~2699) returns
`false`. The non-build-scope exemption is also not the right fix for this FP — the call is
legitimately in `build`, just not doing widget sizing.

---

## Suggested Fix

Extend `_isMediaQuerySizeDimensionInLiteralScaleOrBreakpoint` (or add a parallel helper) to
also return `true` when the immediate parent of the `PropertyAccess` is an `ArgumentList`
inside a `MethodInvocation` whose return type resolves to `bool` (or `bool?`). The reasoning:
a width passed as an argument to a function that returns `bool` cannot be a widget dimension —
it is a breakpoint query.

A more conservative version: return `true` any time the `.width` / `.height` access is a
direct argument (not nested in an arithmetic expression) to any method call — because if the
caller wanted widget sizing, they would assign the value to a `double` field like `width:` or
`height:`, not pass it to a function. This avoids having to resolve the callee's return type.

Reference lines:
- Detection: `runWithReporter` lines ~2615–2621
- Exemption function: `_isMediaQuerySizeDimensionInLiteralScaleOrBreakpoint` lines ~2663–2689

---

## Fixture Gap

The fixture at `example*/lib/widget/prefer_layout_builder_for_constraints_fixture.dart` should
include:

1. **`MediaQuery.sizeOf(context).width` passed to a bool-returning helper** — expect NO lint
   (`ResponsiveLayout.isWide(MediaQuery.sizeOf(context).width)`)
2. **`MediaQuery.sizeOf(context).width` passed as argument to any method call** — expect NO lint
   (the general form of the same pattern)
3. **`MediaQuery.sizeOf(context).width` assigned directly to a `width:` named parameter** —
   expect LINT (this IS widget sizing)
4. **`MediaQuery.sizeOf(context).width * 0.9`** — expect NO lint (already covered by literal
   scale exemption; confirm it stays clean after any fix)
5. **`MediaQuery.sizeOf(context).width > 600`** — expect NO lint (already covered by comparison
   exemption; regression guard)

---

## Changes Made

<!-- Fill in when a fix is written. -->

---

## Tests Added

<!-- List new or updated fixture/test files and what they verify. -->

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: (project: Saropa Contacts, 2026-06-09)
- custom_lint version: N/A — saropa_lints is a native analysis-server plugin
- Triggering project/file: Saropa Contacts — multiple widget `build` methods calling
  `ResponsiveLayout.isWide(MediaQuery.sizeOf(context).width)`; workaround applied
  2026-06-09 via `// ignore: prefer_layout_builder_for_constraints -- window width for
  device-class breakpoint, not widget sizing; LayoutBuilder gives wrong (panel) width`
