# BUG: `avoid_color_only_meaning` — `Common*` / `App*` / `Brand*` wrapper widgets are not recognized as Icon/Text companions

**Status: Fixed (2026-04-25)**  
**Archived:** moved from `bugs/` on 2026-04-25.

Created: 2026-04-25
Rule: `avoid_color_only_meaning`
File: `lib/src/rules/ui/accessibility_rules.dart` (line ~4267, `_companionWidgets`; line ~4382, `_expressionHasCompanion`)
Severity: False positive
Rule version: v1+ (post-Option-A) | Since: unknown | Updated: unknown

---

## Implementation Notes

Implemented in `lib/src/rules/ui/accessibility_rules.dart`:
- Added `_projectWrapperPrefixes` for `Common`, `App`, and `Brand`.
- Replaced direct `_companionWidgets.contains(typeName)` calls with `_isCompanionType(typeName)`.
- `_isCompanionType` accepts direct companions and prefixed wrapper companions whose suffix exactly matches known companion widgets.

Regression coverage added in `example/lib/accessibility/avoid_color_only_meaning_fixture.dart`:
- GOOD: `CommonIcon`, `CommonText`, `BrandIcon`, `AppText` wrappers with conditional colors.
- BAD: `AppCustomLabel` remains linted to guard against over-broad prefix matching.

Also documented in `test/false_positive_fixes_test.dart` under the `avoid_color_only_meaning` false-positive section, with fixture shape assertions in `test/avoid_color_only_meaning_fixture_test.dart`.

---

## Summary

Follow-up to
[avoid_color_only_meaning_false_positive_checkbox_and_iconswap_companions.md](./avoid_color_only_meaning_false_positive_checkbox_and_iconswap_companions.md)
(Option A merged — Checkbox/Switch/Radio added).

The same report flagged a second category that did NOT land in Option A:
project design-system wrapper widgets like `CommonText`, `CommonIcon`,
`AppText`, `BrandIcon`. These are thin wrappers over their Material
counterparts, but `_companionWidgets.contains(typeName)` does an exact
string match — so the rule is blind to renamed wrappers even when an
icon-swap (the canonical non-color signal) IS present in the subtree.

This is a real FP in the contacts repo at
`lib/components/main_layout/search/search_item_toggle.dart:46`, where the
selected/unselected state is conveyed by a `CommonIcon` swap
(`filter.icon → CheckTickYesSuccess`) — a perceivable non-color signal —
but the lint still fires because `CommonIcon != Icon`.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_color_only_meaning'" lib/src/rules/
# lib/src/rules/ui/accessibility_rules.dart:4239:    'avoid_color_only_meaning',
```

**Emitter registration:** `lib/src/rules/ui/accessibility_rules.dart:4239`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
// Project-defined thin wrappers — common pattern in design systems.
class CommonIcon extends StatelessWidget {
  const CommonIcon({required this.iconCommon, super.key});
  final IconData iconCommon;
  @override
  Widget build(BuildContext context) => Icon(iconCommon);
}

class CommonText extends StatelessWidget {
  const CommonText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text);
}

class FilterToggle extends StatelessWidget {
  final bool isSelected;
  final IconData filterIcon;

  @override
  Widget build(BuildContext context) {
    // LINT — but should NOT lint
    // The CommonIcon swaps `filterIcon` → `Icons.check_circle` when
    // selected. That icon swap IS the perceivable non-color signal — but
    // _companionWidgets exact-match against 'Icon' / 'Text' doesn't
    // recognize CommonIcon as a companion.
    return Card(
      color: isSelected
          ? Colors.green.shade100
          : Colors.white,
      child: Row(
        children: <Widget>[
          CommonIcon(
            iconCommon: isSelected ? Icons.check_circle : filterIcon,
          ),
          const CommonText('Label'),
        ],
      ),
    );
  }
}
```

**Frequency:** Always — every project that uses a `Common*`/`App*`/`Brand*`
wrapper around `Icon` / `Text` / `RichText` is invisible to the companion
search, regardless of whether a non-color signal is genuinely present.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `CommonIcon` swap is a perceivable non-color signal |
| **Actual** | `[avoid_color_only_meaning] Color is used as the sole visual indicator…` reported on the Card's `color:` arg |

---

## AST Context

```
InstanceCreationExpression (Card)              ← reported on its `color:` arg
  └─ ArgumentList
      ├─ NamedExpression (color)               ← reported NamedExpression
      │   └─ ConditionalExpression  (isSelected ? ... : ...)
      └─ NamedExpression (child)
          └─ InstanceCreationExpression (Row)
              └─ NamedExpression (children)
                  └─ ListLiteral
                      ├─ InstanceCreationExpression (CommonIcon)   ← icon-swap signal here
                      └─ InstanceCreationExpression (CommonText)
```

`_subtreeHasCompanion` walks Card → Row → ListLiteral → each child:
- `CommonIcon.typeName == 'CommonIcon'` — not in `_companionWidgets` → skip
- `CommonText.typeName == 'CommonText'` — not in `_companionWidgets` → skip

The rule reports as if no companion exists.

---

## Root Cause

`_companionWidgets` and `_expressionHasCompanion`
(`accessibility_rules.dart:4380`) use exact-string match against the
constructor type lexeme. There's no escape hatch for project wrapper
widgets:

```dart
if (expr is InstanceCreationExpression) {
  final String typeName = expr.constructorName.type.name.lexeme;
  if (_companionWidgets.contains(typeName)) return true;
  ...
}
```

The original report (Option A) deliberately scoped to form-state widgets
to keep the change minimal and low-risk. Project-wrapper recognition was
filed as Option B (heuristic prefix match) and Option C (per-project
allowlist). **Option B shipped in saropa_lints (2026-04-25);** Option C remains a possible follow-up for explicit per-project companion names.

---

## Suggested Fix

### Option B (heuristic — quickest)

Recognize widget names that begin with a small allowlist of project
prefixes when the suffix matches an existing companion name:

```dart
// Add to AvoidColorOnlyMeaningRule
static const Set<String> _projectWrapperPrefixes = <String>{
  'Common', 'App', 'Brand',
};

bool _isCompanionType(String typeName) {
  if (_companionWidgets.contains(typeName)) return true;
  for (final String prefix in _projectWrapperPrefixes) {
    if (typeName.startsWith(prefix)) {
      final String rest = typeName.substring(prefix.length);
      if (_companionWidgets.contains(rest)) return true;
    }
  }
  return false;
}
```

Trade-off: matches `CommonIconButton` (which IS interactive, not just an
informational wrapper). False suppressions are possible. Acceptable risk
because the rule's purpose is "is there ANY non-color signal" — an
interactive companion still satisfies that.

### Option C (durable — preferred for v2)

Expose configuration in `analysis_options.yaml` so each project can declare
its design-system wrapper names explicitly:

```yaml
saropa_lints:
  rules:
    avoid_color_only_meaning:
      additionalCompanionWidgets:
        - CommonIcon
        - CommonText
        - CommonChip
        - AppLabel
```

This is the preferred long-term fix because:
- The set of project wrappers is project-specific knowledge the rule
  cannot infer.
- Allowlists explicitly opt-in rather than implicitly matching prefixes.
- Avoids the `CommonIconButton` false-suppression risk of Option B.

Recommend: ship Option B as a fast hot-patch (covers most projects with
`Common`/`App`/`Brand` conventions), plan Option C for the next config
revision.

---

## Fixture Gap

The fixture should add:

1. Card with conditional color, child contains a `CommonIcon` whose
   `iconCommon` arg is itself a conditional (icon swap) — expect NO lint
   after Option B/C.
2. Card with conditional color, child contains a `CommonText` —
   expect NO lint after Option B/C.
3. Card with conditional color, child contains a `BrandIcon` —
   expect NO lint after Option B/C (covers `Brand` prefix).
4. Card with conditional color, child contains an `AppText` —
   expect NO lint after Option B/C.
5. Card with conditional color, child contains an `AppCustomLabel`
   (NOT matching any base companion name) — expect LINT (regression
   guard for over-broad prefix match).
6. Card with conditional color, child contains a `CommonIconButton`
   (interactive wrapper) — expect NO lint under Option B (acceptable
   over-suppression) or LINT under Option C with strict allowlist.

**Fixture status (2026-04-25):** Items 1–5 are covered in `example/lib/accessibility/avoid_color_only_meaning_fixture.dart` (using `Material` where the mock `Card` has no `color:`). Item 6 is not duplicated in the fixture (acceptable optional over-suppression under Option B).

---

## Environment

- saropa_lints version: post-Option-A (~v12.5.x candidate)
- Triggering project: `D:/src/contacts`
- Triggering file: `lib/components/main_layout/search/search_item_toggle.dart` (~L46 — CommonIcon swap)
