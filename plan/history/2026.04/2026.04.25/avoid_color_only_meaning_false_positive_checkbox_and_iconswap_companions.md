# BUG: `avoid_color_only_meaning` — companion-widget set misses Checkbox/Switch/Radio and project-specific `Common*` wrappers

**Status: Implemented (Option A)**

Created: 2026-04-25
Rule: `avoid_color_only_meaning`
File: `lib/src/rules/ui/accessibility_rules.dart` (line ~4267)
Severity: False positive
Rule version: v1 | Since: unknown | Updated: unknown

---

## Summary

`_companionWidgets` (line 4267) is `{'Icon', 'Text', 'RichText', 'Semantics'}`.
That misses two real categories of non-color state signals:

1. **Selection-state form widgets** — `Checkbox`, `Switch`, `Radio`,
   `CheckboxListTile`, `SwitchListTile`, `RadioListTile`. A `Checkbox` is a
   primary state indicator (filled vs empty + tick mark + screen-reader
   announce); when it sits in the same Row as a conditional background
   color, the color is supportive emphasis, not the sole signal — but the
   rule reports anyway.

2. **Wrapper widgets renamed by the host project's design system.** Many
   codebases standardize on `CommonText`, `CommonIcon`, `AppText`,
   `BrandIcon`, etc. These are functional Icon/Text widgets, but
   `_companionWidgets.contains(typeName)` does an exact-string match against
   the constructor type name — so `CommonText` and `CommonIcon` are invisible
   to the companion search even when they're literally just thin wrappers
   over `Icon` / `Text`.

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

### Case 1 — Checkbox sibling carries the primary signal

```dart
class GroupRow extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget avatar;
  final String name;

  @override
  Widget build(BuildContext context) {
    // LINT — but should NOT lint
    // Checkbox at L? IS the primary non-color selection signal: filled vs
    // empty + tick mark + screen-reader announce. The Material's tinted
    // background is supportive emphasis, not the sole indicator.
    return Material(
      color: isSelected
          ? Colors.blue.withAlpha(20)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: <Widget>[
              Checkbox(value: isSelected, onChanged: (_) => onTap()),
              avatar,
              Text(name),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Case 2 — `Common*` wrappers (project design system)

```dart
class CommonText extends StatelessWidget { /* thin wrapper over Text */
  const CommonText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text);
}

class CommonIcon extends StatelessWidget { /* thin wrapper over Icon */
  const CommonIcon({required this.iconCommon, super.key});
  final IconData iconCommon;
  @override
  Widget build(BuildContext context) => Icon(iconCommon);
}

class FilterChipBody extends StatelessWidget {
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    // LINT — but should NOT lint
    // CommonIcon at L? swaps the icon when isSelected (the icon swap is the
    // primary perceivable signal; color is supportive). The rule's exact-
    // string match against 'Icon' / 'Text' does not see CommonIcon /
    // CommonText.
    return Card(
      color: isSelected ? Colors.green.shade100 : Colors.white,
      child: Row(
        children: <Widget>[
          CommonIcon(iconCommon: isSelected ? Icons.check : Icons.filter_alt),
          const CommonText('Label'),
        ],
      ),
    );
  }
}
```

**Frequency:** Always — every site where the only non-color signal is a
sibling form widget (Checkbox/Switch/Radio) or a renamed Common* wrapper.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when a sibling Checkbox/Switch/Radio carries selection state, or a Common*Icon / Common*Text wraps an Icon/Text |
| **Actual** | `[avoid_color_only_meaning] Color is used as the sole visual indicator…` reported on the conditional color arg |

---

## AST Context

```
InstanceCreationExpression (Material)               ← reported on its `color:` arg
  └─ ArgumentList
      ├─ NamedExpression (color)  ← reported NamedExpression
      │   └─ ConditionalExpression  (isSelected ? ... : ...)
      └─ NamedExpression (child)
          └─ InstanceCreationExpression (InkWell)
              └─ NamedExpression (child)
                  └─ InstanceCreationExpression (Padding)
                      └─ NamedExpression (child)
                          └─ InstanceCreationExpression (Row)
                              └─ NamedExpression (children)
                                  └─ ListLiteral
                                      ├─ InstanceCreationExpression (Checkbox)   ← non-color signal here
                                      ├─ ...
                                      └─ ...
```

`_subtreeHasCompanion` walks from Material → InkWell → Padding → Row → Row's
`children:` ListLiteral. Each child is checked: `Checkbox.typeName == 'Checkbox'`,
not in `_companionWidgets` → skip. The Row contains no Icon/Text/RichText/Semantics
literally named, so the search returns false even though Checkbox is right there.

---

## Root Cause

`_companionWidgets` is too narrow. It treats only generic Material primitives
as state indicators:

```dart
static const Set<String> _companionWidgets = <String>{
  'Icon',
  'Text',
  'RichText',
  'Semantics',
};
```

Two missing categories:

1. **Form-state widgets** that ARE the state signal (filled checkbox, thumb
   position on switch, dot in radio): `Checkbox`, `Switch`, `Radio`,
   `CheckboxListTile`, `SwitchListTile`, `RadioListTile`.
2. **Project wrapper widgets** that delegate to Icon/Text under the hood:
   exact-string match has no escape hatch for `Common*` / `App*` / `Brand*`
   prefixes.

---

## Suggested Fix

### Option A — broaden `_companionWidgets` to include form-state widgets

```dart
static const Set<String> _companionWidgets = <String>{
  // Information widgets
  'Icon',
  'Text',
  'RichText',
  'Semantics',
  // Form-state widgets — the widget itself IS the state signal
  'Checkbox',
  'CheckboxListTile',
  'Switch',
  'SwitchListTile',
  'Radio',
  'RadioListTile',
  // Optional: explicit progress / indicator widgets
  'CircularProgressIndicator',
  'LinearProgressIndicator',
};
```

This is a minimal, low-risk change and addresses Case 1 directly.

### Option B — recognize `Common*` / `App*` / `Brand*` prefixes (heuristic)

```dart
bool _isCompanionType(String typeName) {
  if (_companionWidgets.contains(typeName)) return true;
  // Project design-system wrappers: CommonIcon, CommonText, AppIcon, BrandText, etc.
  for (final String prefix in const <String>['Common', 'App', 'Brand']) {
    if (typeName.startsWith(prefix)) {
      final String rest = typeName.substring(prefix.length);
      if (_companionWidgets.contains(rest)) return true;
    }
  }
  return false;
}
```

Trade-off: matches widgets the rule cannot prove are actually thin wrappers
(could be a `CommonIconButton` that does something quite different). The
project's `common-widgets.md` contract does ensure these are wrappers, but
the lint cannot read project docs.

### Option C — make companion set configurable per project

Expose `additionalCompanionWidgets` in `analysis_options.yaml` so each
project can declare its design-system wrappers:

```yaml
saropa_lints:
  rules:
    avoid_color_only_meaning:
      additionalCompanionWidgets:
        - CommonIcon
        - CommonText
        - CommonChip
```

This is the durable fix; Option A is the immediate one.

Implemented: Option A (2026-04-25). The companion widget set now includes
`Checkbox`/`Switch`/`Radio` plus `*ListTile` variants so state-control siblings
are recognized as non-color indicators. Option C remains a future enhancement
for project-defined wrappers.

---

## Fixture Gap

The fixture should include:

1. Material with conditional color, child contains a sibling `Checkbox` —
   expect NO lint after fix.
2. Material with conditional color, child contains a sibling `Switch` —
   expect NO lint after fix.
3. Material with conditional color, child contains `Radio` —
   expect NO lint after fix.
4. Material with conditional color, child contains a `CommonIcon`
   (custom wrapper class) — expect NO lint after fix (Option B/C) or
   continue to LINT (Option A only).
5. Material with conditional color, no companion at all (regression guard) —
   expect LINT.

---

## Environment

- saropa_lints version: see `pubspec.yaml`
- Triggering project: `D:/src/contacts`
- Triggering files:
  - `lib/components/connection/group_share_picker.dart` (~L430 — Checkbox sibling)
  - `lib/components/main_layout/search/search_item_toggle.dart` (~L46 — CommonIcon swap)
