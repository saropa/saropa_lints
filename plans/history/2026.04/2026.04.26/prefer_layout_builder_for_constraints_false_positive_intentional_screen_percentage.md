> **Archived** from `bugs/` on 2026-04-26. **Resolution:** `prefer_layout_builder_for_constraints` v2 skips duplicate `.size` + `.size.width` reports, exempts dimension reads in `*`/`/` and numeric breakpoint comparisons with a literal operand, documents screen vs parent constraints, and matches `MediaQuery.sizeOf(context).width`/`.height`; see [CHANGELOG.md](../../../../CHANGELOG.md) [Unreleased].

# `prefer_layout_builder_for_constraints` — false positive: rule fires on intentional screen-relative sizing where parent constraints are unrelated

**Status:** Fixed (saropa_lints: double-report, screen-fraction/breakpoint exemptions, `sizeOf` parity, fixture + changelog)

Filed: 2026-04-26
Rule: `prefer_layout_builder_for_constraints`
File: `lib/src/rules/widget/widget_layout_constraints_rules.dart` (line 2534, code at 2552–2596)
Severity: False positive
Rule version: v1 | Severity in code: INFO | Impact: low

---

## Summary

The rule fires on every `MediaQuery.of(context).size.width` and `.size.height` access, recommending `LayoutBuilder` instead. But these two APIs answer different questions:

- `MediaQuery.size` → physical screen size (or window size on desktop). Stable across the widget tree. Used when sizing should be a percentage of the **screen / window**.
- `LayoutBuilder.constraints` → constraints handed down by the immediate parent. Used when sizing should fit the available space inside whatever container the widget is nested in.

These are **not interchangeable**. Code like `width: MediaQuery.of(context).size.width * 0.85` deliberately wants 85% of the screen width — independent of any parent's constraints (which may be `BoxConstraints.tightFor(width: 600)` from a fixed-width column on a tablet, etc.). Replacing it with `LayoutBuilder` would change the layout behavior, not improve it.

The rule's only mitigation hint is "MediaQuery-based sizing rebuilds on any MediaQuery change". That is true but rarely material — `MediaQuery.size` only changes on device rotation, window resize (desktop), or keyboard appearance (which already rebuilds the screen anyway via `viewInsets`).

---

## Attribution Evidence

```bash
$ grep -rn "'prefer_layout_builder_for_constraints'" lib/src/rules/
lib/src/rules/widget/widget_layout_constraints_rules.dart:2553:    'prefer_layout_builder_for_constraints',
```

Rule lives here. Confirmed.

**Emitter registration:** `lib/src/rules/widget/widget_layout_constraints_rules.dart:2534` (`PreferLayoutBuilderForConstraintsRule`)
**Rule class:** `PreferLayoutBuilderForConstraintsRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner`:** `dart` (saropa_lints native plugin)

---

## Reproducer

Consumer project: `D:\src\contacts`.

`lib/components/contact/detail_panels/address/address_panel.dart:235` (fires twice on this single line — once for `.size`, once for `.size.width`):

```dart
// Horizontal-layout address card. The card width is intentionally
// 85% of SCREEN width, because the panel is rendered in a horizontal
// PageView where each page should consume most of the screen and leave
// a small peek of the next page. The PageView's parent constraints are
// `BoxConstraints.expand` — so LayoutBuilder.constraints.maxWidth would
// give "PageView width", which is ALREADY screen width. Substituting
// LayoutBuilder here adds boilerplate without changing behavior — and
// in any narrower parent (which exists in tablet / split-view paths)
// it would produce *wrong* output (page width instead of screen width).
SizedBox(
  width: MediaQuery.of(context).size.width * 0.85,  // LINT — but should NOT lint
  child: CommonPanel(...),
);
```

**Frequency:** Always. Two diagnostics fire per line because the rule reports on both `MediaQuery.of(context).size` (the `size` access) and `MediaQuery.of(context).size.width` (the `width` access).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the `MediaQuery.size` value is multiplied by a constant fraction (`* 0.85`) — that pattern is unambiguously a screen-relative sizing intent that LayoutBuilder cannot replicate. Or: rule kept but never reports two diagnostics for the same expression. |
| **Actual** | Both `.size` and `.size.width` get separate `[prefer_layout_builder_for_constraints]` diagnostics on the same line. Replacing with `LayoutBuilder` would change layout in any non-full-width parent. |

---

## AST Context

```
PropertyAccess (.size)                  ← reported (1st diagnostic)
  ├─ target: MethodInvocation (MediaQuery.of(context))
  └─ propertyName: SimpleIdentifier ("size")

PropertyAccess (.width)                 ← reported (2nd diagnostic)
  ├─ target: PropertyAccess (.size of MediaQuery.of(context))
  └─ propertyName: SimpleIdentifier ("width")
```

Detection at `runWithReporter` (lines 2561–2577):

```dart
context.addPropertyAccess((PropertyAccess node) {
  final Expression? target = node.target;
  if (target == null) return;
  final String name = node.propertyName.name;
  if (name == 'size' && _isMediaQueryOf(target)) {
    reporter.atNode(node, _code);                  // ← fires on `.size`
    return;
  }
  if ((name == 'width' || name == 'height') &&
      _isMediaQuerySizeAccess(target)) {
    reporter.atNode(node, _code);                  // ← fires on `.width`
  }
});
```

Both branches fire for `MediaQuery.of(context).size.width` because the analyzer visits the inner `.size` access AND the outer `.width` access.

---

## Root Cause

### Flaw A: rule treats all `MediaQuery.size` as substitutable for `LayoutBuilder`

The two APIs answer different questions (see Summary). The rule's recommendation is correct **only** in the narrow case where a widget needs the size of its *immediate parent*, not the screen. Detection should at least exempt the multiplication-by-constant pattern (`* 0.85`, `/ 2`, etc.) which is the standard idiom for screen-relative sizing.

### Flaw B: dual reporting on a single expression

The rule fires once on `.size` (when target matches `MediaQuery.of(context)`) and once on `.width` (when target matches `MediaQuery.of(context).size`). For a single source expression like `MediaQuery.of(context).size.width`, this produces two warnings pointing at adjacent property accesses — same problem, double-counted.

### Flaw C: no check for the matching `LayoutBuilder` recommendation actually working

If the surrounding scope has access to `MediaQuery` but does NOT have an enclosing `LayoutBuilder` (and adding one would require restructuring), the rule's quick-fix recommendation is non-trivial work that may not produce equivalent layout. The rule severity is INFO, but the recommendation in the message ("Use LayoutBuilder") is presented as a drop-in replacement, which it is not.

---

## Suggested Fix

Three layered fixes, in priority order:

### Fix 1 — Stop double-reporting

In `runWithReporter` at lines 2569–2576, only emit on the **outermost** of the chained PropertyAccess nodes for a given `MediaQuery.of(context).size.{width|height}` expression. The simplest implementation: when matching `.size` (line 2569), check if the *parent* of the node is itself a `PropertyAccess` accessing `width` or `height`, and skip emission — let the outer `.width`/`.height` branch handle it.

```dart
if (name == 'size' && _isMediaQueryOf(target)) {
  final AstNode? parent = node.parent;
  // The .width / .height case below already covers this; don't double-report.
  if (parent is PropertyAccess &&
      (parent.propertyName.name == 'width' ||
       parent.propertyName.name == 'height')) {
    return;
  }
  reporter.atNode(node, _code);
  return;
}
```

### Fix 2 — Exempt the screen-percentage idiom

Skip emission when `MediaQuery.of(context).size.width` (or `.height`) is the left or right operand of a `*` or `/` binary expression with a numeric literal operand. That covers `* 0.85`, `/ 2`, `* 0.5`, etc. — the unambiguous screen-relative pattern.

```dart
if ((name == 'width' || name == 'height') && _isMediaQuerySizeAccess(target)) {
  // Exempt screen-percentage sizing idiom — `LayoutBuilder` cannot replicate
  // intent because constraints reflect parent, not screen.
  if (_isOperandOfMultiplyOrDivide(node)) return;
  reporter.atNode(node, _code);
}
```

### Fix 3 — Add a docstring carve-out

Document when the rule does NOT apply: dialog/sheet sizing relative to the screen (full-screen overlays), responsive breakpoints (`if (MediaQuery.of(context).size.width > 600)`), keyboard-aware insets (`MediaQuery.of(context).viewInsets.bottom`). Currently the rule's docstring (lines 2512–2533) has no such carve-out, which causes consumers to file false-positive issues like this one.

---

## Fixture Gap

The fixture at `example*/lib/widget/prefer_layout_builder_for_constraints_fixture.dart` should include:

1. **`SizedBox(width: MediaQuery.of(context).size.width)` directly inside a constrained parent** — expect LINT (genuine smell)
2. **`SizedBox(width: MediaQuery.of(context).size.width * 0.85)`** — expect NO lint *(currently false positive)*
3. **`if (MediaQuery.of(context).size.width > 600) ...` (responsive breakpoint)** — expect NO lint *(currently false positive — width access in conditional)*
4. **`MediaQuery.of(context).size.width` accessed twice in same expression** — expect ONE lint, not two *(currently double-reports)*
5. **`MediaQuery.sizeOf(context).width`** — expect LINT (matches `_isMediaQueryOf` because it accepts both `of` and `sizeOf`)
6. **`MediaQuery.of(context).viewInsets.bottom`** — expect NO lint (rule doesn't target viewInsets)

---

## Downstream

Tracked in `contacts/`. Once this report exists, the consumer file gets `// ignore: prefer_layout_builder_for_constraints` at `lib/components/contact/detail_panels/address/address_panel.dart:235` with a comment pointing here.

---

## Environment

- saropa_lints version: 12.4.0
- Dart SDK: 3.9.x
- Triggering project: `d:/src/contacts`
- Platform: Windows 11
