# Plan: Additional rules 51–60 (ROADMAP)

**Source:** [ROADMAP.md — Additional rules](../../ROADMAP.md#additional-rules). Ordered by developer usefulness.  
**Legend:** 🟢 L / 🟡 M / 🔴 H effort · ★ / ★★ / ★★★ wow

Register each rule in `all_rules.dart` and `tiers.dart`; add ROADMAP entry and fixture only after the rule is implemented and the BAD example triggers the lint.

---

## 1. invalid_return_type_for_catch_error

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** `Future.catchError` callback return type is incompatible with the Future’s type parameter.

**Target file:** `lib/src/rules/core/async_rules.dart`  
**Approach:** `context.addMethodInvocation` for `catchError`; resolve Future type and callback return type; report if not assignable.  
**Acceptance criteria:** Incompatible return type in catchError reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 2. invalid_type_argument_in_const_literal

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Type parameter used as type argument in const literal (not allowed).

**Target file:** `lib/src/rules/data/type_rules.dart`  
**Approach:** Visit const literals; collect type arguments; report if any are type parameters.  
**Acceptance criteria:** Type parameter in const type argument reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 3. invocation_of_non_function_expression

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Invocation target (e.g. `x()`) is not a function or callable type.

**Target file:** `lib/src/rules/data/type_rules.dart`  
**Approach:** `context.addMethodInvocation` or function expression invocation; resolve target static type; report if not callable.  
**Acceptance criteria:** Call on non-callable expression reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 4. missing_default_value_for_parameter

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Optional parameter has non-nullable type and no default value.

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** Visit formal parameter lists; for optional parameters with non-nullable type, check for default; report if missing.  
**Acceptance criteria:** Optional param without default reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Add default or make required. Optional.

---

## 5. not_assigned_potentially_non_nullable_local_variable

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Local variable is read before it is definitely assigned (or may be non-null when read).

**Target file:** `lib/src/rules/code_quality/` or `flow/control_flow_rules.dart`  
**Approach:** Definite-assignment analysis: track writes to locals; report read before write on non-nullable path. Requires flow analysis.  
**Acceptance criteria:** Use before assign reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 6. not_initialized_non_nullable_instance_field

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Non-nullable instance field is not initialized (no constructor initializer, no field initializer).

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** For each non-nullable instance field, check it is set in every constructor or has an initializer; report if not.  
**Acceptance criteria:** Uninitialized non-nullable field reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 7. not_initialized_non_nullable_variable

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Static or top-level non-nullable variable has no initializer.

**Target file:** `lib/src/rules/architecture/structure_rules.dart` or `code_quality/`  
**Approach:** Visit top-level and static variable declarations; report non-nullable without initializer.  
**Acceptance criteria:** Uninitialized top-level/static reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 8. recursive_constructor_redirect

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Constructor redirects (directly or indirectly) to itself.

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** For redirecting constructors, build redirect graph; detect cycle; report.  
**Acceptance criteria:** Recursive redirect reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 9. redirect_to_invalid_function_type

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Factory constructor redirects to a constructor with incompatible parameters.

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** For factory redirects, resolve target constructor and compare parameter types; report if incompatible.  
**Acceptance criteria:** Incompatible redirect reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 10. super_formal_parameter_without_associated_positional

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Positional super parameter is used but super constructor has no matching positional parameter.

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** For super parameters, resolve super constructor signature; report if positional count/type doesn’t match.  
**Acceptance criteria:** Mismatched super parameter reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## Implementation order (suggested)

1. missing_default_value_for_parameter · 2. not_initialized_non_nullable_variable · 3. not_initialized_non_nullable_instance_field · 4. recursive_constructor_redirect · 5. redirect_to_invalid_function_type · 6. super_formal_parameter_without_associated_positional · 7. invalid_return_type_for_catch_error · 8. invalid_type_argument_in_const_literal · 9. invocation_of_non_function_expression · 10. not_assigned_potentially_non_nullable_local_variable · body_might_complete_normally (flow)

---

## Checklist per rule

- [ ] Rule in correct `*_rules.dart`; registered in `all_rules.dart`; tier in `tiers.dart`; ROADMAP entry; fixture when BAD triggers; unit test; `/analyze`, `/test`, `/format`; no `// ignore:` fix.
