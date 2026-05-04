# BUG: `require_rtl_layout_support` — False positive in physical-corner enum mapper; ignore directive on enclosing function does not suppress

**Status: Fixed (false-positive aspect, Hypothesis A / Suggested Fix #1)**

Created: 2026-05-03
Rule: `require_rtl_layout_support`
File: `lib/src/rules/ui/internationalization_rules.dart` (class `RequireRtlLayoutSupportRule`, `runWithReporter` ~2750; `_code` registered ~2725)
Severity: False positive (High — forces every consumer of the affected API to annotate, and the natural single-directive suppression doesn't work)
Rule version: v1 (per `LintCode` message suffix `{v1}`)

---

## Summary

Two distinct problems on the same site:

1. **False positive on physical-corner mapping.** The rule fires on `Alignment.topLeft` / `Alignment.topRight` / `Alignment.bottomLeft` / `Alignment.bottomRight` inside a switch expression that maps an enum whose own member names (`topLeft`, `topRight`, `bottomLeft`, `bottomRight`) commit to physical-corner semantics by API contract. Mapping these to `AlignmentDirectional.*Start/*End` would silently flip the gradient corner under RTL — the opposite of what the enum API promises its callers.

2. **Suppression is unergonomic.** The rule reports on each leaf `PrefixedIdentifier` (`Alignment.topLeft`) inside switch arms. Dart's `// ignore:` is line-immediate, so a single directive placed above the enclosing arrow function (the natural location) suppresses only the function signature line, not the four arms beneath it. There is no single line at which one `// ignore: require_rtl_layout_support` can silence all four diagnostics. Workarounds are all bad: `// ignore_for_file:` is over-broad; per-arm ignores clutter the switch.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_rtl_layout_support'" lib/src/rules/
# lib/src/rules/ui/internationalization_rules.dart:2725:    'require_rtl_layout_support',

# Negative — rule is NOT defined in saropa_drift_advisor
grep -rn "'require_rtl_layout_support'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/ui/internationalization_rules.dart:2725`
**Rule class:** `RequireRtlLayoutSupportRule` — registered in `lib/src/rules/all_rules.dart`, listed in `lib/src/tiers.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (owner `_generated_diagnostic_collection_name_#3`)

---

## Reproducer

Minimal pattern — an enum whose member names declare physical corners, mapped to `Alignment` values inside an arrow-bodied switch expression. The enclosing `// ignore:` is the natural placement a developer reaches for; it does not suppress.

```dart
import 'package:flutter/material.dart';

enum AlignmentOption { topLeft, topRight, bottomLeft, bottomRight }

class Mapper {
  // The enum names declare PHYSICAL corners. Callers asking for `topLeft` expect the
  // gradient to stay on the same screen edge regardless of locale direction. Mapping
  // these to AlignmentDirectional.*Start/*End would silently flip in RTL — the opposite
  // of the enum API contract.
  // ignore: require_rtl_layout_support -- enum carries physical-corner semantics
  Alignment toAlignment(AlignmentOption value) => switch (value) {
    AlignmentOption.topLeft => Alignment.topLeft,        // LINT — but should NOT lint
    AlignmentOption.topRight => Alignment.topRight,      // LINT — but should NOT lint
    AlignmentOption.bottomLeft => Alignment.bottomLeft,  // LINT — but should NOT lint
    AlignmentOption.bottomRight => Alignment.bottomRight,// LINT — but should NOT lint
  };
}
```

**Downstream example:** `contacts/lib/components/primitive/gradient/gradient_overlay_corner.dart:101-106` — `GradientOverlayCorner._toAlignment` maps the public `AlignmentOption` enum (whose member names are physical corners) to `Alignment` values for a `RadialGradient.center`. The widget's API explicitly promises physical-corner placement; flipping under RTL would break every caller.

**Frequency:** Always — every `Alignment.{centerLeft,centerRight,topLeft,topRight,bottomLeft,bottomRight}` reference flags, regardless of whether the surrounding code is provably enforcing physical semantics by API contract.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected (a)** | No diagnostic when the `Alignment.*Left/*Right` value is the right-hand side of a switch arm whose pattern is an enum constant of the same physical-corner name. The mapping is identity-by-name and the enum's public API has already committed to physical semantics. |
| **Expected (b)** | If the rule must still fire, it should report at a node where one `// ignore:` directive can suppress the group — e.g. the enclosing `MethodDeclaration` / `FunctionExpression` / `SwitchExpression`. Today the leaf-node placement makes single-directive suppression impossible. |
| **Actual** | Four separate `[require_rtl_layout_support] Hardcoded left/right directional value detected ... {v1}` diagnostics, one per switch arm. `// ignore:` placed above the function declaration suppresses nothing in the arms (it only covers the function signature line, which has no diagnostic). |

---

## AST Context

```
MethodDeclaration (toAlignment)
  └─ FunctionExpression (=> body)
      └─ SwitchExpression
          ├─ SwitchExpressionCase (AlignmentOption.topLeft => ...)
          │   └─ PrefixedIdentifier (Alignment.topLeft)   ← node reported here
          ├─ SwitchExpressionCase (AlignmentOption.topRight => ...)
          │   └─ PrefixedIdentifier (Alignment.topRight)  ← node reported here
          ├─ SwitchExpressionCase (AlignmentOption.bottomLeft => ...)
          │   └─ PrefixedIdentifier (Alignment.bottomLeft)← node reported here
          └─ SwitchExpressionCase (AlignmentOption.bottomRight => ...)
              └─ PrefixedIdentifier (Alignment.bottomRight)← node reported here
```

The rule's `addPrefixedIdentifier` callback (`internationalization_rules.dart:2763`) reports on `node` (the `PrefixedIdentifier` itself, ~2776). With four sibling arms, four sibling reports — and no enclosing single line is the "next line" for any of them, so `// ignore:` placed above the function signature covers only line 1 of the function and not any arm.

---

## Root Cause

### Hypothesis A — Reporting node is too low for a group pattern

`reporter.atNode(node)` at `internationalization_rules.dart:2776` reports on the leaf `PrefixedIdentifier`. When the same flagged construct repeats across all arms of a single switch expression — a strong signal of a deliberate enum-mapping function — there is no way for a developer to suppress the group with one `// ignore:`. The rule does not consider the enclosing context.

### Hypothesis B — No semantic exception for "physical-corner mapper" pattern

The rule treats every `Alignment.topLeft` reference identically. It has no recognition for the case where:
- The reference is the right-hand side of a switch arm,
- The arm's pattern is an enum constant whose name matches the `Alignment.*` member name,
- All arms in the switch follow the same `EnumValue.name => Alignment.name` shape.

That shape is by definition a physical-corner adapter — flipping under RTL is wrong by construction.

### Hypothesis C — `_alignmentLeftRight` set has no opt-out

The rule's static set at `internationalization_rules.dart:2740-2747` flags the names unconditionally. There is no allowlist for "physical alignment is the API contract" sites and no annotation handle (e.g. `@physicalAlignment`) the rule could honor.

---

## Suggested Fix

Pick one (any of these closes the suppression-ergonomics gap; the first two also close the false-positive aspect):

1. **Add a semantic exception (preferred).** Before reporting on a `PrefixedIdentifier` whose prefix is `Alignment` and identifier is in `_alignmentLeftRight`, walk up the AST. If the parent is a `SwitchExpressionCase` whose pattern is an enum constant whose simple name equals the identifier (e.g. `AlignmentOption.topLeft => Alignment.topLeft`), skip reporting. This recognizes the physical-corner-mapper pattern without any annotation.

2. **Honor an enclosing-declaration ignore.** Before reporting, check whether the closest enclosing `MethodDeclaration` / `FunctionDeclaration` / `FunctionExpression` has a `// ignore: require_rtl_layout_support` (or `// ignore: saropa_lints/require_rtl_layout_support`) on the line directly above. If yes, skip reporting on every leaf inside that function. This makes the natural placement work.

3. **Group-report on the switch expression.** When the rule fires multiple times within the same `SwitchExpression`, collapse to a single report on the `SwitchExpression` node. One `// ignore:` directly above the switch (or above the arrow function) then suppresses the group.

4. **Document the workaround in the rule's correction message.** If none of the above is acceptable, at minimum mention that physical-corner adapters require `// ignore_for_file:` because per-line `// ignore:` cannot reach inside switch-expression arms with a single directive.

---

## Fixture Gap

The fixture at `example*/lib/ui/require_rtl_layout_support_fixture.dart` should include:

1. **Physical-corner enum mapper, arrow body** — expect NO lint (after fix). The exact reproducer shape above.
2. **Physical-corner enum mapper, block body with `return switch`** — expect NO lint. Same semantic, different syntactic shape.
3. **Mixed mapper (some arms map to physical, others to directional)** — expect LINT only on physical arms. Confirms the "all arms identity-mapped" shortcut doesn't accidentally let through a misuse.
4. **Plain `Alignment.topLeft` outside a switch arm** — expect LINT (regression check; the fix must not weaken normal detection).
5. **`// ignore: require_rtl_layout_support` on the line above the enclosing function** — expect NO lint anywhere inside that function (validates suggested fix #2 if adopted).

---

## Changes Made

Adopted **Suggested Fix #1** (semantic exception for the physical-corner mapper pattern). The `addPrefixedIdentifier` callback in `RequireRtlLayoutSupportRule.runWithReporter` now consults a new private predicate `_isIdentityEnumMapperArm(node, identifier)` before reporting on `Alignment.*Left/*Right` and `TextAlign.left/right` references. The predicate returns `true` only when:

1. `node.parent` is a `SwitchExpressionCase`,
2. `node` is exactly that case's `expression` (not nested in a larger expression — e.g. `MyEnum.x => Alignment.topLeft.add(...)` would still report),
3. The case's `guardedPattern.pattern` is a `ConstantPattern`,
4. The pattern's `expression` is a `PrefixedIdentifier` whose simple name equals the lint target's identifier (`AlignmentOption.topLeft` matches `Alignment.topLeft`).

When all four hold, the rule returns early without reporting. Non-identity mappings (`DirectionOption.start => Alignment.topLeft`) still fire — only same-named arms are excluded, since only those carry the physical-corner API contract.

Hypothesis B (no semantic exception) is closed by this change. Hypothesis A (reporting node too low for group suppression) is partially closed — for the physical-corner shape there is now no diagnostic to suppress, so the group-suppression problem disappears in practice. Other suppression-ergonomics gaps (e.g. honoring `// ignore:` on the enclosing function for genuinely-flagged cases) remain open and tracked separately.

Files touched:

- `lib/src/rules/ui/internationalization_rules.dart` — added `_isIdentityEnumMapperArm` static helper; gate both `Alignment.*` and `TextAlign.left/right` reports through it.
- `example/lib/internationalization/require_rtl_layout_support_fixture.dart` — replaced the stub with concrete BAD / GOOD / regression sections.
- `test/rules/ui/require_rtl_layout_support_physical_corner_mapper_test.dart` — added behavioral and AST-shape tests.
- `CHANGELOG.md` — `[Unreleased] / Fixed` entry.

---

## Tests Added

- `test/rules/ui/require_rtl_layout_support_physical_corner_mapper_test.dart`
  - **Registration & fixture sanity** — rule is in `allSaropaRules`; fixture exists and contains the named sections.
  - **Negative regression** — the `_PhysicalCornerMapper{ArrowBody, BlockBody}` slice of the fixture must contain NO `expect_lint:` markers (failing this means the fix has been weakened or reverted).
  - **Positive regression** — the `_NonIdentityMapper` slice must contain exactly TWO `expect_lint:` markers (failing this means the fix has accidentally been broadened to silence non-identity arms).
  - **AST predicate (negative)** — a parsed `final a = Alignment.topLeft;` produces a `PrefixedIdentifier` whose parent is NOT `SwitchExpressionCase`, so the predicate cannot match.
  - **AST predicate (positive)** — a parsed `AlignmentOption.topLeft => Alignment.topLeft` arm produces the four AST features the predicate keys on (parent kind, expression identity, ConstantPattern, name match).
  - **AST predicate (mismatch)** — a parsed `DirectionOption.start => Alignment.topLeft` arm produces a name mismatch, confirming the rule continues to fire.
- `example/lib/internationalization/require_rtl_layout_support_fixture.dart` — exercises the real visitor end-to-end via `fixture_lint_integration_test.dart` (custom_lint / `dart analyze`).

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.3.3
- Dart SDK version: stable
- custom_lint version: n/a — saropa_lints uses `analysis_server_plugin` directly
- Triggering project/file: `contacts/lib/components/primitive/gradient/gradient_overlay_corner.dart:101-106`
