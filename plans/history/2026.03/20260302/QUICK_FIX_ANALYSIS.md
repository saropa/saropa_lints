# Quick Fix Coverage: Rule-by-Rule Analysis

**Generated from codebase scan + spot-reading rule sources.**  
**Current state:** 119 rules with fixes / 1962 total rules (6.1%). **1843 rules have no fix.**

---

## 1. Per-file gap (rules missing fixes)

The audit counts quick fixes by scanning rule files for `get fixGenerators => [` (one count per override). Source: `scripts/modules/_audit_checks.py`.

**Largest fix gaps (rules − fixes):**

- `widget_patterns_rules.dart`: 105 rules, 9 fixes, **96 missing**
- `ios_rules.dart`: 86 rules, 1 fix, **85 missing**
- `widget_layout_rules.dart`: 76 rules, 6 fixes, **70 missing**
- `security_rules.dart`: 59 rules, 2 fixes, **57 missing**
- `bloc_rules.dart`: 54 rules, 0 fixes, **54 missing**
- `structure_rules.dart`: 51 rules, 0 fixes, **51 missing**
- `performance_rules.dart`: 50 rules, 0 fixes, **50 missing**
- `api_network_rules.dart`: 38 rules, 0 fixes, **38 missing**
- `naming_style_rules.dart`: 34 rules, 0 fixes, **34 missing**

**Lowest fix coverage files (rules ≥ 5) include many 0% files**, e.g. `bloc_rules.dart`, `structure_rules.dart`, `performance_rules.dart`, `code_quality_avoid_rules.dart`, `api_network_rules.dart`, `naming_style_rules.dart`, `firebase_rules.dart`, `drift_rules.dart`, `widget_patterns_require_rules.dart`, `type_rules.dart`, `animation_rules.dart`, etc.

---

## 2. How quick fixes work in this repo

- Rules extend `SaropaLintRule` (`lib/src/saropa_lint_rule.dart`) and optionally override:

  - `List<SaropaFixGenerator> get fixGenerators => [ ({required CorrectionProducerContext context}) => MyFix(context: context), ];`

- Fix producers extend `SaropaFixProducer` (`lib/src/native/saropa_fix.dart`) and implement:
  - `FixKind get fixKind`
  - `Future<void> compute(ChangeBuilder builder)`

- Reusable bases:
  - `ReplaceNodeFix` (`lib/src/fixes/common/replace_node_fix.dart`)
  - `DeleteNodeFix` (`lib/src/fixes/common/delete_node_fix.dart`)
  - `InsertTextFix` (`lib/src/fixes/common/insert_text_fix.dart`)

---

## 3. High-signal “EASY fix” candidates (deterministic, local edits)

These are rules where the diagnostic points at a narrow AST node and the fix is a one-step replace/delete/insert.

### A) `structure_rules.dart` (51 rules, 0 fixes)

Already verified in source: it reports on `ImportDirective` / `ExportDirective` / URI literals / parameter tokens for multiple rules.

**EASY:**

- **`avoid_double_slash_imports`**  
  - **Reports:** URI `SimpleStringLiteral` in import/export directives.  
  - **Fix:** replace string literal value with `value.replaceAll('//', '/')`.

- **`avoid_duplicate_exports`**  
  - **Reports:** the duplicate `ExportDirective`.  
  - **Fix:** delete the directive.

- **`avoid_duplicate_named_imports`**  
  - **Reports:** duplicate `ImportDirective`.  
  - **Fix:** delete the directive.

- **`prefer_trailing_underscore_for_unused`**  
  - **Reports:** `param.name` token for unused parameters in closures.  
  - **Fix:** rename `x` → `x_` (or `_x`) consistently with the rule message.

**MEDIUM/HARD (examples):** `prefer_named_imports`, `prefer_named_parameters`, `prefer_mixin_over_abstract` (may require structural transformation), `avoid_unnecessary_nullable_return_type` (needs semantics).

### B) `bloc_rules.dart` (54 rules, 0 fixes)

**EASY:**

- **`avoid_bloc_event_in_constructor`**  
  - **Reports:** `MethodInvocation` for `add(...)` inside constructor.  
  - **Fix:** delete the enclosing `ExpressionStatement` (remove the `add(...)` call statement).

### C) `performance_rules.dart` (50 rules, 0 fixes)

**EASY:**

- **`prefer_const_widgets`**  
  - **Reports:** `InstanceCreationExpression` constructor node.  
  - **Fix:** prefix with `const` when safe (similar to existing const-focused fixes).

**MEDIUM:**

- **`avoid_synchronous_file_io`**  
  - **Reports:** sync method invocation (`readAsStringSync`, etc.).  
  - **Fix option 1:** replace the method name with async version.  
  - **Fix option 2:** if in async function, also insert `await ` at the call site (multi-edit).

### D) `naming_style_rules.dart` (34 rules, 0 fixes)

**EASY (reuse):**

- **`prefer_capitalized_comment_start`**  
  - `CapitalizeCommentFix` already exists (`lib/src/fixes/stylistic/capitalize_comment_fix.dart`) and is wired to a stylistic rule.  
  - Add `fixGenerators` for this naming rule that returns `CapitalizeCommentFix`.

### E) `type_rules.dart` (20 rules, 0 fixes)

**EASY:**

- **`prefer_const_declarations`**  
  - Reports at the variable name token in a `VariableDeclarationList` with keyword `final`.  
  - Fix: replace `final` with `const` on that declaration list.

- **`prefer_final_locals`**  
  - Reports at the variable name token for local vars never reassigned.  
  - Fix: insert `final` keyword (or replace `var` with `final`) on the declaration list.

---

## 4. Additional “EASY” buckets for later scanning

These files are high rule-count with 0% fixes and likely contain many deterministic replacements/deletions:

- `code_quality_avoid_rules.dart` (44, 0 fixes) — pragma deletions, unused param renames, crypto algorithm replacement/TODO.
- `firebase_rules.dart` (32, 0 fixes) — often literal/config or API substitutions.
- `drift_rules.dart` (31, 0 fixes) — frequent “prefer X API” patterns.
- `widget_patterns_require_rules.dart` (31, 0 fixes) — many widget substitution fixes can follow patterns already used in widget rules.
- iOS sub-files like `ios_platform_lifecycle_rules.dart` (47, 0 fixes) and `ios_capabilities_permissions_rules.dart` (29, 0 fixes) — many plist/literal transformations.

---

## 5. Practical ceiling + classification

- **EASY:** deterministic local edit; safe. (Target: hundreds of rules over time.)  
- **MEDIUM:** multi-node but deterministic; still safe with careful implementation.  
- **HARD/NONE:** ambiguous refactors, project-wide renames, semantics-heavy transformations.

This document is the **analysis**. Execution work should follow the checklist plan in `bugs/roadmap/QUICK_FIX_PLAN_CHECKLIST.md`.

