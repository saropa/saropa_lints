# BUG: `avoid_positioned_outside_stack` — false positive when Positioned is built into a list that a parent widget spreads into its own Stack

**Status: Fixed (already fixed — duplicate of 2026-05-13 fix)**

Created: 2026-08-16
Fixed: 2026-08-16 (confirmed existing fix covers this case)
Rule: `avoid_positioned_outside_stack`
File: `lib/src/rules/widget_layout_constraints_rules.dart` (line ~5474)
Severity: False positive

---

## Summary

The rule flags a `Positioned` widget whose syntactic parent is a `List<Widget>` literal passed to a parameter (e.g. `backgroundLayers:`) that the receiving widget spreads directly into its own `Stack.children`. The code is correct at runtime — `Positioned` DOES end up as a direct Stack child — but the rule only walks the local AST, so any Positioned built outside a literal `Stack(children: [...])` is flagged.

---

## Attribution Evidence

```
# Positive — rule IS defined here
Select-String lib/src/rules/**/*.dart -Pattern "avoid_positioned_outside_stack"
widget_layout_constraints_rules.dart:5474: // Rule: avoid_positioned_outside_stack
widget_layout_constraints_rules.dart:5519: 'avoid_positioned_outside_stack',
widget_layout_constraints_rules.dart:5520: '[avoid_positioned_outside_stack] Positioned widget used outside '
```

**Emitter registration:** `lib/src/rules/widget_layout_constraints_rules.dart:~5519`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
// A composition widget that owns the Stack and spreads a caller-supplied
// layer list into it (the FocusCard pattern in the Saropa contacts app):
class FocusCard extends StatelessWidget {
  const FocusCard({required this.backgroundLayers, super.key});
  final List<Widget> backgroundLayers;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        ...backgroundLayers, // Positioned entries land as DIRECT Stack children
        const SizedBox.expand(),
      ],
    );
  }
}

// Call site:
Widget buildCard() {
  return FocusCard(
    backgroundLayers: <Widget>[
      // LINT — but should NOT lint: this list is spread straight into
      // FocusCard's Stack, so Positioned has a Stack as its render parent.
      Positioned(right: -16, bottom: -16, child: Icon(Icons.star)),
    ],
  );
}
```

Real-world trigger: `d:\src\contacts\lib\components\event\discovery_cards\update_available_focus_card.dart:118` (and the sibling discovery cards using the same `FocusCard.backgroundLayers` contract), suppressed there with `// ignore: avoid_positioned_outside_stack -- FocusCard spreads backgroundLayers into its own Stack`.

**Frequency:** Always, for any Positioned inside a list argument that the receiver spreads into a Stack.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (Positioned is a direct Stack child at runtime via the spread) |
| **Actual** | `[avoid_positioned_outside_stack] Positioned widget used outside ...` reported at the call site |

---

## AST Context

```
InstanceCreationExpression (FocusCard)
  └─ NamedExpression (backgroundLayers:)
      └─ ListLiteral (<Widget>[...])
          └─ InstanceCreationExpression (Positioned)  ← node reported here
```

The rule's parent walk from `Positioned` reaches a `ListLiteral` whose enclosing argument is NOT `Stack.children` (it is `FocusCard.backgroundLayers`), so it reports.

---

## Root Cause

### Hypothesis A: parent walk only accepts a literal `Stack(children: ...)` ancestor

The rule likely checks whether the nearest enclosing list literal is the `children:` argument of a `Stack`/`IndexedStack` constructor invocation. A list passed to any other parameter fails that check, even when the receiving widget's build method spreads the list into a Stack — cross-widget dataflow the rule cannot see locally.

---

## Suggested Fix

Cannot be solved soundly with local analysis. Pragmatic options:

1. Recognize a conventional escape hatch: skip lists passed to parameters whose name matches a configured allowlist (e.g. `backgroundLayers`, `overlayChildren`) — configurable per project.
2. Or downgrade the diagnostic when the list is an argument to a non-`children` widget parameter (unknown destination) rather than a plain variable/return — "unknown" is not "wrong".

---

## Fixture Gap

The fixture at `example*/lib/.../avoid_positioned_outside_stack_fixture.dart` should include:

1. **Positioned inside a list passed to a widget param spread into that widget's Stack** — expect NO lint (currently lints)
2. **Positioned inside a list passed to a param that is NOT spread into a Stack** — expect LINT (true positive, guards against over-fixing)

---

## Changes Made

No code changes needed — the fix was already applied on 2026-05-13 (see
`plans/history/2026.05/2026.05.13/avoid_positioned_outside_stack_false_positive_list_passed_to_stack_param.md`).

The rule passes `treatCustomWidgetParentAsIndeterminate: true` at line ~5549.
The `_findWidgetAncestor` helper (line ~5310) returns `indeterminate` when the
first widget ancestor is a user-defined widget (detected by `_isCustomFlutterWidget`),
which suppresses the lint for patterns like `FocusCard(backgroundLayers: [Positioned(...)])`.

**Added fixture coverage** for this case — the original fix had no test.

---

## Tests Added

- `example/lib/widget_layout/avoid_positioned_outside_stack_fixture.dart` — new
  fixture covering:
  - BAD: Positioned inside Column (true positive, must lint)
  - GOOD: Positioned inside Stack (direct child)
  - GOOD: Positioned inside IndexedStack (subclass)
  - GOOD: Positioned in a list passed to a custom widget param (FocusCard pattern — the FP this bug reports)
  - GOOD: Positioned returned from a helper method (indeterminate)
  - GOOD: Positioned inside .map callback (indeterminate)

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: pin in d:\src\contacts pubspec / analysis_options `plugins:` block
- Dart SDK version: Flutter stable bundled (contacts app toolchain)
- Triggering project/file: `d:\src\contacts\lib\components\event\discovery_cards\update_available_focus_card.dart:118`

---

## Finish Report (2026-08-16)

**Duplicate bug.** The reported false positive — `Positioned` inside a list passed to a custom widget parameter that spreads it into a `Stack` — was already fixed on 2026-05-13. The fix lives in `_findWidgetAncestor` (widget_layout_constraints_rules.dart ~line 5310): when `treatCustomWidgetParentAsIndeterminate` is true and the first widget ancestor is a user-defined widget (per `_isCustomFlutterWidget`), the walk returns `indeterminate`, suppressing the lint.

**Gap closed:** The original fix shipped with no fixture coverage. The fixture at `example/lib/widget_layout/avoid_positioned_outside_stack_fixture.dart` was a stub (`void main() {}`). It now contains six test scenarios: one true positive (Positioned inside Column) and five true negatives (direct Stack child, IndexedStack, list-to-custom-widget param, helper method return, `.map` callback).

**Key design constraint:** `FocusCard` is defined in the fixture file itself, not in `flutter_mocks.dart`. `_isCustomFlutterWidget` explicitly excludes libraries ending with `/flutter_mocks.dart` (treating them as framework widgets), so a mock defined there would bypass the indeterminate path and the test would not exercise the fix.

**CHANGELOG:** The `[Unreleased]` section was merged into `[15.0.3]` (unreleased version). The diagnostic-span fix bullet joined `### Fixed (Extension)` and the fixture bullet joined the `Maintenance` details block.

**Integrity test:** Added `test/integrity/positioned_outside_stack_fixture_contract_test.dart` — verifies the fixture exists, has `expect_lint`, defines a custom widget with `List<Widget>` for the FP guard, and includes Stack/IndexedStack GOOD cases. The resolved-rule harness cannot test this rule (Flutter types resolve to `InvalidType` in the example package), so the contract test is the best available structural coverage.
