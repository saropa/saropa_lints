# Completed: plan_additional_rules_31_through_40

**Status:** Complete (2026-03-23)  
**Source:** [ROADMAP.md — Additional rules](../../../ROADMAP.md#additional-rules). Ordered by developer usefulness.  
**Legend:** 🟢 L / 🟡 M / 🔴 H effort · ★ / ★★ / ★★★ wow

---

## Implementation summary

Ten Essential-tier rules were added, mirroring or supplementing common Dart analyzer diagnostics for consistent Saropa tier messaging and configuration:

| Rule | Primary file |
|------|----------------|
| `abstract_field_initializer` | `compile_time_syntax_rules.dart` |
| `undefined_enum_constructor` | `compile_time_syntax_rules.dart` |
| `non_constant_map_element` | `collection_rules.dart` |
| `return_in_generator`, `yield_in_non_generator` | `control_flow_rules.dart` |
| `subtype_of_disallowed_type`, `abi_specific_integer_invalid` | `type_rules.dart` |
| `deprecated_new_in_comment_reference` | `documentation_rules.dart` |
| `annotate_redeclares`, `document_ignores` | `stylistic_rules.dart` |

### Follow-up (review pass)

- **Registration:** Rules are listed in [`lib/saropa_lints.dart`](../../../lib/saropa_lints.dart) `_allRuleFactories` and in [`lib/src/tiers.dart`](../../../lib/src/tiers.dart) `essentialRules` (required for the plugin to load them).
- **Tests:** `test/plan_additional_rules_31_40_test.dart` — registry resolution, `requiredPatterns` for file pre-filter, duplicated regex checks for `document_ignores` / `deprecated_new_in_comment_reference`, GOOD-section fixture slices.
- **Performance:** `requiredPatterns` on `abi_specific_integer_invalid`, `return_in_generator`, `yield_in_non_generator`, `document_ignores`, `deprecated_new_in_comment_reference` (skip irrelevant files via content index).
- **Docs / counts:** README, `pubspec.yaml`, and ROADMAP rule totals; `example/analysis_options_template.yaml` tier approximations + rule entries under compile-time shape.

### Quick fixes

Not added (plan optional); overlapping analyzer fixes already exist for several codes.

---

## Original plan (specification)

Register each rule in `all_rules.dart` and `tiers.dart`; add ROADMAP entry and fixture only after the rule is implemented and the BAD example triggers the lint.

---

## 1. non_constant_map_element

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** `if` or spread element in a const map must be constant.

**Target file:** `lib/src/rules/data/collection_rules.dart` or `type_rules.dart`  
**Approach:** Visit const map literals; check each element (if-element, spread) is constant. Use `context.addSetOrMapLiteral` or similar and inspect element list.  
**Acceptance criteria:** Non-constant element in const map reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Remove from const or make expression const. Optional.

---

## 2. return_in_generator

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** Generator (async* / sync*) must not use `return` with a value or implicit return; use `yield` instead.

**Target file:** `lib/src/rules/flow/control_flow_rules.dart` or `core/async_rules.dart`  
**Approach:** Find function bodies that are generators (async* or sync*). Traverse for `return` statements with an expression or missing yield on path; report.  
**Acceptance criteria:** `return value;` or implicit return in generator reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Replace with `yield value;` or add yield. Optional.

---

## 3. subtype_of_disallowed_type

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** Class must not extend/implement/with/on restricted types (e.g. bool, int, String).

**Target file:** `lib/src/rules/data/type_rules.dart`  
**Approach:** `context.addClassDeclaration`. For each extends/implements/with/on clause, resolve the type; if it is a disallowed type (SDK primitives, etc.), report.  
**Acceptance criteria:** `extends int` (or similar) reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Remove or change supertype. Optional.

---

## 4. undefined_enum_constructor

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** Enum value constructor does not exist (typo or wrong enum).

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** Visit enum value references (e.g. in switch or constructor calls). Resolve to enum declaration and check constructor exists; report if not.  
**Acceptance criteria:** Reference to non-existent enum constructor reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Fix name or add constructor. Optional.

---

## 5. yield_in_non_generator

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** `yield` / `yield*` used in a function that is not async* or sync*.

**Target file:** `lib/src/rules/flow/control_flow_rules.dart` or `core/async_rules.dart`  
**Approach:** Find `yield`/`yield*` expressions; get enclosing function and check it is a generator; report if not.  
**Acceptance criteria:** yield in normal async or sync function reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Change to async* or sync*, or remove yield. Optional.

---

## 6. abstract_field_initializer

| **Kind** | CODE_SMELL | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** Abstract field must not have an initializer.

**Target file:** `lib/src/rules/architecture/structure_rules.dart`  
**Approach:** `context.addFieldDeclaration`. If field is abstract and has an initializer, report.  
**Acceptance criteria:** `abstract int x = 0;` reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Remove initializer. Optional.

---

## 7. annotate_redeclares

| **Kind** | CODE_SMELL | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** Redeclared members (e.g. hiding super members) should be annotated as intended (e.g. @override or documentation).

**Target file:** `lib/src/rules/stylistic/stylistic_rules.dart` or `structure_rules.dart`  
**Approach:** For class members that hide a super member, check for appropriate annotation; report if missing. Requires resolution to find redeclarations.  
**Acceptance criteria:** Unannotated redeclaration reported where required. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Add @override or doc. Optional.

---

## 8. deprecated_new_in_comment_reference

| **Kind** | CODE_SMELL | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** Doc comment should not use deprecated `new` in comment reference (Dart 2 style).

**Target file:** `lib/src/rules/core/docs_rules.dart`  
**Approach:** Parse doc comments for `new ClassName`-style references; suggest or report using `ClassName` instead.  
**Acceptance criteria:** Deprecated `new` in doc reference reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Remove `new` from reference. Optional.

---

## 9. document_ignores

| **Kind** | CODE_SMELL | **Severity** | MINOR | **Effort** | 🟡 M | **Wow** | ★ |

**Summary:** Ignored diagnostics should be documented (e.g. why the ignore is there).

**Target file:** `lib/src/rules/stylistic/stylistic_rules.dart`. Per project rules, do not add/support ignore; only report when an ignore comment lacks a trailing explanation.  
**Approach:** Find `// ignore:` comments; parse list; if no trailing comment/documentation, report. Do not use to skip reporting other rules.  
**Acceptance criteria:** Bare ignore without explanation reported. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Add trailing comment. Optional.

---

## 10. abi_specific_integer_invalid

| **Kind** | BUG | **Severity** | MINOR | **Effort** | 🔴 H | **Wow** | ★ |

**Summary:** Class extending AbiSpecificInteger (dart:ffi) does not meet requirements.

**Target file:** `lib/src/rules/data/type_rules.dart` or `hardware/ffi_rules.dart`. Run only when project uses dart:ffi.  
**Approach:** Find classes extending AbiSpecificInteger; check size/alignment requirements per SDK docs; report if invalid.  
**Acceptance criteria:** Invalid AbiSpecificInteger subclass reported in FFI projects. Register, tier, ROADMAP, fixture, test.  
**Quick fix:** Adjust size/alignment. Optional.

---

## Implementation order (suggested)

1. abstract_field_initializer · 2. non_constant_map_element · 3. return_in_generator · 4. yield_in_non_generator · 5. subtype_of_disallowed_type · 6. undefined_enum_constructor · 7. deprecated_new_in_comment_reference · 8. annotate_redeclares · 9. document_ignores · 10. abi_specific_integer_invalid

---

## Checklist per rule (done)

- [x] Rule in correct `*_rules.dart`; registered in `all_rules.dart`; tier in `tiers.dart`.
- [x] ROADMAP entry; fixture only when BAD triggers; unit test; `/analyze`, `/test`, `/format`.
- [x] No quick fix that inserts `// ignore:`.
