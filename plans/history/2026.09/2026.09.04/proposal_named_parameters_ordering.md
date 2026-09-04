# PROPOSAL: Enforce Consistent Named-Argument Order at Call Sites

**Status: Implemented**

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

## Finish Report (2026-09-04)

### Issues

- **Rule is not wired into the plugin — it currently never runs.** Confirmed by grep: `NamedParametersOrderingRule.new` is absent from `_allRuleFactories` in `lib/saropa_lints.dart`, `'named_parameters_ordering'` is absent from every tier set (including `stylisticRules`) in `lib/src/tiers.dart`, and there is no `export 'stylistic/named_parameters_ordering_rules.dart';` in `lib/src/rules/all_rules.dart`. The only place the rule name appears outside its own file is `lib/src/scan/rule_category_map.dart:992` (display metadata only — does not register or execute the rule). As shipped, this is dead code: the scan CLI, the IDE plugin, and `dart test --no-pub test/integrity/saropa_lints_test.dart` will not run it. The proposal doc itself documents this (Implementation Notes, "Registration status") as deliberate per task instruction, but it means the fixture's 3 `expect_lint` cases and the "verified via standalone script" claim in the doc are the ONLY evidence this rule fires — that evidence lives in a deleted throwaway script, not in anything reproducible in the repo today.
- **Two call-site shapes with named arguments are silently never checked**, both because `runWithReporter` (lines 97-113) only registers `addInstanceCreationExpression` and `addMethodInvocation`:
  - `SuperConstructorInvocation` (`super(named: ...)` in a constructor initializer list) and `RedirectingConstructorInvocation` (`this(named: ...)`) both accept named arguments and both have declared parameter order to violate, but neither has a visitor hook at all in `SaropaContext` (grepped `lib/src/native/saropa_context.dart` — no `addSuperConstructorInvocation` / `addRedirectingConstructorInvocation` exist in the framework). This is a framework gap, not something this rule can fix alone, but it means constructor-initializer reordering — arguably the most common site for "which param comes first" confusion in Flutter widgets with forwarding constructors — is an unflagged false-negative class.
  - `FunctionExpressionInvocation` (calling a variable/field/tear-off of function type, e.g. `final f = exampleFunction; f(gamma: ..., alpha: ...);`) IS supported by the framework (`SaropaContext.addFunctionExpressionInvocation` exists, `lib/src/native/saropa_context.dart:821`) but `_checkOrder` is never wired to it. This is a straightforward false-negative the rule author could have caught with the existing framework.
  - `EnumConstantDeclaration` (`enum E { a(x: 1, y: 2) }`) also accepts named arguments and also has a framework hook (`addEnumConstantDeclaration`, `saropa_context.dart:738`) that goes unused here.

### Concerns

- **Test suite proves nothing about firing behavior.** `test/rules/stylistic/named_parameters_ordering_test.dart` only instantiates the rule and asserts `LintCode` string metadata (name, message prefix, message length `>50`, correctionMessage non-null). It never resolves the fixture or asserts a diagnostic is produced. Combined with the "Issues" point above (rule unregistered), there is currently zero automated evidence in the repository that this rule ever fires correctly — the only evidence is a manually-run, now-deleted script described in prose in the proposal doc. If the visitor logic regresses later (e.g. during a refactor of `_checkOrder`), nothing in CI will catch it.
- **Unit test's `greaterThan(50)` assertion is weaker than the project's own documented bar.** `CLAUDE.md`'s "Problem Message Requirements" state the message "Must be >200 chars total" — the actual message here (~410 chars) satisfies that, but the test only guards `>50`, so a future edit could shrink the message well below the project's real minimum without the test failing.
- **Fixture doesn't exercise the proposal's own documented edge cases.** The proposal's "Edge Cases" section lists 4 scenarios; the fixture (`example/lib/stylistic/named_parameters_ordering_fixture.dart`) only covers edge case 1 (omitted trailing parameter, `goodExamples()` line 34) and implicitly touches edge case 3 via the doc's prose claim (not an actual fixture case — no factory/redirecting-constructor call site appears anywhere in the fixture). Edge case 2 (`super(...)` forwarding) and edge case 4 (named args interleaved with positional args, e.g. `exampleFunction('positional', beta: 'b', alpha: 'a')` if the signature allowed it) have no fixture coverage at all — for edge case 4 specifically, there is no call site in the fixture that mixes positional and named arguments, so the claim "positional arguments never enter the named-arg index space" (Implementation Notes) is asserted but not demonstrated.
- **Single-violation-per-call-site reporting** (`_checkOrder` returns at the first inversion, line 163-164) means a call site with 3+ named args in fully reversed order requires multiple lint-fix-rerun cycles to fully clean up rather than one pass. This is a reasonable, common lint pattern (not a bug) but is undocumented behavior a user hitting a large reordering job might find surprising — worth a one-line doc comment noting it's intentional.
- **No quick fix.** The violation (reorder a `NamedExpression` list to match `declaredIndexByName`) is fully mechanical and safe to auto-fix — the rule computes everything needed (`declaredIndexByName`, `namedArgs` in source order) to build the corrected order, but no `DartFix` exists. Not required for every rule, but this one is an unusually good candidate given the project's "quick fixes" emphasis (221+ shipped) and the low-risk nature of a pure argument reorder.

### Opportunities

- Wire `_checkOrder` to `context.addFunctionExpressionInvocation` — this needs no new framework support (the hook already exists) and directly closes one of the false-negative classes above. Low effort, same helper method already handles the `ExecutableElement`/`ArgumentList` pair generically.
- Wire `_checkOrder` to `context.addEnumConstantDeclaration` similarly, mapping its `.arguments` to the constructor being invoked.
- A quick fix that rebuilds the `ArgumentList`'s named-argument segment in `declaredIndexByName` order (stable sort of `namedArgs` by resolved declared index, keeping any interleaved positional arguments in their original slots) would make this rule strictly better than its `solid_lints` counterpart it was built to match, and is a natural companion to the sibling `prefer_arguments_ordering`/`enforce_parameters_ordering` rules if either already has a fix implemented (worth checking `lib/src/fixes/` for a reusable arg-reordering helper before writing one from scratch).
- Extend the unit test to actually resolve the fixture (pattern used elsewhere in the test suite per `saropa-lints-validation-and-qa` — `expect_lint` + a resolved-AST assertion) so the fixture's 3 BAD cases and 4 GOOD cases are enforced by `dart test`, not just by a manual, already-deleted verification script.

### Recommendations

1. **Highest priority — wire up registration.** Add `NamedParametersOrderingRule.new` to `_allRuleFactories` in `lib/saropa_lints.dart`, `'named_parameters_ordering'` to `stylisticRules` in `lib/src/tiers.dart`, and the export line to `lib/src/rules/all_rules.dart`. Until this lands the rule does not exist from a user's perspective regardless of how correct its logic is. (The doc's stated reason for skipping this — concurrent edits from other agents on this session's working tree — is a one-time scheduling problem, not a reason to leave it unregistered going forward.)
2. **Add a resolved-fixture test** that actually invokes the rule against `named_parameters_ordering_fixture.dart` and asserts diagnostics at the 3 documented `expect_lint` lines and none elsewhere, per this project's own `saropa-lints-validation-and-qa` policy — the current test only pins `LintCode` string metadata and would pass even if `_checkOrder` were deleted entirely.
3. **Close the `FunctionExpressionInvocation` and `EnumConstantDeclaration` false-negative gaps** (Issues above) — both hooks already exist in the framework; this is small, self-contained follow-up work.
4. **Tighten the unit test's message-length assertion** from `greaterThan(50)` to `greaterThan(200)` to match the project's actual documented requirement, so a future edit that shrinks the message is caught.
5. **Lower priority:** add fixture coverage for proposal edge cases 2 and 4 (super-constructor forwarding, positional/named interleaving) once/if `SuperConstructorInvocation` support exists in the framework or is added; add a quick fix.

## Commits
