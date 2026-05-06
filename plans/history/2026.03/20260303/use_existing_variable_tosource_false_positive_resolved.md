# use_existing_variable — Same source treated as same value (false positive) — RESOLVED

**Rule:** `use_existing_variable`  
**File:** `lib/src/rules/code_quality/code_quality_variables_rules.dart` — `UseExistingVariableRule`  
**Status:** Resolved  
**Date:** 2026-03-03

## Resolution summary

The rule no longer reports duplicate variables when the initializer **contains any method or function invocation** (e.g. `Random().nextDouble()`, `DateTime.now()`). Same source was incorrectly treated as same value; such expressions can produce different values or have side effects. Initializers whose AST contains a `MethodInvocation` or `FunctionExpressionInvocation` are now excluded from duplicate detection. Implementation: `_InvocationPresenceVisitor` + `_expressionContainsInvocation()`; `LintImpact.medium`, `RuleCost.low`; doc and heuristic note added. Fixture: `example_core/lib/code_quality/use_existing_variable_fixture.dart` — `_goodSameSourceWithInvocation()` (DateTime.now()) must not trigger. Tests: `test/code_quality_rules_test.dart`, `test/false_positive_fixes_test.dart`.

## References

- Original bug: `bugs/use_existing_variable_tosource_false_positive.md` (moved here after fix)

---

## Original report (archived)

**Date:** 2025-03-03 | **Package:** saropa_lints 6.1.2 | **Severity:** Medium

The rule flags “new variable with the same **value** as an existing one” but used only `toSource()` for equality. Expressions that are syntactically identical but produce different values (e.g. `rng.nextDouble()`, `DateTime.now()`) were falsely reported. **Fix applied:** Exclude any initializer whose AST contains `MethodInvocation` or `FunctionExpressionInvocation` from duplicate detection.
