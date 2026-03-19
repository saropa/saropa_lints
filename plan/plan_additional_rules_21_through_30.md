# Plan: Additional rules 21–30 (ROADMAP)

**Source:** [ROADMAP.md — Additional rules](../../ROADMAP.md#additional-rules). Ordered by developer usefulness (after 11–20).  
**Legend:** 🟢 L / 🟡 M / 🔴 H effort · ★ / ★★ / ★★★ wow

Register each rule in `all_rules.dart` and `tiers.dart`; add ROADMAP entry and fixture only after the rule is implemented and the BAD example triggers the lint.

---

## 1. conflicting_constructor_and_static_member

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** Named constructor and static method/field have the same name (illegal in Dart).

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** `context.addClassDeclaration`. Collect all constructor names and all static member names; report if any name appears in both sets.  
**Acceptance criteria:** Same-named constructor and static member reported; no false positives. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Rename one. Optional.

---

## 2. duplicate_constructor

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** More than one unnamed constructor or more than one constructor with the same name.

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** `context.addClassDeclaration`. Iterate constructors; count unnamed and per-name; report duplicates.  
**Acceptance criteria:** Duplicate constructors reported; single constructors not reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Remove or rename duplicate. Optional.

---

## 3. duplicate_field_name

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** Record literal or record type has duplicate field name.

**Target file:** `lib/src/rules/data/type_rules.dart` or `structure_rules.dart`  
**Approach:** `context.addRecordLiteral` / record type visitor if available. Collect field names; report if any name appears more than once.  
**Acceptance criteria:** Duplicate record field names reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Remove or rename duplicate field. Optional.

---

## 4. field_initializer_redirecting_constructor

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** A redirecting constructor must not initialize a field (only forwarding constructors can).

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** `context.addConstructorDeclaration`. If constructor has `redirects` (redirecting factory/constructor), check it has no initializer list that assigns to instance fields; report if it does.  
**Acceptance criteria:** Redirecting constructor with field initializer reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Remove field initializer or change to non-redirecting. Optional.

---

## 5. illegal_concrete_enum_member

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** Enum or concrete Enum implementer must not declare a concrete instance member (only abstract or enum entries allowed).

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** `context.addEnumDeclaration` and/or class implementing Enum. Check members; report concrete instance methods/getters/setters/fields where disallowed.  
**Acceptance criteria:** Illegal concrete enum member reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Make abstract or move to extension. Optional.

---

## 6. invalid_extension_argument_count

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** Extension override must have exactly one argument (the receiver).

**Target file:** `lib/src/rules/data/type_rules.dart`  
**Approach:** Find extension override syntax (e.g. `TypeExtension(args)...`). Check argument count is exactly one; report otherwise. May use `context.addExtensionOverride` or similar.  
**Acceptance criteria:** Zero or 2+ arguments on extension override reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Adjust argument list. Optional.

---

## 7. invalid_field_name

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** Record literal or record type has invalid field name (e.g. reserved word or invalid identifier).

**Target file:** `lib/src/rules/data/type_rules.dart`  
**Approach:** Visit record literals and record type annotations; check each field name is a valid Dart identifier and not reserved.  
**Acceptance criteria:** Invalid record field names reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Rename to valid identifier. Optional.

---

## 8. invalid_literal_annotation

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** `@literal` (or similar) applied to a non–const constructor.

**Target file:** `lib/src/rules/architecture/structure_rules.dart` or `type_rules.dart`  
**Approach:** Find annotations named `literal` (or the exact annotation class). Check target is a const constructor; report if not.  
**Acceptance criteria:** `@literal` on non-const constructor reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Remove annotation or make constructor const. Optional.

---

## 9. invalid_non_virtual_annotation

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** `nonVirtual` on wrong declaration or on non-concrete member.

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** Find `@nonVirtual` (or equivalent). Check it is on a concrete instance member that can be overridden; report if on static, abstract, or other invalid target.  
**Acceptance criteria:** Invalid nonVirtual use reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Remove or move annotation. Optional.

---

## 10. invalid_super_formal_parameter_location

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** Super parameter used outside a non-redirecting generative constructor.

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** `context.addConstructorDeclaration`. Detect super parameters (e.g. `super.x`). Ensure constructor is generative and not redirecting; report if used in redirecting or factory constructor.  
**Acceptance criteria:** Super parameter in wrong constructor type reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Convert to normal parameter and pass to super. Optional.

---

## Implementation order (suggested)

1. duplicate_constructor · 2. conflicting_constructor_and_static_member · 3. duplicate_field_name · 4. invalid_field_name · 5. field_initializer_redirecting_constructor · 6. invalid_super_formal_parameter_location · 7. illegal_concrete_enum_member · 8. invalid_extension_argument_count · 9. invalid_literal_annotation · 10. invalid_non_virtual_annotation

---

## Checklist per rule

- [ ] Rule in correct `*_rules.dart`; registered in `all_rules.dart`; tier in `tiers.dart`.
- [ ] ROADMAP entry; fixture only when BAD triggers; unit test; `/analyze`, `/test`, `/format`.
- [ ] No quick fix that inserts `// ignore:`.
