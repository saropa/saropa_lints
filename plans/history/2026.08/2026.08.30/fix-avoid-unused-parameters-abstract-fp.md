# Fix: avoid_unused_parameters false positive on abstract methods

`avoid_unused_parameters` incorrectly flagged every parameter on abstract, external, and native method declarations. These methods have no implementation body — their parameters define a contract, not usage sites.

## Finish Report (2026-08-30)

### Root Cause

`_checkParameters` in `AvoidUnusedParametersRule` guards against `body == null` but abstract/external/native methods produce an `EmptyFunctionBody` AST node (the `;` terminator), not a null body. Native methods produce a separate `NativeFunctionBody`. The `_IdentifierCollector` visitor found zero identifiers in the empty body and flagged every parameter as unused.

### Fix

Replaced the `body == null` guard with a positive check: only proceed when `body is BlockFunctionBody || body is ExpressionFunctionBody`. This excludes `EmptyFunctionBody` (abstract/external), `NativeFunctionBody`, and any future body subtype without implementation code. The positive-check pattern matches `compile_time_syntax_rules.dart:116` for consistency.

### Files Changed

| File | Change |
|------|--------|
| `lib/src/rules/code_quality/code_quality_avoid_rules.dart` | Positive body-type guard in `_checkParameters` — only `BlockFunctionBody` and `ExpressionFunctionBody` proceed |
| `example/lib/code_quality/avoid_unused_parameters_fixture.dart` | GOOD fixtures: abstract interface class, abstract class, external method |
| `test/rules/code_quality/avoid_unused_parameters_behavior_test.dart` | 10-case behavioral test: 4 true-positive + 6 false-positive guards (abstract, external, override, underscore, expression body) |
| `CHANGELOG.md` | Entry under `[15.2.5] — Unreleased` Fixed section |

### Hardening Applied

- **NativeFunctionBody coverage**: Initial fix only guarded `EmptyFunctionBody`; hardened to a positive-check pattern that also excludes `NativeFunctionBody` and any future body subtype.
- **Cross-rule audit**: Surveyed 30+ `body == null` guards across `lib/src/rules/`. All other rules check for specific patterns *inside* the body (presence-based), so `EmptyFunctionBody` causes "nothing found" (correct). Only `avoid_unused_parameters` uses absence-based logic (flagging what's NOT referenced), making it uniquely vulnerable to this false-positive class.
- **Behavioral test suite**: New resolved-harness test covers the exact reporter pattern from #319, plus abstract classes, external methods, overrides, underscore params, expression bodies, and concrete unused params.

### Testing

- 10/10 behavioral tests pass via resolved rule harness (`runRuleResolved`).
- Instantiation test passes (`dart test --name AvoidUnusedParametersRule`).
- Fixture file compiles cleanly (`dart analyze` — 0 issues).

### Risk

Low. The guard is a positive type check against two stable AST node classes (`BlockFunctionBody`, `ExpressionFunctionBody`). No behavioral change for concrete methods with block or expression bodies.

Closes [#319](https://github.com/saropa/saropa_lints/issues/319).
