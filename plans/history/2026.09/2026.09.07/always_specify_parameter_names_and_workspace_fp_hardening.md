# Batch build: always_specify_parameter_names rule + avoid_unbounded_dependency workspace FP hardening

Two independent lint-rule items were built in parallel via the batch-build workflow (two build agents, two cross-review agents, findings verified and fixed before commit), then a further `/code-review medium` pass on the resulting commit found two additional logic bugs, which were fixed before this record was written.

## What shipped

### New rule: `always_specify_parameter_names` (Professional tier, INFO)

Flags call sites passing 2+ consecutive positional arguments of confusable static type (identical types, or the numeric group int/double/num) without named arguments, targeting the classic silent-argument-swap bug class (`createUser('Smith', 'John')`). Implemented across two files to stay within the 200-line limit:

- `lib/src/rules/code_quality/always_specify_parameter_names_rule.dart` — AST wiring (method invocations, constructor calls, function expression invocations) and the `SaropaLintRule` subclass.
- `lib/src/rules/code_quality/always_specify_parameter_names_helpers.dart` — pure, unit-testable string/type logic: type normalization, confusable-run detection, and the constructor allowlist.

Registered in all three required places (`_allRuleFactories`, `professionalOnlyRules`, `all_rules.dart` export).

### Hardening: `avoid_unbounded_dependency` workspace/Melos false positive

`ParsedPubspec` gained a `pathOverriddenPackages` field. The parser now tracks which packages named in `dependency_overrides:` have a `path:` child key, and the rule excludes those packages from the unbounded-dependency check — an `any` constraint paired with a local path override is inert because pub resolves via the path, not the loose constraint. Only `path:` overrides suppress the lint; `git:`/`hosted:` overrides do not, since those still resolve through pub's normal version negotiation.

## Bugs found and fixed after the initial commit

The batch-build's own cross-review caught and fixed two critical issues before the first commit (a literal `{v1}/{v2}/{v3}` placeholder rendering in the diagnostic message, and a false-positive guard that incorrectly required the callee to have *any* named parameter). A second, independent `/code-review medium` pass on the committed diff — four parallel finder agents plus a removed-behavior audit — found two further genuine logic bugs that had survived the first review:

1. **Generic type erasure (false positive).** `normalizeTypeName` used `element?.name` (bare class name) to group custom types, so `List<String>` and `List<int>` both normalized to `'List'` and were reported as a confusable/swappable pair, even though swapping them would fail to compile. Fixed by using `type.getDisplayString()` instead, which includes type arguments.

2. **Allowlist bypassed by name collision (false negative).** `_isAllowlistedConstructor` matched purely on the class's simple name (`Size`, `Offset`, `Point`, etc.) against the allowlist, with no check of the declaring library. A user-defined class named `Size` with two `String` constructor parameters would be silently exempted from the check merely because the name collided with `dart:ui`'s `Size`. Fixed by keying the allowlist on `(className, libraryUri)` pairs (`dart:ui` for Offset/Size/Rect, `dart:math` for Point/Rectangle/MutableRectangle) via a new `findAllowlistedMaxArgs` lookup function.

Two smaller findings were also addressed: `findConfusableRuns` compared each entry against the run's first element (`runStart`) rather than the immediately preceding element — correct only because confusability is a transitive equality check, but confusing to read — changed to compare against `i - 1`. A comment was added to `_depSectionHeader` documenting that it must never match `dependency_overrides:`, since the invariant that override entries don't leak into `dependencies` now holds only implicitly (no explicit boolean guard remains after the `_collectPathOverrides` extraction).

## Deferred, not fixed

- **`pubspec_constraint_parser.dart` file length (581 lines).** Already 523 lines before this session touched it — pre-existing tech debt, not newly introduced. A clean extraction of the new `_collectPathOverrides` logic into a sibling file would require either duplicating the shared `_depEntry` regex (used by both the override collector and the main dependency-parsing loop) or making it public, adding risk to a file shared by five constraint-hygiene rules for a cosmetic line-count improvement. Left as documented, out-of-scope tech debt.
- **Quick fix for `always_specify_parameter_names`.** A fix that rewrites positional args to named syntax would require changing the *callee's declaration*, not just the call site — a cross-file refactor beyond a simple quick fix's scope.
- **Exposing `pathOverriddenPackages` in the scan CLI's JSON output.** The scan CLI does not consume `ParsedPubspec` directly (rules call the parser internally); plumbing this through would need changes beyond the parser/rule pair.

## Tests

- 34 tests in `test/rules/code_quality/always_specify_parameter_names_test.dart` (24 original + 10 added for `findAllowlistedMaxArgs`, covering the name-collision false-negative fix).
- 119 tests in `test/config/pubspec_constraint_parser_test.dart` (11 new, covering all 10 spec edge cases for the workspace path-override suppression plus a multi-override case).
- 24 integrity tests (`test/integrity/saropa_lints_test.dart`) unaffected, all passing.
- `dart run saropa_lints scan` at `comprehensive` tier against all four touched files: 43 findings, all on pre-existing lines untouched by this work (none on the new/modified lines).
