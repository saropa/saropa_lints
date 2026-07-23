# BUG: `avoid_debug_print` — contradicts `prefer_debug_print` and penalizes correct Flutter code

**Status: Fixed**

Created: 2026-07-20
Rule: `avoid_debug_print`
File: `lib/src/rules/testing/debug_rules.dart` (line ~85)
Severity: High — ships a WARNING against Flutter's own recommended console function
Rule version: v4 | Since: v1.5.1 | Updated: v4.13.0

---

## Summary

`avoid_debug_print` warns on every `debugPrint()` call and tells users to replace it with "a structured logging package." `prefer_debug_print` (same file, line ~552) warns on every `print()` call and tells users to replace it with `debugPrint()`. These two rules directly contradict each other: one says "use debugPrint," the other says "don't use debugPrint."

For any project that does NOT have a custom logging wrapper (the vast majority of Flutter projects), `debugPrint` IS the correct, Flutter-recommended function for console output. Flagging it as a code smell penalizes correct code.

The rule was written for one project (Saropa Contacts) that has a custom `debug()` wrapper routing through `debugPrint` internally. That project-specific preference was encoded as a general-purpose lint rule and shipped to all users.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_debug_print'" lib/src/rules/
# lib/src/rules/testing/debug_rules.dart:108: 'avoid_debug_print',
```

**Emitter registration:** `lib/src/rules/testing/debug_rules.dart:85`
**Rule class:** `AvoidDebugPrintRule` — registered in `lib/saropa_lints.dart:224`
**Tier:** `lib/src/tiers.dart:1585`

---

## The Contradiction

| Rule | Message | Advice |
|------|---------|--------|
| `prefer_debug_print` | `print()` should use `debugPrint()` | Use `debugPrint` |
| `avoid_debug_print` | `debugPrint` bypasses structured logging | Don't use `debugPrint` |

A user who enables both rules has no valid console output function. `print()` fires `prefer_debug_print`. `debugPrint()` fires `avoid_debug_print`. The only escape is a third-party logging package — which is a project-architecture decision, not something a lint plugin should force.

---

## The `isInsideLoggingSink` Exemption Is Project-Specific

The rule exempts functions named `debug*`, `_debug*`, `breadcrumb`, or `_breadcrumb` (line 145-163). These are the internal function names of the Saropa Contacts `debug.dart` logging wrapper. No other Flutter project has functions with these names serving this purpose. This exemption logic is a direct leak of one project's internal architecture into a public lint rule.

---

## Quick Fix Is Destructive

The quick fix (`CommentOutDebugPrintFix`) comments out the `debugPrint` statement. For a user who has no alternative logging wrapper, this silently removes their only diagnostic output. Commenting out code is not a fix — it is suppression.

---

## Options

1. **Remove `avoid_debug_print` entirely.** `prefer_debug_print` already covers the `print()` → `debugPrint()` upgrade path. Users with custom logging wrappers can write a project-local lint or use `// ignore:` on `prefer_debug_print` and enable a custom rule.

2. **Disable by default, opt-in only.** Keep the rule but set it to `false` in the default config. Projects with structured logging can enable it explicitly. This still ships the contradiction but doesn't inflict it on users who haven't opted in.

3. **Make the two rules mutually exclusive.** If `prefer_debug_print` is enabled, `avoid_debug_print` auto-disables (or vice versa). Adds complexity for no real gain.

Option 1 is the clean fix.

---

## Fixture Gap

No fixture test validates the interaction between the two rules. A user enabling both rules simultaneously should either get a configuration error or one rule should yield.

---

## Environment

- saropa_lints version: current (tiers.dart shows both rules active)
- Dart SDK version: current
- Triggering project: saropa_contacts (`analysis_options.yaml:837`)

---

## Finish Report (2026-07-20)

**Resolution:** Option 1 — complete removal of `avoid_debug_print` and its quick fix `CommentOutDebugPrintFix`.

**Root cause:** The rule encoded a project-specific preference (Saropa Contacts' custom `debug()` wrapper) as a general-purpose lint. For the majority of Flutter projects that lack a custom logging wrapper, `debugPrint()` is the correct, Flutter-recommended console output function. The rule directly contradicted `prefer_debug_print`, which recommends `debugPrint()` as the upgrade path from `print()`.

**Changes across 20+ files:**
- Deleted `AvoidDebugPrintRule` class, public `isInsideLoggingSink` helper, and `CommentOutDebugPrintFix` quick fix file.
- Removed from all registration surfaces: `_allRuleFactories` in `saropa_lints.dart`, `recommendedOnlyRules` in `tiers.dart`, `comprehensive.yaml`, `rule_pack_codes_generated.dart`, both `analysis_options.yaml` files.
- Removed from extension metadata: `rules_catalog.json`, `ruleTierDefinitions.ts`, `rulePackDefinitions.ts`.
- Deleted fixture `example/lib/debug/avoid_debug_print_fixture.dart` and removed `expect_lint` from shared fixture.
- Updated 6 test files that used `avoid_debug_print` as example data (swapped to `avoid_unguarded_debug`).
- Updated 4 migration/doc guides and 2 `config_loader.dart` doc comments.

**Validation:** 55 unit tests + 24 tier/plugin integrity tests pass. No remaining source references to the removed rule outside generated report files.

**Not changed:** The private `_isInsideLoggingSink` in `error_handling_rules.dart` is a separate copy used by a different rule and was unaffected. `prefer_debug_print` and `avoid_unguarded_debug` remain active and cover the `print()` → `debugPrint()` and "guard with kDebugMode" use cases respectively.
