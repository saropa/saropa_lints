# BUG: `require_ios_deployment_target_consistency` — False positive on rule name strings in registry files

**Status: Fixed**

**Resolution note:** Duplicate of the false positive already fixed same-day in commit
`f3eeb695` ("fix: remove 'async' from iOS deployment target rule + add
data-literal guard to 6 iOS rules") — see
`plans/history/2026.09/2026.09.05/require_ios_deployment_target_consistency_async_false_positive.md`.
That commit removed the overly broad `'async'` entry from `_ios15PlusApis` and
added the shared `isDataLiteralElement()` guard (`lib/src/literal_context_utils.dart`),
which already skips string literals whose immediate parent is a
`ListLiteral`/`SetOrMapLiteral`/`MapLiteralEntry` — exactly the shape of the
rule-name registries in `tiers.dart`, `rule_pack_codes_generated.dart`, and
`rule_category_map.dart` cited below. Verified: none of the current
`_ios15PlusApis` keys (`SharePlay`, `GroupActivities`, `AttributedString`)
appear as substrings in any of the three cited files, and the guard is in
place at `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart:1831`.
Added two additional GOOD fixture cases (Set-literal and Map-value) to
`example/lib/ios/require_ios_deployment_target_consistency_fixture.dart` to
lock in the specific "rule-name string in a registry" scenario this report
described.

Created: 2026-09-05
Rule: `require_ios_deployment_target_consistency`
File: `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart` (line ~1788)
Severity: False positive
Rule version: v2

---

## Summary

The rule fires 105 times on `tiers.dart`, `rule_pack_codes_generated.dart`, and `rule_category_map.dart` — files that contain rule *name strings* (e.g. `'require_ios_deployment_target_consistency'`) in tier/category registries. These are string literals naming rules, not iOS API calls. The rule's pattern matcher is triggering on its own name and sibling iOS-related rule names.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_ios_deployment_target_consistency'" lib/src/rules/
# lib/src/rules/platforms/ios_platform_lifecycle_rules.dart:1788:    'require_ios_deployment_target_consistency',
```

---

## Reproducer

```dart
// These are rule registry entries, not iOS API calls.
// tiers.dart — tier set definitions
final essentialRules = {
  'require_ios_deployment_target_consistency', // LINT — but should NOT lint
  'avoid_platform_specific_imports',
};
```

**Frequency:** Always — every occurrence of the rule name string in registry files.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — these are string literals in a rule registry, not iOS API usage |
| **Actual** | `[require_ios_deployment_target_consistency] API requiring iOS 15+ detected` reported 105 times |

---

## Root Cause

### Hypothesis A: String-matching on tokens instead of API resolution

The rule likely pattern-matches on tokens or identifiers that contain iOS-related keywords rather than resolving actual API calls via the analyzer's type system. Rule name strings like `'require_ios_deployment_target_consistency'` contain `ios` and `deployment_target` substrings that trigger the match.

---

## Suggested Fix

The rule should only fire on actual API calls (method invocations, property accesses) whose resolved element belongs to an iOS-specific SDK. String literals should be excluded from detection. Check that the rule uses `staticElement` / `staticType` resolution rather than string matching.

---

## Fixture Gap

The fixture should include:

1. **String literal containing iOS rule name** — expect NO lint
2. **Map/Set literal with iOS-related string keys** — expect NO lint
3. **Actual iOS API call** — expect LINT

---

## Environment

- saropa_lints version: current (unreleased)
- Dart SDK version: current
- Triggering files: `lib/src/tiers.dart`, `lib/src/config/rule_pack_codes_generated.dart`, `lib/src/scan/rule_category_map.dart`
