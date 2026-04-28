# Plan #067 - prefer_scrollbar_theme_of

**Source:** Flutter SDK 3.7.0 (`flutter/flutter#113237`)  
**Category:** Replacement / Migration  
**Priority:** High (easy, safe autofix)  
**Status:** Implemented

---

## Release-note Intent (normalized)

Replace direct `Theme.of(context).scrollbarTheme` reads with
`ScrollbarTheme.of(context)` so inherited `ScrollbarTheme` widgets in the tree
are respected.

`ScrollbarTheme.of(context)` already falls back to `Theme.of(context)` when no
local `ScrollbarTheme` exists, so this migration is behavior-preserving in the
common case and more correct when nested themes are present.

---

## Exact API Mapping

- **Old pattern:** `Theme.of(<contextExpr>).scrollbarTheme`
- **New pattern:** `ScrollbarTheme.of(<contextExpr>)`

### Scope

- Flutter code only (`package:flutter/...` symbols).
- Expression-level replacement only; no constructor/argument rewrites.

### Non-goals

- Do not rewrite unrelated `Theme.of(context)` access (for color/text/theme).
- Do not rewrite non-Flutter user-defined `Theme` classes.

---

## Proposed Lint Rule

- **Rule name:** `prefer_scrollbar_theme_of`
- **Rule type:** `codeSmell` / migration
- **Default severity:** `INFO`
- **Impact:** `low`
- **Autofix:** Yes (single replacement)

### Detection Strategy

Report when the AST matches:

1. `PropertyAccess` where `propertyName.name == 'scrollbarTheme'`.
2. `realTarget` is a `MethodInvocation`:
   - `methodName.name == 'of'`
   - `target` identifier lexeme is `Theme`
   - single argument preserved as context expression
3. If resolved, ensure `Theme.of` belongs to `package:flutter/...`.
   If unresolved, allow lexical fallback for migration-in-progress code.

### Fix Strategy

Replace entire property-access expression:

- From: `Theme.of(context).scrollbarTheme`
- To: `ScrollbarTheme.of(context)`

Preserve original context argument source verbatim.

---

## False-positive Guards

- `Theme.of(context).colorScheme` -> no lint.
- `_Theme.of(context).scrollbarTheme` (user type) -> no lint.
- `Theme.of(context)` by itself -> no lint.
- Any access not ending in `.scrollbarTheme` -> no lint.

---

## Test Plan

Fixture cases:

- BAD: `Theme.of(context).scrollbarTheme`
- BAD: nested/chained context expression
- GOOD: `ScrollbarTheme.of(context)`
- GOOD: other `Theme.of(context).<otherProperty>`
- GOOD: user-defined `Theme` type

Unit tests:

- Rule appears in registry and recommended tier.
- `requiredPatterns` includes `scrollbarTheme`.
- `fixGenerators` non-empty and fix replacement is exact.

---

## Implementation Checklist

- [x] Confirm migration source (`flutter/flutter#113237`)
- [x] Define concrete old->new API mapping
- [x] Implement rule in `flutter_sdk_migration_rules.dart`
- [x] Add quick fix
- [x] Add fixture BAD/GOOD cases
- [x] Update `flutter_sdk_migration_rules_test.dart`
- [x] Register in `lib/saropa_lints.dart`
- [x] Add to `recommendedOnlyRules` in `tiers.dart`
- [ ] Update `CHANGELOG.md` (defer to release batching)

---

## Shipping Notes

- Safe as INFO + autofix because replacement is syntactic and preserves context.
- No SDK-min gating required in detection; this is a preferred usage migration,
  not a removed-API break.
