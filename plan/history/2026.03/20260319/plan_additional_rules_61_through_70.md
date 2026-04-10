# Plan: Additional rules 61–70 (ROADMAP)

**Source:** [ROADMAP.md — Additional rules](../../ROADMAP.md#additional-rules). Ordered by developer usefulness.  
**Legend:** 🟢 L / 🟡 M / 🔴 H effort · ★ / ★★ / ★★★ wow

Register each rule in `all_rules.dart` and `tiers.dart`; add ROADMAP entry and fixture only after the rule is implemented and the BAD example triggers the lint.

---

## 1. undefined_constructor_in_initializer

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Super constructor invoked in initializer list does not exist.

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** Visit constructor initializers; resolve super/this constructor call to declaration; report if not found or wrong argument count.  
**Acceptance criteria:** Undefined constructor in initializer reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 2. undefined_extension_getter

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Extension override getter is not defined on the extension.

**Target file:** `lib/src/rules/data/type_rules.dart`  
**Approach:** Find extension override nodes; resolve getter name to extension member; report if missing.  
**Acceptance criteria:** Undefined extension getter reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 3. undefined_extension_setter

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Extension override setter is not defined on the extension.

**Target file:** `lib/src/rules/data/type_rules.dart`  
**Approach:** Find extension override setter calls; resolve to extension; report if setter not defined.  
**Acceptance criteria:** Undefined extension setter reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 4. undefined_super_member

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Referenced super member is not in the superclass chain.

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** Find super.x / super.method() usages; resolve member in superclass chain; report if not found.  
**Acceptance criteria:** Undefined super member reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 5. wrong_number_of_type_arguments

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Type arguments count does not match type parameters of the generic type.

**Target file:** `lib/src/rules/data/type_rules.dart`  
**Approach:** Visit generic type usages; compare type argument count to type parameter count; report mismatch.  
**Acceptance criteria:** Wrong type argument count reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 6. omit_obvious_local_variable_types

| **Kind** | CODE_SMELL | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Don’t annotate local variable when type is obvious from initializer (style).

**Target file:** `lib/src/rules/stylistic/stylistic_rules.dart`  
**Approach:** Visit local variable declarations with type annotations; infer type from initializer; report if same as annotated type (redundant).  
**Acceptance criteria:** Redundant type annotation reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Remove type annotation. Optional.

---

## 7. type_parameter_supertype_of_its_bound

| **Kind** | CODE_SMELL | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Type parameter’s bound is (indirectly) the type parameter itself (invalid recursion).

**Target file:** `lib/src/rules/data/type_rules.dart`  
**Approach:** For type parameters with bounds, check bound does not refer back to the type parameter (cycle); report.  
**Acceptance criteria:** Circular bound reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Optional.

---

## 8. unnecessary_null_comparison

| **Kind** | CODE_SMELL | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Equality with null where the operand can never be null (redundant check).

**Target file:** `lib/src/rules/data/type_rules.dart` or `stylistic_rules.dart`  
**Approach:** Find `== null` / `!= null`; get static type of operand; report if non-nullable.  
**Acceptance criteria:** Redundant null comparison reported. Register, tier, ROADMAP, fixture, test. **Quick fix:** Remove comparison or simplify. Optional.

---

---

## Implementation order (suggested)

1. wrong_number_of_type_arguments · 2. undefined_constructor_in_initializer · 3. undefined_super_member · 4. undefined_extension_getter · 5. undefined_extension_setter · 6. unnecessary_null_comparison · 7. type_parameter_supertype_of_its_bound · 8. omit_obvious_local_variable_types

---

## Checklist per rule

- [ ] Rule in correct `*_rules.dart`; registered in `all_rules.dart`; tier in `tiers.dart`; ROADMAP entry; fixture when BAD triggers; unit test; `/analyze`, `/test`, `/format`; no `// ignore:` fix.
