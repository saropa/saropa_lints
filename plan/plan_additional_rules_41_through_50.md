# Plan: Additional rules 41–50 (ROADMAP)

**Source:** [ROADMAP.md — Additional rules](../../ROADMAP.md#additional-rules). Ordered by developer usefulness.  
**Legend:** 🟢 L / 🟡 M / 🔴 H effort · ★ / ★★ / ★★★ wow

Register each rule in `all_rules.dart` and `tiers.dart`; add ROADMAP entry and fixture only after the rule is implemented and the BAD example triggers the lint.

---

## 1. argument_type_not_assignable_to_error_handler

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** `Future.catchError` argument function parameters are incompatible with the error type.

**Target file:** `lib/src/rules/core/async_rules.dart`  
**Approach:** `context.addMethodInvocation` for `catchError`. Resolve callback parameter type and required error type; report if not assignable.  
**Acceptance criteria:** Incompatible catchError callback reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 2. body_might_complete_normally

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Method/function with non-nullable return type can complete without returning a value (implicit null).

**Target file:** `lib/src/rules/flow/control_flow_rules.dart`  
**Approach:** For functions with non-nullable return type, analyze control flow; report if a path exists that doesn’t return. Requires flow analysis.  
**Acceptance criteria:** Missing return on path reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 3. const_map_key_not_primitive_equality

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Const map key type must use primitive equality (must not implement custom ==/hashCode).

**Target file:** `lib/src/rules/data/collection_rules.dart` or `type_rules.dart`  
**Approach:** Visit const map literals; resolve key types; report if key class implements == or hashCode.  
**Acceptance criteria:** Custom equality key in const map reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 4. dead_null_aware_expression

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Left operand of `??` can never be null, or null-aware usage is unnecessary.

**Target file:** `lib/src/rules/data/type_rules.dart` or `stylistic_rules.dart`  
**Approach:** Find null-aware operators (`??`, `?.`, `!`). Use static type of left operand; if non-nullable, report.  
**Acceptance criteria:** Dead null-aware usage reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Remove null-aware or simplify. Optional.

---

## 5. duplicate_pattern_field

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Record or object pattern matches the same field or getter more than once.

**Target file:** `lib/src/rules/data/type_rules.dart` or `flow/control_flow_rules.dart`  
**Approach:** Visit pattern nodes (record/object patterns); collect field names; report duplicates.  
**Acceptance criteria:** Duplicate pattern field reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 6. implicit_super_initializer_missing_arguments

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Super constructor has required parameter that is not passed in initializer list.

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** For constructor initializers, find super constructor call; compare required parameters with passed arguments; report missing.  
**Acceptance criteria:** Missing super argument reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 7. inconsistent_pattern_variable_logical_or

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Pattern variable in logical-or has different type on branches (unsound).

**Target file:** `lib/src/rules/flow/control_flow_rules.dart` or `type_rules.dart`  
**Approach:** Find logical-or expressions containing pattern variables; check types on each branch; report if inconsistent.  
**Acceptance criteria:** Inconsistent pattern variable in `||` reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 8. invalid_annotation

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Annotation is not a const variable or const constructor invocation.

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** Visit annotations; resolve to element; verify const constructor or const variable; report if not.  
**Acceptance criteria:** Non-const annotation reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 9. invalid_null_aware_operator

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Null-aware operator used on a receiver that is known to be non-nullable.

**Target file:** `lib/src/rules/data/type_rules.dart`  
**Approach:** Find `?.`, `??`, `!`; get receiver static type; report if non-nullable.  
**Acceptance criteria:** Unnecessary null-aware on non-null type reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Remove `?` or `!`. Optional.

---

## 10. invalid_pattern_variable_in_shared_case_scope

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Shared switch case body references a pattern variable from only one case (scope error).

**Target file:** `lib/src/rules/flow/control_flow_rules.dart`  
**Approach:** Visit switch statements with shared cases; track which variables are bound in which case; report use of variable in shared body that is not bound in all cases.  
**Acceptance criteria:** Invalid pattern variable in shared case reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## Implementation order (suggested)

1. invalid_annotation · 2. dead_null_aware_expression · 3. invalid_null_aware_operator · 4. argument_type_not_assignable_to_error_handler · 5. const_map_key_not_primitive_equality · 6. duplicate_pattern_field · 7. implicit_super_initializer_missing_arguments · 8. inconsistent_pattern_variable_logical_or · 9. invalid_pattern_variable_in_shared_case_scope · 10. body_might_complete_normally

---

## Checklist per rule

- [ ] Rule in correct `*_rules.dart`; registered in `all_rules.dart`; tier in `tiers.dart`; ROADMAP entry; fixture when BAD triggers; unit test; `/analyze`, `/test`, `/format`; no `// ignore:` fix.
