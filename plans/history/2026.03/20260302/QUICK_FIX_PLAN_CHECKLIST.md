# Quick Fix Implementation Plan — Checklist

**Goal:** Increase quick fix coverage from **119/1962 (6.1%)** by implementing fixes in priority order, with fixtures + tests, and validating via the audit script.

**Reference analysis:** `bugs/roadmap/QUICK_FIX_ANALYSIS.md`

---

## A. Pre-flight (once)

- [ ] Run `python scripts/publish.py` (audit-only) and record:
  - [ ] quick fix coverage (count + %)
  - [ ] “Files needing quick fixes” top offenders
- [ ] Confirm clean baseline:
  - [ ] `dart analyze --fatal-infos` passes
  - [ ] `dart test` passes
- [ ] Create a working branch for quick fix batches.

---

## B. Batch workflow (repeat for every fix)

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

---

## C. Batch 1 — `structure_rules.dart` (EASY, deterministic)

**File:** `lib/src/rules/structure_rules.dart` (51 rules, 0 fixes)

- [ ] `avoid_double_slash_imports`
  - [ ] Fix: replace URI string literal value to remove `//`
  - [ ] Implementation: ReplaceNodeFix/custom on `SimpleStringLiteral`
- [ ] `avoid_duplicate_exports`
  - [ ] Fix: delete duplicate `ExportDirective`
  - [ ] Implementation: DeleteNodeFix (target the directive)
- [ ] `avoid_duplicate_named_imports`
  - [ ] Fix: delete duplicate `ImportDirective`
  - [ ] Implementation: DeleteNodeFix (target the directive)
- [ ] `prefer_trailing_underscore_for_unused`
  - [ ] Fix: rename unused param `x` → `x_` (or `_x`, pick one consistent with rule)
  - [ ] Implementation: replace the parameter name token / source range

**Exit criteria:** All 4 fixes have fixtures + tests and audit count increases by 4.

---

## D. Batch 2 — `bloc_rules.dart` + `performance_rules.dart` (EASY)

- [ ] `bloc_rules.dart`: `avoid_bloc_event_in_constructor`
  - [ ] Fix: delete the statement containing `add(...)` in constructor
  - [ ] Implementation: DeleteNodeFix; target `ExpressionStatement`

- [ ] `performance_rules.dart`: `prefer_const_widgets`
  - [ ] Fix: add `const` to the instance creation expression when valid
  - [ ] Implementation: ReplaceNodeFix/custom on `InstanceCreationExpression`

**Exit criteria:** +2 fixes, fixtures/tests present, audit count increases by 2.

---

## E. Batch 3 — naming + type (EASY, high impact)

- [ ] `naming_style_rules.dart`: `prefer_capitalized_comment_start`
  - [ ] Fix: reuse existing `CapitalizeCommentFix`
  - [ ] Implementation: add `fixGenerators` returning `CapitalizeCommentFix`

- [ ] `type_rules.dart`: `prefer_const_declarations`
  - [ ] Fix: replace `final` with `const` for the declaration list
  - [ ] Implementation: custom `SaropaFixProducer` that edits the keyword range

- [ ] `type_rules.dart`: `prefer_final_locals`
  - [ ] Fix: add `final` (or replace `var` with `final`) for local decl
  - [ ] Implementation: custom `SaropaFixProducer` keyword insertion/replacement

**Exit criteria:** +3 fixes, fixtures/tests present, audit count increases by 3.

---

## F. Batch 4 — `code_quality_avoid_rules.dart` (EASY candidates)

**File:** `lib/src/rules/code_quality_avoid_rules.dart` (44 rules, 0 fixes)

- [ ] `avoid_redundant_pragma_inline`
  - [ ] Fix: delete redundant pragma annotation
  - [ ] Implementation: DeleteNodeFix/custom on annotation node
- [ ] `avoid_unused_parameters`
  - [ ] Fix: rename unused parameter to `_x` / `x_` (match convention)
  - [ ] Implementation: replace name token range
- [ ] `avoid_weak_cryptographic_algorithms`
  - [ ] Decide fix behavior:
    - [ ] Option A: replace algorithm call (only when API is known + safe)
    - [ ] Option B: insert TODO/comment (always safe)

**Exit criteria:** +2 to +3 fixes, fixtures/tests present, audit increases accordingly.

---

## G. Batch 5 — `unnecessary_code_rules.dart` (fill remaining gaps)

- [ ] Scan the 7 rules without fixes and classify:
  - [ ] deterministic local delete/replace → implement
  - [ ] ambiguous → TODO/comment fix only

**Exit criteria:** +N fixes with tests, audit increases.

---

## H. Batch 6 — Performance sync I/O (MEDIUM)

- [ ] `performance_rules.dart`: `avoid_synchronous_file_io`
  - [ ] Fix 1: replace sync method name with async equivalent
  - [ ] Fix 2 (optional): also add `await` when legal (multi-edit)

**Exit criteria:** +1 or +2 fixes, fixtures/tests present, audit increases.

---

## I. After Batch 6

- [ ] Run full audit and record:
  - [ ] new fix count / coverage %
  - [ ] updated worst offending files list
- [ ] Add Batch 7+ for iOS, security, widget patterns/layout based on updated audit deltas.

