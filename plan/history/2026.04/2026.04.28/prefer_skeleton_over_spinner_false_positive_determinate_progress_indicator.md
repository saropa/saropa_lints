# BUG: `prefer_skeleton_over_spinner` — False positive on determinate progress indicators

**Status: Fixed (local)**

Created: 2026-04-28  
Rule: `prefer_skeleton_over_spinner`  
File: `lib/src/rules/widget/ui_ux_rules.dart` (line ~868)  
Severity: False positive  
Rule version: v2 | Since: v2.1.0 | Updated: v4.13.0

---

## Summary

`prefer_skeleton_over_spinner` currently flags determinate progress indicators
(`CircularProgressIndicator(value: ...)`) when they appear inside conditionals.
These are progress meters, not content-loading spinners, so they should not be
reported by a skeleton-loader rule.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_skeleton_over_spinner'" lib/src/rules/
# lib/src/rules/widget/ui_ux_rules.dart:885:    'prefer_skeleton_over_spinner',

# Registration
grep -rn "PreferSkeletonOverSpinnerRule" lib/
# lib/saropa_lints.dart:1803:  PreferSkeletonOverSpinnerRule.new,

# Tier registration
grep -rn "'prefer_skeleton_over_spinner'" lib/src/tiers.dart
# lib/src/tiers.dart:1218:  'prefer_skeleton_over_spinner',

# Negative attribution (sibling repo check)
grep -rn "'prefer_skeleton_over_spinner'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/widget/ui_ux_rules.dart:868`  
**Rule class:** `PreferSkeletonOverSpinnerRule`  
**Diagnostic `source` / `owner` seen downstream:** `dart` (custom lint surfaced via analyzer)

---

## Reproducer

```dart
Widget buildBadgeRing(double progress) {
  if (progress > 0 && progress < 1) {
    // OK: determinate completion meter, not content-loading placeholder
    return CircularProgressIndicator(
      value: progress,
      strokeWidth: 3,
    );
  }
  return const SizedBox.shrink();
}
```

**Frequency:** Always (when progress indicator is nested in a conditional)

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic for determinate `CircularProgressIndicator(value: ...)` used as progress meter |
| **Actual** | `[prefer_skeleton_over_spinner] CircularProgressIndicator for content loading. Prefer skeleton loaders.` |

---

## AST Context

```
MethodDeclaration (buildBadgeRing)
  └─ BlockFunctionBody
      └─ IfStatement
          └─ Block
              └─ ReturnStatement
                  └─ InstanceCreationExpression (CircularProgressIndicator)
                      └─ NamedExpression (value: progress)
```

---

## Root Cause

The rule uses a broad heuristic:

1. Match any `InstanceCreationExpression` of `CircularProgressIndicator` or
   `LinearProgressIndicator`.
2. Walk parents and report if found inside `ConditionalExpression`,
   `IfStatement`, or `IfElement`.

This logic in `PreferSkeletonOverSpinnerRule.runWithReporter` does not inspect
whether the indicator is determinate (`value` provided), so all conditional
progress indicators are treated as loading spinners.

---

## Suggested Fix

In `PreferSkeletonOverSpinnerRule`:

1. For `CircularProgressIndicator`, detect whether a `value:` named argument is
   present and non-null.
2. If determinate, skip reporting (progress meter use case).
3. Keep reporting indeterminate spinner placeholders in conditional loading UI.

Optional extension: apply similar determinate guard to
`LinearProgressIndicator(value: ...)`.

---

## Fixture Gap

The fixture at `example/lib/ui_ux/prefer_skeleton_over_spinner_fixture.dart`
should include:

1. **Determinate circular progress in conditional** — expect **NO** lint.
2. **Determinate linear progress in conditional** — expect **NO** lint.
3. Existing indeterminate spinner in conditional — expect **LINT**.

---

## Changes Made

Implemented in `lib/src/rules/widget/ui_ux_rules.dart`:

1. Added a determinate guard in `PreferSkeletonOverSpinnerRule`:
   - Detects `value:` named argument on progress indicators.
   - Treats `value: null` as indeterminate (still reportable).
   - Skips reporting when `value` is present and non-null.
2. Kept existing conditional-context behavior for indeterminate spinners.

---

## Tests Added

Updated fixture `example/lib/ui_ux/prefer_skeleton_over_spinner_fixture.dart`:

1. Added determinate circular progress in conditional (NO lint expected).
2. Added determinate linear progress in conditional (NO lint expected).
3. Retained existing indeterminate spinner conditional case (LINT expected).

---

## Commits

None in this session yet.

---

## Environment

- saropa_lints version: current workspace checkout
- Dart SDK version: unknown
- custom_lint version: unknown
- Triggering project/file: `D:/src/contacts/lib/components/user/achievements/user_badges_section.dart`
