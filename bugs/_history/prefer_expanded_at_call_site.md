# Bug Report: `prefer_expanded_at_call_site` — Multiple Issues

## Summary

The `prefer_expanded_at_call_site` rule (widget_layout_rules.dart:6433) has several
gaps that reduce its effectiveness at preventing runtime crashes caused by returning
`Expanded`/`Flexible` directly from a widget's `build()` method.

## Real-World Example (contacts project)

```
lib/components/system/network_detect/network_speed_gauge_widget.dart
```

```dart
class NetworkSpeedGaugeWidget extends StatelessWidget {
  // ...

  @override
  Widget build(BuildContext context) => Expanded(          // <- problematic
    child: StreamBuilder<(double speed, double progress)>(
      stream: speedStream,
      builder: (BuildContext context,
          AsyncSnapshot<(double speed, double progress)> snapshot) {
        // ...
        return Column(
          children: <Widget>[
            Expanded(                                      // <- this one is fine (Column is Flex)
              child: AnimatedRadialGauge(/* ... */),
            ),
            if (showStatus) CommonText(/* ... */),
          ],
        );
      },
    ),
  );
}
```

The outer `Expanded` at the `build()` return level forces every caller to place
this widget inside a `Row`, `Column`, or `Flex`. If the widget is ever wrapped
with `Padding`, placed in a `Stack`, or used in a `SingleChildScrollView`, the
app crashes at runtime with a `ParentDataWidget` error.

---

## Issue 1: `Spacer` Not Covered

**Severity: Gap in detection**

`_flexChildTypes` only contains `Expanded` and `Flexible`:

```dart
// widget_layout_rules.dart:6457
static const Set<String> _flexChildTypes = <String>{
  'Expanded',
  'Flexible',
};
```

`Spacer` is also a flex-only widget (it internally wraps `Expanded`). Returning
`Spacer` from `build()` has the same crash risk but is not flagged.

Both `prefer_expanded_at_call_site` and `avoid_expanded_outside_flex` (line 6276)
share this gap.

### Fix

Add `'Spacer'` to `_flexChildTypes` in both rules.

---

## Issue 2: Severity Should Be ERROR, Not WARNING

**Severity: Misclassified severity**

The rule is configured as `DiagnosticSeverity.WARNING` (line 6454), but the
problem message itself says:

> "the Expanded wrapper triggers a runtime ParentDataWidget error and **crashes
> the app**"

A pattern that can crash the app at runtime should be `DiagnosticSeverity.ERROR`,
matching the sibling rule `avoid_expanded_outside_flex` which correctly uses ERROR.

The `impact` field is `LintImpact.medium` (line 6438) but this is arguably
`LintImpact.critical` — it's the same class of defect (Expanded without
guaranteed Flex parent).

### Fix

Change severity to `DiagnosticSeverity.ERROR` and impact to `LintImpact.critical`.

---

## Issue 3: No Tests

**Severity: Quality gap**

No test files exist for `prefer_expanded_at_call_site`. Searched `test/` directory
— zero matches.

This means the rule's detection logic is unverified for:

- Expression body: `Widget build(context) => Expanded(...);`
- Block body with return: `return Expanded(...);`
- Conditional returns: `return cond ? Expanded(...) : Container();`
- Nested if/else branches returning Expanded
- `Spacer` (once added to `_flexChildTypes`)
- False positives: Expanded inside a Column returned from build
  (should NOT flag the inner Expanded, only the outer)

### Fix

Add test file `test/rules/prefer_expanded_at_call_site_test.dart` covering all
the above cases.

---

## Issue 4: Quick Fix Is Insufficient

**Severity: UX improvement**

The quick fix (`_PreferExpandedAtCallSiteFix`, line 6545) only adds a HACK
comment:

```dart
// HACK: Returning Expanded from build() couples to Flex parent.
// Consider returning the child directly.
```

A more useful fix would **unwrap the Expanded** — extract its `child` and return
that directly. This is a straightforward AST transformation:

**Before:**
```dart
Widget build(BuildContext context) => Expanded(
  child: MyContent(),
);
```

**After:**
```dart
Widget build(BuildContext context) => MyContent();
```

The caller can then wrap with `Expanded` as needed:
```dart
Row(children: [Expanded(child: NetworkSpeedGaugeWidget(...))])
```

### Fix

Replace the HACK-comment fix with a proper unwrap transformation that extracts
the `child` argument from the Expanded/Flexible constructor.

---

## Issue 5: Rule Overlap With `avoid_expanded_outside_flex`

**Severity: Design clarification needed**

Two rules detect overlapping issues:

| Rule | Scope | Severity |
|------|-------|----------|
| `avoid_expanded_outside_flex` | Any Expanded without Flex ancestor in AST | ERROR |
| `prefer_expanded_at_call_site` | Expanded returned from `build()` specifically | WARNING |

When `Expanded` is returned from `build()`:
- `avoid_expanded_outside_flex` walks up and hits the `MethodDeclaration` boundary
  without finding a Flex parent → reports ERROR
- `prefer_expanded_at_call_site` detects build return → reports WARNING

The user sees **two diagnostics** for the same line, with different severities.
The WARNING is redundant when the ERROR already fires.

### Fix Options

**Option A:** Make `avoid_expanded_outside_flex` skip the build-return case
(let `prefer_expanded_at_call_site` own it, after bumping to ERROR).

**Option B:** Remove `prefer_expanded_at_call_site` entirely and ensure
`avoid_expanded_outside_flex` has a clear message for the build-return case
(e.g., a more specific `correctionMessage` when the boundary is a `build()` method).

**Option C:** Keep both but suppress `avoid_expanded_outside_flex` when
`prefer_expanded_at_call_site` fires on the same node (dedup logic).

---

## Issue 6: Does Not Cover `SliverFillRemaining` and Other Parent-Coupled Widgets

**Severity: Enhancement / future consideration**

The same architectural problem applies to other widgets that require specific
parent types:

| Widget | Required Parent |
|--------|----------------|
| `Expanded` / `Flexible` / `Spacer` | `Row`, `Column`, `Flex` |
| `SliverFillRemaining` | `CustomScrollView` |
| `SliverToBoxAdapter` | `CustomScrollView` |
| `Positioned` | `Stack` |
| `TableCell` | `Table` / `TableRow` |

Returning any of these from `build()` creates the same encapsulation violation.
This could be generalized into a broader `avoid_parent_coupled_widget_in_build`
rule, or handled as separate focused rules.

### Fix

Consider expanding the rule or creating companion rules for other
parent-coupled widgets, at minimum `Positioned` (very common mistake).

---

## Affected Files

| File | Line | What |
|------|------|------|
| `lib/src/rules/widget_layout_rules.dart` | 6433–6585 | Rule + fix implementation |
| `lib/src/rules/widget_layout_rules.dart` | 6248–6395 | Sibling rule overlap |
| `lib/src/tiers.dart` | 697 | Tier registration |
| `lib/saropa_lints.dart` | 1750 | Plugin registration |
| `test/` | (missing) | No tests exist |

## Priority

**High** — This is a runtime crash prevention rule with no test coverage, a
severity level that undersells the risk, and incomplete widget coverage.
