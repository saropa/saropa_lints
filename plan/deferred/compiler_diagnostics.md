# Deferred: Compiler Diagnostic Rules

> **Last reviewed:** 2026-04-13

## Why these rules are not worth implementing

These rules duplicate checks that the **Dart compiler already performs**. The Dart analyzer catches these errors at compile time with clear messages. Reimplementing them as lint rules would:

- **Add no value**: The compiler already reports these as errors or warnings.
- **Risk divergence**: If the compiler changes its behavior, our duplicate rule could give conflicting advice.
- **Cost high effort**: Each rule requires deep type-system and control-flow analysis to replicate what the compiler does natively.

All rules below are rated **High effort, Low value** — the worst possible return on investment.

### What would change this assessment

Nothing realistic. The Dart compiler is the authoritative source for these diagnostics. Duplicating them is wasted work.

---

## Bug Detection (duplicates compiler errors) — 24 rules

| Rule | What the compiler already catches |
|------|-----------------------------------|
| `argument_type_not_assignable_to_error_handler` | `Future.catchError` argument type mismatch. |
| `body_might_complete_normally` | Non-nullable return type with missing return. |
| `const_map_key_not_primitive_equality` | Const map key class with custom `==` or `hashCode`. |
| `dead_null_aware_expression` | `??` where left operand cannot be null. |
| `duplicate_pattern_field` | Record/object pattern matching same field twice. |
| `implicit_super_initializer_missing_arguments` | Super constructor required parameter not passed. |
| `inconsistent_pattern_variable_logical_or` | Pattern variable type differs across logical-or branches. |
| `invalid_annotation` | Annotation is not a const variable or const constructor. |
| `invalid_null_aware_operator` | Null-aware operator on non-nullable receiver. |
| `invalid_pattern_variable_in_shared_case_scope` | Shared switch case body references case-specific variable. |
| `invalid_return_type_for_catch_error` | `Future.catchError` callback return type mismatch. |
| `invalid_type_argument_in_const_literal` | Type parameter used as type argument in const literal. |
| `invocation_of_non_function_expression` | Calling something that is not a function. |
| `missing_default_value_for_parameter` | Optional parameter with non-nullable type and no default. |
| `not_assigned_potentially_non_nullable_local_variable` | Local variable used before definite assignment. |
| `not_initialized_non_nullable_instance_field` | Non-nullable instance field without initializer. |
| `not_initialized_non_nullable_variable` | Non-nullable static/top-level variable without initializer. |
| `recursive_constructor_redirect` | Constructor redirects to itself. |
| `redirect_to_invalid_function_type` | Factory redirects to constructor with incompatible parameters. |
| `super_formal_parameter_without_associated_positional` | Super parameter without matching positional in superclass. |
| `undefined_constructor_in_initializer` | Super constructor invoked does not exist. |
| `undefined_extension_getter` | Extension getter not defined. |
| `undefined_extension_setter` | Extension setter not defined. |
| `undefined_super_member` | `super` member not in superclass chain. |
| `wrong_number_of_type_arguments` | Type argument count does not match type parameters. |

## Code Smell (duplicates compiler warnings) — 3 rules

| Rule | What the compiler already catches |
|------|-----------------------------------|
| `omit_obvious_local_variable_types` | Redundant type annotation where type is obvious. Overlaps with `omit_local_variable_types` lint. |
| `type_parameter_supertype_of_its_bound` | Type parameter bound that is (indirectly) itself. |
| `unnecessary_null_comparison` | Equality check with null where operand cannot be null. |

## Previously Removed (1 rule)

| Rule | Status |
|------|--------|
| `avoid_unstable_final_fields` | Removed. No longer proposed. |

**Total: 28 rules**
