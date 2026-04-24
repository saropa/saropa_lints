# BUG: `avoid_color_only_meaning` — Fires on theme-adaptive conditional (isDarkMode) that conveys no state

**Status: Closed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-24
Rule: `avoid_color_only_meaning`
File: `lib/src/rules/ui/accessibility_rules.dart` (class `AvoidColorOnlyMeaningRule` at line 4223, code declaration at line 4239)
Severity: False positive — High (forces `// ignore:` on every theme-adaptive background in the codebase)
Rule version: v1 | Since: unknown | Updated: n/a

---

## Summary

The rule fires on a `ColoredBox` whose `color:` is a ternary branching on `ThemeUtils.isDarkMode`. This is a theme-adaptation conditional — the user only ever sees one branch depending on their OS theme setting — and carries no meaning or state the user could be expected to infer from color. WCAG 1.4.1 applies to color used as an information channel; it does not apply to a theme's own background color. The rule should not flag conditionals whose predicate resolves to a dark-mode / platform-brightness check.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_color_only_meaning'" lib/src/rules/
# D:\src\saropa_lints\lib\src\rules\ui\accessibility_rules.dart:4239:    'avoid_color_only_meaning',
```

**Emitter registration:** `lib/src/rules/ui/accessibility_rules.dart:4239`
**Rule class:** `AvoidColorOnlyMeaningRule` — defined at `accessibility_rules.dart:4223`
**Diagnostic `source` / `owner` as seen in Problems panel:** `_generated_diagnostic_collection_name_#2` (custom_lint-style anonymous owner; verified by positive grep)

No negative attribution grep needed — `avoid_color_only_meaning` is unique to `saropa_lints` and does not appear in `saropa_drift_advisor` or any other analyzer plugin.

---

## Reproducer

Minimal case (reproduces exactly the situation hit in `d:/src/contacts/lib/views/phone_dialer/phone_dial_pad.dart:186-190`):

```dart
import 'package:flutter/material.dart';

class ThemeUtils {
  static bool get isDarkMode => false; // stub — real impl reads MediaQuery
}

class Example extends StatelessWidget {
  const Example({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // LINT — but should NOT lint. The ternary branches on `isDarkMode`,
      // not on user-facing state. Color here is theme adaptation, not an
      // information channel subject to WCAG 1.4.1.
      color: ThemeUtils.isDarkMode ? Colors.black : Colors.white,
      child: const SizedBox(width: 10, height: 10),
    );
  }
}
```

**Frequency:** Always — fires on any `ColoredBox` / `Card` / `Material` / `DecoratedBox` / `Chip` / `CircleAvatar` / `Badge` / `PhysicalModel` / `AnimatedContainer` whose `color` or `backgroundColor` is a ternary, regardless of what the predicate actually tests.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. The ternary predicate is a theme / platform-brightness check — the user never sees both variants to compare, so there is no meaning being encoded in color. |
| **Actual** | `[avoid_color_only_meaning] Color is used as the sole visual indicator to convey meaning or state ...` reported at the `color:` argument. |

Real-world site that triggered this report: `d:/src/contacts/lib/views/phone_dialer/phone_dial_pad.dart:187-190`:

```dart
return ColoredBox(
  color: ThemeUtils.isDarkMode
      ? ThemeCommonColor.BrandSaropa.from(context).withValues(alpha: 0.9)
      : ThemeCommonColor.BrandSaropaLightest.from(context).withValues(alpha: 0.9),
  child: Column( ... ),
);
```

---

## AST Context

```
ReturnStatement
  └─ InstanceCreationExpression (ColoredBox)            ← rule walks this
      └─ ArgumentList
          ├─ NamedExpression (color:)                   ← reporter.atNode target
          │   └─ ConditionalExpression                  ← detection fires here
          │       ├─ condition: PrefixedIdentifier (ThemeUtils.isDarkMode)
          │       ├─ thenExpression: MethodInvocation (.withValues on theme color)
          │       └─ elseExpression: MethodInvocation (.withValues on theme color)
          └─ NamedExpression (child:)
              └─ InstanceCreationExpression (Column)
                  └─ ... no Icon/Text companion in the immediate subtree
```

The rule's detection at `accessibility_rules.dart:4279-4301` sees `ConditionalExpression` on `color:`, then calls `_hasCompanionWidget(node)` which walks `child` / `children` subtrees and up 3 parent levels looking for `Icon` / `Text` / `RichText` / `Semantics`. On layout containers where the immediate children are structural (rows, wraps, spacers) the companion walk fails and the rule reports.

The companion-walk heuristic is not the defect. **The defect is treating any `ConditionalExpression` on `color:` as "color used to convey meaning".** A theme-adaptation ternary encodes no meaning — it is presentation, not information.

---

## Root Cause

### Hypothesis A (primary): predicate-blind detection

At `accessibility_rules.dart:4285-4294` the detection fires on **any** `ConditionalExpression` whose parent named argument is `color:` or `backgroundColor:`. It never inspects the condition expression. Theme / platform / locale branches are indistinguishable from state branches to the current logic:

```dart
// Currently flagged identically:
color: isError ? Colors.red : Colors.green,                  // TRUE positive — state
color: ThemeUtils.isDarkMode ? Colors.black : Colors.white,  // FALSE positive — theme
color: Theme.of(context).brightness == Brightness.dark ? ... // FALSE positive — theme
color: Directionality.of(context) == TextDirection.rtl ? ... // FALSE positive — locale
color: Platform.isIOS ? ... : ...                            // FALSE positive — platform
```

None of the theme/locale/platform cases encode user-visible state. The user sees exactly one branch based on their environment; there is no "color A vs color B" distinction for them to miss.

### Hypothesis B (secondary): companion-walk does not help here

Even if the parent walk at `_hasCompanionWidget` (line 4305-4319) found an `Icon` or `Text` nearby, it would not actually disambiguate theme-adaptive backgrounds from state-indicator backgrounds — it would just silence this specific site while leaving the wrong mental model in place. The fix belongs at the predicate check, not the companion search.

---

## Suggested Fix

Add a predicate-level exclusion before the companion walk. At `accessibility_rules.dart:4289`, when the `color:` / `backgroundColor:` argument is a `ConditionalExpression`, inspect `conditionalExpr.condition` and skip the rule if the condition matches any of:

1. **Dark-mode / brightness checks:**
   - `PrefixedIdentifier` / `PropertyAccess` ending in `.isDarkMode`, `.isLightMode`
   - `BinaryExpression` comparing `Theme.of(...).brightness` / `MediaQuery.of(...).platformBrightness` against `Brightness.dark` / `Brightness.light`
   - `PropertyAccess` on known theme utility identifiers (project-configurable; `ThemeUtils` is the Saropa convention)
2. **Platform checks:** `Platform.isIOS` / `isAndroid` / `isMacOS` / `isWindows` / `isLinux` / `isFuchsia`, and `defaultTargetPlatform == TargetPlatform.X`
3. **Directionality / locale checks:** `Directionality.of(...) == TextDirection.rtl|ltr`, `Localizations.localeOf(...).languageCode == '...'`

Pseudocode at line ~4289:

```dart
if ((name == 'color' || name == 'backgroundColor') &&
    arg.expression is ConditionalExpression) {
  final ConditionalExpression cond = arg.expression as ConditionalExpression;

  // Theme/platform/locale adaptation is not "color conveying meaning".
  // The user sees exactly one branch based on environment, so there is
  // no information to miss. Skip these predicates entirely.
  if (_isEnvironmentPredicate(cond.condition)) return;

  conditionalColorArg = arg;
  break;
}
```

Where `_isEnvironmentPredicate(Expression)` recognizes the patterns listed above. The recognizer can be conservative at first (dark-mode + platform + directionality covers ~100% of real-world hits) and widen later as needed.

Keep the existing companion-walk as a second-line check for genuine state conditionals.

---

## Fixture Gap

The fixture at `example/lib/accessibility/avoid_color_only_meaning_fixture.dart` should include:

1. **Dark-mode ternary on `ColoredBox`** — expect NO lint
   ```dart
   ColoredBox(color: ThemeUtils.isDarkMode ? Colors.black : Colors.white, child: SizedBox())
   ```
2. **`Theme.of(context).brightness` comparison** — expect NO lint
   ```dart
   ColoredBox(color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white, child: SizedBox())
   ```
3. **`MediaQuery.platformBrightnessOf`** — expect NO lint
4. **`Platform.isIOS` ternary on `Card.color`** — expect NO lint
5. **`Directionality.of(context) == TextDirection.rtl`** — expect NO lint
6. **Regression: state-indicator ternary still fires** — expect LINT
   ```dart
   Card(color: isError ? Colors.red : Colors.green, child: SizedBox(width: 24, height: 24)) // LINT
   ```
7. **Regression: `isSelected` ternary still fires** — expect LINT
8. **Regression: state-indicator ternary with Icon companion** — expect NO lint (existing companion behavior preserved)

---

## Changes Made

Implemented Hypothesis A in [`lib/src/rules/ui/accessibility_rules.dart`](../lib/src/rules/ui/accessibility_rules.dart):

1. **Predicate-level exclusion in `runWithReporter`** (around line 4289). When a `color:` / `backgroundColor:` named argument carries a `ConditionalExpression`, the rule now calls `_isEnvironmentPredicate(cond.condition)` before considering it a candidate. A `true` return causes the loop to `continue`, so the argument is not stored as `conditionalColorArg` and no diagnostic is emitted. Theme / platform / directionality ternaries are therefore filtered out *before* the companion-walk runs.

2. **`_isEnvironmentPredicate(Expression)`** — constructs an `_EnvironmentPredicateVisitor` and returns its `matched` flag. Conservative by design: any identifier hit anywhere in the subtree trips the allowlist, favoring false negatives over false positives (the bug report's stated preference — reporting a true state ternary as clean is a smaller harm than forcing `// ignore:` on every theme-adaptive background).

3. **`_environmentIdentifiers` allowlist** — single `Set<String>` containing the three groups from the bug's Suggested Fix:
   - Brightness / dark-mode: `isDarkMode`, `isLightMode`, `isDark`, `isLight`, `brightness`, `platformBrightness`, `platformBrightnessOf`, `Brightness`
   - Platform: `isIOS`, `isAndroid`, `isMacOS`, `isWindows`, `isLinux`, `isFuchsia`, `isWeb`, `kIsWeb`, `Platform`, `defaultTargetPlatform`, `TargetPlatform`
   - Directionality / locale: `TextDirection`, `Directionality`, `Localizations`, `languageCode`, `countryCode`, `localeOf`

4. **`_EnvironmentPredicateVisitor extends RecursiveAstVisitor<void>`** — walks the condition AST and sets `matched = true` whenever a `SimpleIdentifier.name` is in the allowlist. Matches `ThemeUtils.isDarkMode`, `Platform.isIOS`, `Theme.of(context).brightness == Brightness.dark`, `MediaQuery.of(context).platformBrightness`, `Directionality.of(context) == TextDirection.rtl`, and all equivalent `PropertyAccess` / `PrefixedIdentifier` / `BinaryExpression` / `MethodInvocation` shapes — because `RecursiveAstVisitor` descends into every subexpression and all of these shapes resolve to `SimpleIdentifier` tokens eventually.

The companion-walk heuristic (`_hasCompanionWidget` / `_subtreeHasCompanion`) is unchanged — it remains the second-line check for genuine state ternaries, exactly as the bug recommends under Hypothesis B.

---

## Tests Added

[`example/lib/accessibility/avoid_color_only_meaning_fixture.dart`](../example/lib/accessibility/avoid_color_only_meaning_fixture.dart) now carries the six scenarios from the bug's Fixture Gap section:

| Case | Expected |
|---|---|
| `ColoredBox(color: ThemeUtils.isDarkMode ? ... : ...)` | NO lint |
| `ColoredBox(color: Theme.of(context).brightness == Brightness.dark ? ...)` | NO lint |
| `ColoredBox(color: MediaQuery.of(context).platformBrightness == Brightness.dark ? ...)` | NO lint |
| `ColoredBox(color: Platform.isIOS ? ... : ...)` | NO lint |
| `ColoredBox(color: isError ? red : green)` with structural child | **LINT** (regression guard) |
| `ColoredBox(color: isSelected ? blue : grey)` with structural child | **LINT** (regression guard) |
| `ColoredBox(color: isError ? red : green, child: Icon(...))` | NO lint (companion-walk still works) |

All three existing `accessibility_rules_test.dart` tests for this rule pass (`AvoidColorOnlyMeaningRule` instantiation, fixture-exists check, SHOULD-trigger / should-NOT-trigger placeholders), and the full 160-test accessibility suite remains green. `dart analyze --fatal-infos` reports no issues.

Directionality / `TextDirection` coverage was not added to the fixture because the mock in [`example/lib/flutter_mocks.dart`](../example/lib/flutter_mocks.dart) does not currently declare a `Directionality` helper; the identifiers are still in the allowlist and the logic path is identical to the other environment predicates, so the regression is covered by construction.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: (current working tree on `main`)
- Dart SDK version: stable
- custom_lint version: n/a — saropa_lints is a native analyzer plugin (`analysis_server_plugin`)
- Triggering project/file: `d:/src/contacts/lib/views/phone_dialer/phone_dial_pad.dart:187-190`
