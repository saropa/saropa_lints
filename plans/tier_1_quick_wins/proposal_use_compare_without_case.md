# PROPOSAL: Suggest Case-Insensitive Comparison Helper for String Equality

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_case_sensitive_path_comparison` (file-path-scoped equivalent)

---

## Summary

Add `use_compare_without_case` to flag `==`/`!=` comparisons between two `String` expressions where at least one side is derived from user input, config, or an external source (heuristically: not a `const`/literal-only comparison), and suggest a case-insensitive comparison helper (e.g. `.toLowerCase() ==` or a `compareWithoutCase()` extension) instead.

**Closes gap:** `flutter_custom_lints` `use-compare-without-case`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Miscellaneous single-rule gaps" theme, which explicitly notes saropa's `avoid_case_sensitive_path_comparison` is scoped to file paths only, not general strings.

---

## Motivation

saropa's existing `avoid_case_sensitive_path_comparison` catches this exact bug class but only for filesystem paths — a narrow slice of where case-sensitivity bugs actually bite (locale-inconsistent OS behavior). The far more common real-world case is comparing user-typed input (email addresses, search queries, enum-like string flags from an API) with `==`, which silently fails whenever casing differs, e.g. rejecting `"Admin"` when the stored role is `"admin"`.

---

## Detection / Behavior

Flag a `==`/`!=` `BinaryExpression` where both operands are statically typed `String`, at least one operand is not a compile-time constant, and neither operand is already wrapped in `.toLowerCase()`/`.toUpperCase()`/a case-normalizing call.

### Should flag (bad code)

```dart
bool isAdmin(String role) {
  return role == 'admin'; // LINT — case-sensitive comparison of external input
}
```

### Should pass (good code)

```dart
bool isAdmin(String role) {
  return role.toLowerCase() == 'admin'; // OK — normalized before comparison
}

const kEnvProd = 'production';
bool isProd(String env) => env == kEnvProd; // OK — both sides are internal constants under our own control
```

---

## Proposed Tier

Tier: Pedantic
Justification: High false-positive risk against intentionally case-sensitive comparisons (enum-like internal constants, IDs, hashes) — needs to start opt-in and graduate only after real-world tuning.

---

## Edge Cases

1. **Comparison against an internal enum-like constant string (e.g. a route name)** — should pass under the "both sides constant" exemption; case sensitivity is intentional and correct there.
2. **Comparison inside a `switch` statement's `case` clauses** — should discuss; `switch` on string literals is a common, usually-intentional exact-match pattern and may need blanket exemption to avoid noise.
3. **`.compareTo(other) == 0`** — should flag identically to `==`; same case-sensitivity bug, different syntax.
4. **String comparison of already-`.toLowerCase()`-normalized values on both sides** — should pass; the rule's job is done.

---

## Alternatives Considered

- **Extend `avoid_case_sensitive_path_comparison` to cover all strings instead of a new rule** — rejected; the path-specific rule's heuristics (path-shaped values, path APIs) are much lower false-positive-risk than general string comparison, so keeping them separate lets each be tuned independently.

---

## Decision

---

## Implementation Notes

---

## Commits

## Finish Report (2026-09-04)

### Issues

- **Rule is completely unregistered — it never runs.** `UseCompareWithoutCaseRule` is not exported from `lib/src/rules/all_rules.dart` (the `data/` export block at lines 51-58 lists `collection_rules.dart`, `equality_rules.dart`, `json_datetime_rules.dart`, `money_rules.dart`, `numeric_literal_rules.dart`, `record_pattern_rules.dart`, `type_rules.dart`, `type_safety_rules.dart` — `use_compare_without_case_rules.dart` is missing), it is absent from `_allRuleFactories` in `lib/saropa_lints.dart`, and it is absent from every tier set in `lib/src/tiers.dart` (verified: no match for `use_compare_without_case` in either file). The class compiles and the fixture/test files reference it directly by import, so nothing in the build catches this — `test/scan/rule_tier_index_test.dart` only asserts that rules *listed in tiers.dart* exist in the plugin factories; it does not assert that every rule *class in `lib/src/rules/`* is reachable from a tier or factory. As shipped, this rule fires for nobody, in no tier, ever. This is the single blocking defect — everything else below is secondary until this is fixed.
- Test file (`test/rules/data/use_compare_without_case_test.dart`) checks `problemMessage.length, greaterThan(50)`. Project convention (CLAUDE.md, this project's rule-authoring standard) requires problem messages **>200 chars**. The actual message is well over 200 chars, but the test's own threshold (50) does not enforce that requirement — a future edit could shrink the message to 51 chars and still pass.

### Concerns

- **No fixture/test coverage for the `PrefixedIdentifier`/`PropertyAccess` branches of `_isConstantString`** (lines 192-198, the `ClassName.constField` case explicitly called out in the code's own comment). This is a completely unexercised code path — if it has a bug (e.g. wrong `Element` type check), nothing would catch it.
- **No fixture for the `0 == a.compareTo(b)` operand order** (zero-literal on the left). Only `a.compareTo(b) == 0` is tested; the symmetric branch in `_stringPairFor` (lines 142-146) that handles the reversed order is unverified.
- **No fixture for `String?` (nullable) operands.** `_isStringTyped` explicitly special-cases `'String?'` display names (line 165), but every fixture operand is non-nullable `String`, so this branch is unverified.
- **Enum `.name` comparisons are a plausible false-positive class not covered by any fixture.** `myEnum.name == 'active'` is a very common exact-tag-match idiom; it will fire under the current logic (neither side is a recognized constant, neither is normalized) even though case sensitivity is intentional and correct there. The proposal's "Edge Cases" section lists route-name-style internal constants but does not consider enum `.name` or JSON/API discriminator fields (`json['type'] == 'success'`) as a named risk, and the rule/fixture doesn't lock in current behavior for either.
- **Potential double-firing with `avoid_case_sensitive_path_comparison`** on file-extension-style String comparisons (e.g. `path.extension == '.png'`, where `extension` returns `String`, not a path object). The proposal's "Alternatives Considered" section says the two rules are kept separate "so each be tuned independently," but nothing prevents both rules from firing on the same line for path-adjacent String comparisons — worth a fixture noting the expected (possibly dual) behavior once the rule is actually wired in.
- `static final String kFoo = 'x';` (non-const) is treated as non-constant by `_isConstantString`, since it checks `VariableElement.isConst` strictly (line 186). This is a defensible, literal reading of "compile-time constant," but codebases that use `static final` instead of `const` for Strings (common when the field needs to live alongside non-const siblings) will see this rule fire where the intent was clearly a stable internal sentinel — same class of noise the "both sides constant" exemption was meant to suppress.

### Opportunities

- None identified beyond what's listed under Concerns — the `_isConstantString` reuse-of-pattern comment (referencing `_isEffectivelyConstantCondition` in `collection_rules.dart`) is a good instance of following existing conventions rather than reinventing one.

### Recommendations

1. **Blocking, do first:** Register the rule — add `export 'data/use_compare_without_case_rules.dart';` to `lib/src/rules/all_rules.dart`, add `UseCompareWithoutCaseRule.new` to `_allRuleFactories` in `lib/saropa_lints.dart`, and add `'use_compare_without_case'` to the appropriate tier set in `lib/src/tiers.dart` (proposal specifies Pedantic tier, consistent with the `RuleStatus.beta` status already set on the class). Without this, none of the rest matters — the rule does not exist to end users.
2. After registration, verify actual firing against the fixture using the scan CLI (`dart run saropa_lints scan example/lib/data --files use_compare_without_case_fixture.dart --format json`, per this project's verification convention) rather than relying on the instantiation-only unit test — this has not been done yet for this rule.
3. Add fixtures for the untested branches named above, in priority order: (a) `ClassName.constField` const exemption, (b) `0 == a.compareTo(b)` reversed order, (c) `String?` operand. These are existing code paths with zero coverage, not new features.
4. Tighten the unit test's message-length assertion from `greaterThan(50)` to `greaterThan(200)` to actually enforce the project's problem-message length convention.
5. Consider (not blocking): add explicit "GOOD near-miss" fixtures for `enum.name == 'literal'` and JSON-discriminator-style (`json['type'] == 'literal'`) comparisons to document current (permissive) behavior, given these are named as the rule's primary false-positive risk and currently have no regression coverage either way.
