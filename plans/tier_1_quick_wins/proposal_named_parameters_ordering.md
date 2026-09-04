# PROPOSAL: Enforce Consistent Named-Argument Order at Call Sites

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `named_parameters_ordering` to flag call sites where named arguments are passed in an order that does not match the order the named parameters are declared in the function/constructor signature. Requiring call-site order to mirror declaration order makes diffs smaller and call sites easier to scan against the API they invoke.

**Closes gap:** `solid_lints` `named_parameters_ordering` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Dart lets named arguments appear in any order, so two call sites for the same constructor can list the same arguments in unrelated orders — one alphabetical, one by "importance", one arbitrary. That inconsistency makes it harder to visually diff two call sites or to match a call site back to the parameter list while reading. Enforcing declaration order gives one canonical shape for every call.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class Config {
  Config({required this.host, required this.port, this.timeout});
  final String host;
  final int port;
  final Duration? timeout;
}

final config = Config(
  port: 443,
  host: 'example.com', // LINT — `port` passed before `host`, but `host` is declared first
);
```

### Should pass (good code)

```dart
final config = Config(
  host: 'example.com', // OK — matches declaration order
  port: 443,
  timeout: const Duration(seconds: 5),
);
```

---

## Proposed Tier

Tier: Pedantic
Justification: pure call-site style with no runtime effect; belongs alongside other cosmetic ordering rules in the opt-in Pedantic tier.

---

## Edge Cases

1. **Some named parameters omitted at the call site** — should pass as long as the ones present preserve their relative declaration order.
2. **Constructor declared across `super(...)` forwarding with reordered params** — should flag on the call site only, not the forwarding declaration itself.
3. **Redirecting/factory constructors with a different parameter order than the target** — needs discussion; likely evaluate against the immediate signature being called, not the redirect target.
4. **Named parameters interleaved with positional parameters** — should pass for positional ordering (out of scope); only named-argument relative order is checked.

---

## Alternatives Considered

- **Enforce alphabetical order instead of declaration order** — rejected; alphabetical order breaks logical grouping in wide constructors (e.g. related `min`/`max` pairs), whereas declaration order is already the author's intended grouping.

---

## Decision

**Implemented** (2026-09-04).

---

## Implementation Notes

**Rule class:** `NamedParametersOrderingRule`
**Rule name string:** `named_parameters_ordering`
**Config alias:** `named_arguments_ordering` (discovery alias matching the solid_lints rule this closes the gap against)

**Files:**
- `lib/src/rules/stylistic/named_parameters_ordering_rules.dart` — rule implementation
- `example/lib/stylistic/named_parameters_ordering_fixture.dart` — fixture (3 BAD `expect_lint`-marked cases, 4 GOOD/near-miss cases)
- `test/rules/stylistic/named_parameters_ordering_test.dart` — instantiation/metadata smoke test, matching the existing `stylistic_rules_test.dart` pattern

**Detection approach:** Registers on `InstanceCreationExpression` and `MethodInvocation`. Resolves the callee's element (`node.constructorName.element` / `node.methodName.element`) and reads its declared named-parameter order directly off `ExecutableElement.formalParameters` (filtered to `isNamed`). Compares that declared index against the call site's named arguments in source order; reports at the first argument whose declared index is lower than an already-seen index. Bails out (reports nothing) whenever the callee element doesn't resolve to an `ExecutableElement`, or a call-site argument name has no matching declared parameter — never guesses. No `.contains()` or string matching used anywhere in detection, per the false-positive doctrine. Requires a resolved AST (`usesTypeResolution => true`; `scan --resolve` or the IDE plugin path), since declaration order is only knowable from the resolved element, not the raw AST.

Handles the proposal's edge cases directly from this design: omitted parameters are simply absent from the compared sequence (no special-casing needed); redirecting/factory constructors are checked against the immediate constructor's own parameter list because `constructorName.element` resolves to that declaration, not the redirect target; positional arguments never enter the named-arg index space, so interleaving is a non-issue.

**Recommended tier:** `stylisticRules` (opt-in, not part of any numbered tier). The proposal doc said "Pedantic", but this project's actual convention (seen in `lib/src/tiers.dart`) puts every opinionated `*_ordering` rule — including the sibling `prefer_arguments_ordering` (alphabetical call-site order) and `enforce_parameters_ordering` (declaration-side positional/named category order) — in the opt-in `stylisticRules` set with a "Moved from X (opinionated)" comment, specifically because pure ordering conventions have no correctness/performance impact and teams disagree on them. Followed that established convention over the proposal doc's literal tier recommendation.

**Registration status:** Per explicit task instruction, `lib/saropa_lints.dart` (`_allRuleFactories`), `lib/src/tiers.dart` (tier set entry), and `lib/src/rules/all_rules.dart` (barrel export) were **not modified** — the rule is implemented but not yet wired into the plugin's rule registry. A follow-up change needs to add `NamedParametersOrderingRule.new` to `_allRuleFactories` in `lib/saropa_lints.dart`, the string `'named_parameters_ordering'` to `stylisticRules` in `lib/src/tiers.dart`, and `export 'stylistic/named_parameters_ordering_rules.dart';` to `lib/src/rules/all_rules.dart` (alongside the existing `stylistic/formatting_rules.dart` export) before the rule will actually run via the scan CLI, `dart test --no-pub test/integrity/saropa_lints_test.dart`, or the IDE plugin.

**Verification:** The scan CLI could not be used directly for firing verification — `--tier` doesn't expose the opt-in `stylistic` tier, and the CLI's config-file loader (`loadScanConfig`) expects a `diagnostics:` section format that doesn't match this project's own `example/analysis_options.yaml` (`saropa_lints: rules:` format), so neither path could enable an unregistered rule by name. Multiple other agents were concurrently editing `lib/saropa_lints.dart`/`lib/src/tiers.dart`/`lib/src/rules/all_rules.dart` in this same working tree during this session, and temporary edits made there for testing were observed reverted by that concurrent activity — confirming those files should not be touched. Instead, verified by writing a standalone script that builds a real resolved `AnalysisContextCollection` for the fixture file and calls `NamedParametersOrderingRule().registerNodeProcessors(...)` directly (bypassing the plugin's rule registry entirely, touching no registration file). Result: all 3 `expect_lint`-marked BAD lines fired (lines 46, 49, 52) with zero false positives on the 4 GOOD/near-miss cases. The script was deleted after use; no trace remains in the working tree.

**Issues:** None outstanding in the rule logic itself. The scan CLI has two latent gaps unrelated to this rule that a maintainer may want to track separately: (1) `--tier` rejects `stylistic` even though `getRulesForTier('stylistic')` supports it internally; (2) the `--files` flag's internal path-absolutization trips the scanner's hardcoded `/example` exclusion (meant for a consumer project's own `example/` dir) whenever the scan target is this package's own `example/` tree, making `--files` silently return zero files for any fixture path — the plain directory-listing scan path (no `--files`) does not hit this because it doesn't absolutize the target path first.

---

## Commits
