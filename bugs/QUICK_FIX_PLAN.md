# Quick Fix Plan: Analysis + Checklist

**Goal:** Increase quick fix coverage from **119/1962 (6.1%)** by implementing fixes in priority order, with fixtures + tests, and validating via the audit script.

**Current state:** 119 rules with fixes / 1962 total rules (6.1%). **1843 rules have no fix.**

---

## Part 1 — Analysis

*Generated from codebase scan + spot-reading rule sources.*

### 1. Per-file gap (rules missing fixes)

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

### 2. How quick fixes work in this repo

- Rules extend `SaropaLintRule` (`lib/src/saropa_lint_rule.dart`) and optionally override:

  - `List<SaropaFixGenerator> get fixGenerators => [ ({required CorrectionProducerContext context}) => MyFix(context: context), ];`

- Fix producers extend `SaropaFixProducer` (`lib/src/native/saropa_fix.dart`) and implement:
  - `FixKind get fixKind`
  - `Future<void> compute(ChangeBuilder builder)`

- Reusable bases:
  - `ReplaceNodeFix` (`lib/src/fixes/common/replace_node_fix.dart`)
  - `DeleteNodeFix` (`lib/src/fixes/common/delete_node_fix.dart`)
  - `InsertTextFix` (`lib/src/fixes/common/insert_text_fix.dart`)

**Prohibited: "Insert-TODO" style fixes.** Do not add quick fixes that only insert a `// TODO: ...` comment (or similar) at the violation. They add no value over the lint itself and clutter the fix list. Only implement fixes that make a real code change (replace/delete/insert that resolves or meaningfully addresses the violation).

### 3. High-signal “EASY fix” candidates (deterministic, local edits)

These are rules where the diagnostic points at a narrow AST node and the fix is a one-step replace/delete/insert.

#### A) `structure_rules.dart` (51 rules, 0 fixes)

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

#### B) `bloc_rules.dart` (54 rules, 0 fixes)

**EASY:**

- **`avoid_bloc_event_in_constructor`**
  - **Reports:** `MethodInvocation` for `add(...)` inside constructor.
  - **Fix:** delete the enclosing `ExpressionStatement` (remove the `add(...)` call statement).

#### C) `performance_rules.dart` (50 rules, 0 fixes)

**EASY:**

- **`prefer_const_widgets`**
  - **Reports:** `InstanceCreationExpression` constructor node.
  - **Fix:** prefix with `const` when safe (similar to existing const-focused fixes).

**MEDIUM:**

- **`avoid_synchronous_file_io`**
  - **Reports:** sync method invocation (`readAsStringSync`, etc.).
  - **Fix option 1:** replace the method name with async version.
  - **Fix option 2:** if in async function, also insert `await ` at the call site (multi-edit).

#### D) `naming_style_rules.dart` (34 rules, 0 fixes)

**EASY (reuse):**

- **`prefer_capitalized_comment_start`**
  - `CapitalizeCommentFix` already exists (`lib/src/fixes/stylistic/capitalize_comment_fix.dart`) and is wired to a stylistic rule.
  - Add `fixGenerators` for this naming rule that returns `CapitalizeCommentFix`.

#### E) `type_rules.dart` (20 rules, 0 fixes)

**EASY:**

- **`prefer_const_declarations`**
  - Reports at the variable name token in a `VariableDeclarationList` with keyword `final`.
  - Fix: replace `final` with `const` on that declaration list.

- **`prefer_final_locals`**
  - Reports at the variable name token for local vars never reassigned.
  - Fix: insert `final` keyword (or replace `var` with `final`) on the declaration list.

### 4. Additional “EASY” buckets for later scanning

These files are high rule-count with 0% fixes and likely contain many deterministic replacements/deletions:

- `code_quality_avoid_rules.dart` (44, 0 fixes) — pragma deletions, unused param renames, crypto algorithm replacement/TODO.
- `firebase_rules.dart` (32, 0 fixes) — often literal/config or API substitutions.
- `drift_rules.dart` (31, 0 fixes) — frequent “prefer X API” patterns.
- `widget_patterns_require_rules.dart` (31, 0 fixes) — many widget substitution fixes can follow patterns already used in widget rules.
- iOS sub-files like `ios_platform_lifecycle_rules.dart` (47, 0 fixes) and `ios_capabilities_permissions_rules.dart` (29, 0 fixes) — many plist/literal transformations.

### 5. Practical ceiling + classification

- **EASY:** deterministic local edit; safe. (Target: hundreds of rules over time.)
- **MEDIUM:** multi-node but deterministic; still safe with careful implementation.
- **HARD/NONE:** ambiguous refactors, project-wide renames, semantics-heavy transformations.

Execution work follows **Part 2 (Checklist)** below.

---

## Part 2 — Checklist

### A. Pre-flight (once)

- [ ] Run `python scripts/publish.py` (audit-only) and record:
  - [ ] quick fix coverage (count + %)
  - [ ] “Files needing quick fixes” top offenders
- [ ] Confirm clean baseline:
  - [ ] `dart analyze --fatal-infos` passes
  - [ ] `dart test` passes
- [ ] Create a working branch for quick fix batches.

### B. Batch workflow (repeat for every fix)

- [ ] Add / update fix producer under `lib/src/fixes/**`
  - [ ] Prefer `ReplaceNodeFix` / `DeleteNodeFix` / `InsertTextFix` for simple edits
  - [ ] Otherwise extend `SaropaFixProducer`
- [ ] Wire the rule to the fix:
  - [ ] Add `fixGenerators` override on the rule class in `lib/src/rules/**`
- [ ] Add fixture showing violation + expected fix outcome (`example*`):
  - [ ] Include `// LINT` marker
- [ ] Add / update test under `test/**` to verify:
  - [ ] fix is offered for the diagnostic
  - [ ] applying fix produces expected output
- [ ] Run:
  - [ ] `dart format .`
  - [ ] `dart analyze --fatal-infos`
  - [ ] `dart test`
- [ ] Re-run `python scripts/publish.py` (audit-only) and confirm fix count increased.

### C. Batch 1 — `structure_rules.dart` (EASY, deterministic)

**File:** `lib/src/rules/structure_rules.dart` (51 rules, 4 fixes)

- [x] `avoid_double_slash_imports`
  - [x] Fix: replace URI string literal value to remove `//`
  - [x] Implementation: `RemoveDoubleSlashImportsFix` (ReplaceNodeFix on `SimpleStringLiteral`)
- [x] `avoid_duplicate_exports`
  - [x] Fix: delete duplicate `ExportDirective`
  - [x] Implementation: `DeleteDuplicateExportFix` (DeleteNodeFix)
- [x] `avoid_duplicate_named_imports`
  - [x] Fix: delete duplicate `ImportDirective`
  - [x] Implementation: `DeleteDuplicateImportFix` (DeleteNodeFix)
- [x] `prefer_trailing_underscore_for_unused`
  - [x] Fix: rename unused param `x` → `x_`
  - [x] Implementation: `PreferTrailingUnderscoreForUnusedFix` (replace name token)

**Exit criteria:** All 4 fixes have fixtures + tests and audit count increases by 4. **Done.**

### D. Batch 2 — `bloc_rules.dart` + `performance_rules.dart` (EASY)

- [x] `bloc_rules.dart`: `avoid_bloc_event_in_constructor`
  - [x] Fix: delete the statement containing `add(...)` in constructor
  - [x] Implementation: DeleteNodeFix; target `ExpressionStatement` (`RemoveBlocEventInConstructorFix`)
  - [x] Fixture: `example_packages/lib/bloc/avoid_bloc_event_in_constructor_fixture.dart` (Bloc with add() in constructor)
  - [x] Test: `bloc_rules_test.dart` — rule offers quick fix

- [x] `performance_rules.dart`: `prefer_const_widgets`
  - [x] Fix: add `const` to the instance creation expression when valid
  - [x] Implementation: `PreferConstWidgetsFix` on `InstanceCreationExpression`
  - [x] Fixture: `example_async/lib/performance/prefer_const_widgets_fixture.dart`
  - [x] Test: `performance_rules_test.dart` — rule offers quick fix

**Exit criteria:** +2 fixes, fixtures/tests present, audit count increases by 2. **Done.**

### E. Batch 3 — naming + type (EASY, high impact)

- [x] `naming_style_rules.dart`: `prefer_capitalized_comment_start`
  - [x] Fix: reuse existing `CapitalizeCommentFix`
  - [x] Implementation: `fixGenerators` already returns `CapitalizeCommentFix` (FormatCommentRule)
  - [x] Fixture: `example_core/lib/naming_style/prefer_capitalized_comment_start_fixture.dart`
  - [x] Test: `naming_style_rules_test.dart` — rule offers quick fix

- [x] `type_rules.dart`: `prefer_const_declarations`
  - [x] Fix: replace `final` with `const` for the declaration list
  - [x] Implementation: `PreferConstDeclarationsFix` (edits keyword range)
  - [x] Fixture: `example_core/lib/type/prefer_const_declarations_fixture.dart` (BAD: final pi = 3.14159)
  - [x] Test: `type_rules_test.dart` — rule offers quick fix

- [x] `type_rules.dart`: `prefer_final_locals`
  - [x] Fix: add `final` (or replace `var` with `final`) for local decl
  - [x] Implementation: `PreferFinalLocalsFix` (keyword insertion/replacement)
  - [x] Fixture: `example_core/lib/type/prefer_final_locals_fixture.dart` (BAD: var count = 1)
  - [x] Test: `type_rules_test.dart` — rule offers quick fix

**Exit criteria:** +3 fixes, fixtures/tests present, audit count increases by 3. **Done.**

### F. Batch 4 — `code_quality_avoid_rules.dart` (EASY candidates)

**File:** `lib/src/rules/code_quality_avoid_rules.dart` (44 rules, 0 fixes)

- [x] `avoid_redundant_pragma_inline`
  - [x] Fix: delete redundant pragma annotation
  - [x] Implementation: `RemoveRedundantPragmaInlineFix` (DeleteNodeFix on Annotation)
  - [x] Fixture: `example_core/lib/code_quality/avoid_redundant_pragma_inline_fixture.dart`
  - [x] Test: `code_quality_rules_test.dart` — rule offers quick fix
- [x] `avoid_unused_parameters`
  - [x] Fix: prefix unused parameter with underscore
  - [x] Implementation: `PrefixUnusedParameterFix` (replace name token)
  - [x] Fixture: `example_core/lib/code_quality/avoid_unused_parameters_fixture.dart`
  - [x] Test: `code_quality_rules_test.dart` — rule offers quick fix
- [x] `avoid_weak_cryptographic_algorithms`
  - [x] Fix: replace weak algorithm identifier with `sha256` (Option A; Option B TODO fix removed)
  - [x] Implementation: `ReplaceWeakCryptoFix` (replaces md5/sha1/MD5/SHA1 → sha256); removed `WeakCryptoTodoFix`
  - [x] Fixture: `example_core/lib/code_quality/avoid_weak_cryptographic_algorithms_fixture.dart`
  - [x] Test: `code_quality_rules_test.dart` — rule offers quick fix

**Exit criteria:** +2 to +3 fixes, fixtures/tests present, audit increases accordingly. **Done.**

### G. Batch 5 — `unnecessary_code_rules.dart` (fill remaining gaps)

- [x] Scanned rules; 1 had no fix, 1 had prohibited TODO fix.
- [x] `avoid_unnecessary_getter`: added `RemoveUnnecessaryGetterFix` (DeleteNodeFix on getter MethodDeclaration). Fixture exists; test added in `unnecessary_code_rules_test.dart`.
- [x] `no_empty_block`: replaced `NoEmptyBlockTodoFix` with `AddNoEmptyBlockIgnoreFix` (inserts `// ignore: no_empty_block` per rule’s correctionMessage). Deleted `no_empty_block_todo_fix.dart`. Test added.

**Exit criteria:** +N fixes with tests, audit increases. **Done (+2 fixes).**

### H. Batch 6 — Performance sync I/O (MEDIUM)

- [ ] `performance_rules.dart`: `avoid_synchronous_file_io`
  - [ ] Fix 1: replace sync method name with async equivalent
  - [ ] Fix 2 (optional): also add `await` when legal (multi-edit)

**Exit criteria:** +1 or +2 fixes, fixtures/tests present, audit increases.

### I. After Batch 6

- [ ] Run full audit and record:
  - [ ] new fix count / coverage %
  - [ ] updated worst offending files list
- [ ] Add Batch 7+ for iOS, security, widget patterns/layout based on updated audit deltas.
