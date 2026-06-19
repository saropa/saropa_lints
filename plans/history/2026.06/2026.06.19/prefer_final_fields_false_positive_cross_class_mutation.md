# BUG: `prefer_final_fields` — False positive on field reassigned by another class

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-19
Rule: `prefer_final_fields`
File: `lib/src/rules/core/class_constructor_rules.dart` (line ~2583)
Severity: False positive — **High** (the suggested change does not compile)
Rule version: v1 | Since: v6.0.8 | Updated: —

---

## Summary

`prefer_final_fields` reports "Field is never reassigned and could be final" on a
non-`final` field that **is** reassigned — but the reassignment happens from a
*different* class, through an instance reference (`entry.count++`,
`_ctx.field = x`). The rule only counts mutations made by the declaring class's
own members, so it misses reassignment through a holder of an instance. Applying
the suggested fix (adding `final`) produces a compile error
(`The final variable 'x' can only be set once`).

Expected: **no diagnostic** — the field is reassigned somewhere in the program,
so it cannot be `final`.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`.

```bash
# Positive — rule IS defined here
grep -rn "'prefer_final_fields'" lib/src/rules/
# lib/src/rules/core/class_constructor_rules.dart:2583:    'prefer_final_fields',

# Negative — rule is NOT defined in the triggering project
grep -rn "prefer_final_fields" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches (the string appears only in that project's analysis_options.yaml,
#  which is rule *configuration*, not a rule *definition*)
```

**Emitter registration:** `lib/src/rules/core/class_constructor_rules.dart:2582`
(the `LintCode` `'prefer_final_fields'` inside `PreferFinalFieldsRule`).
**Rule class:** `PreferFinalFieldsRule` (`class_constructor_rules.dart:2567`) —
registered through the package's rule-collection mechanism (the rule class is not
referenced by literal name in `all_rules.dart`; `PreferFinalFields` is defined
only in `class_constructor_rules.dart`).
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (the
`saropa_lints` `custom_lint` plugin emits under the analyzer's `dart` owner).

---

## Reproducer

Two real cases from `saropa_drift_advisor`.

### Case 1 — same file, different class (`lib/src/server/rate_limiter.dart`)

```dart
class _WindowEntry {
  _WindowEntry(this.windowSecond);
  final int windowSecond;
  int count = 1; // LINT prefer_final_fields — but RateLimiter does `entry.count++`
                 //   below, so this field CANNOT be final.
}

final class RateLimiter {
  final Map<String, _WindowEntry> _windows = {};

  bool shouldThrottleKey(String key) {
    final entry = _windows[key]!;
    entry.count++; // <-- cross-class reassignment the rule misses
    return entry.count > maxRequestsPerSecond;
  }
}
```

### Case 2 — different file (`server_context.dart` + `router.dart`)

```dart
// server_context.dart
class ServerContext {
  bool changeDetectionEnabled = true; // LINT prefer_final_fields — but Router
                                      //   reassigns it (different file).
}

// router.dart
void configure(ServerContext _ctx, bool enabled) {
  _ctx.changeDetectionEnabled = enabled; // <-- cross-class reassignment the rule misses
}
```

**Frequency:** Always, when the *only* reassignment(s) of a field occur through an
instance reference outside the declaring class.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the field is reassigned elsewhere in the program, so it cannot be `final`. |
| **Actual** | `[prefer_final_fields] Field is never reassigned and could be final.` reported at the field declaration. Applying the fix (`final`) fails to compile. |

---

## AST Context

The flagged node is the `FieldDeclaration`. The reassignment the rule fails to
count is an `AssignmentExpression` / `PostfixExpression` whose write target is a
`PrefixedIdentifier` or `PropertyAccess` on a *non-`this`* holder, living in
**another** `ClassDeclaration` (and in Case 2, another `CompilationUnit`).

```
CompilationUnit (rate_limiter.dart)
  ├─ ClassDeclaration (_WindowEntry)
  │    └─ FieldDeclaration (int count = 1)        ← node reported here (false positive)
  │
  └─ ClassDeclaration (RateLimiter)
       └─ MethodDeclaration (shouldThrottleKey)
            └─ Block
                └─ ExpressionStatement
                    └─ PostfixExpression  (entry.count++)   ← the missed write
                        └─ operand: PropertyAccess
                            ├─ target: SimpleIdentifier (entry)  ← NOT a ThisExpression
                            └─ propertyName: SimpleIdentifier (count)
```

The rule never visits the bodies of *other* classes when scanning for the
declaring class's field writes, and even within the same class it only accepts
`PropertyAccess` whose `target is ThisExpression`. A write through `entry` (or
`_ctx`) matches neither path.

---

## Root Cause

The detection is **name-scoped to the declaring class body** and **`this`-only**
for member access. It uses string field-name matching plus a `ThisExpression`
target check; it never resolves the write target to the field's `Element`, so a
write through any other holder is invisible.

### Mechanism

`PreferFinalFieldsRule.runWithReporter` (`class_constructor_rules.dart:2589`):

1. Lines 2599–2607 collect the **names** of the current class's non-`final`,
   non-`const`, non-`late`, non-`static` instance fields into `mutableFieldNames`.
2. Lines 2611–2615 visit only **this same class's own members** (`node.bodyMembers`)
   with `_AssignmentToFieldVisitor` to populate the `assigned` set. Nothing outside
   `node` is ever walked — not sibling classes in the same unit, not other files.
3. Lines 2617–2622 report every field whose name is **not** in `assigned`.

The visitor `_AssignmentToFieldVisitor` (`class_constructor_rules.dart:2709`)
only recognizes two write shapes, by **name**, never by resolved element:

- `visitAssignmentExpression` (2716): accepts `left` when it is a bare
  `SimpleIdentifier` matching a field name, **or** a `PropertyAccess` whose
  `target is ThisExpression` (lines 2718–2724). A `PrefixedIdentifier`
  (`_ctx.changeDetectionEnabled`, the common cross-holder shape) is not handled
  at all, and a `PropertyAccess` on a non-`this` target (`entry.count`) is
  rejected by the `target is ThisExpression` guard.
- `visitPrefixExpression` / `visitPostfixExpression` (2730, 2746): same
  `SimpleIdentifier`-or-`this`-`PropertyAccess` restriction for `++`/`--`.

So `entry.count++` (Case 1) and `_ctx.changeDetectionEnabled = enabled` (Case 2)
are both writes the rule cannot see:

- Case 1: the write lives in a **different class** (`RateLimiter`), which is never
  visited because step 2 only walks `node.bodyMembers` of `_WindowEntry`; and even
  if it were visited, `entry.count` is a `PropertyAccess` on a `SimpleIdentifier`
  target, not `ThisExpression`, so the guard at 2721 / 2737 / 2753 rejects it.
- Case 2: the write lives in a **different file** (`router.dart`), so it is
  outside the analyzed `ClassDeclaration` entirely; additionally the target shape
  is a `PrefixedIdentifier`, which the visitor does not handle even for `this`.

Because detection is name-local and `this`-only rather than element-resolved and
program-wide, any field whose sole reassignments are through an external instance
reference is wrongly reported as "never reassigned."

---

## Suggested Fix

Resolve writes to the field's **`Element`**, not its name, and widen the search
beyond the declaring class body. Concretely:

1. **Match by element, not name.** In `_AssignmentToFieldVisitor`
   (`class_constructor_rules.dart:2709`), for each write target resolve
   `staticElement` (or `writeElement` on the `AssignmentExpression`) and compare it
   to the set of `FieldElement`s for the class's mutable fields, instead of
   comparing `SimpleIdentifier`/`PropertyAccess` names. This lets the visitor count
   a write through **any** holder:
   - `AssignmentExpression` with `leftHandSide` a `PrefixedIdentifier`
     (`_ctx.field = x`) — currently unhandled.
   - `AssignmentExpression` / `PostfixExpression` / `PrefixExpression` with a
     `PropertyAccess` on a non-`this` target (`entry.count++`) — currently rejected
     by the `target is ThisExpression` guard at lines 2721 / 2737 / 2753.

   Resolving the element makes the `ThisExpression` guard unnecessary and removes
   the `SimpleIdentifier`-only assumption.

2. **Widen the traversal beyond the declaring class.** The loop at lines 2611–2615
   only walks `node.bodyMembers`. To catch Case 1 (same-file sibling class), walk
   the entire enclosing `CompilationUnit` (the declaring class's parent unit) with
   the element-aware visitor and union those writes into `assigned`.

3. **Soundness limit (must be documented in the fix comment).** A `custom_lint`
   rule sees **one resolved unit at a time**; it cannot, from the unit that
   declares `_WindowEntry` / `ServerContext`, observe writes that live in *other*
   files (Case 2, `router.dart`). A fully sound "is this field ever reassigned
   anywhere in the program" check is not achievable from a single-unit rule
   without a project-wide index. Therefore:
   - At minimum, fix **same-file cross-class** mutation (Case 1) by resolving the
     write element and scanning the whole `CompilationUnit`. This is fully within
     reach and removes the most common false positive.
   - For **cross-file** mutation (Case 2), the rule cannot prove the field is never
     reassigned from the declaring unit alone. The safe choice is to **not report**
     a public/visible mutable field whose element could be written from outside the
     unit (i.e., narrow the rule to private-to-library fields, or fields whose type
     is not exposed via a public instance reference), rather than emit a fix that
     may not compile. The fix comment must state that single-unit analysis is the
     reason the rule cannot be fully sound and why under-reporting (a missed
     "could be final") is preferable to a non-compiling suggestion.

Reference lines for the change: collection at `2599–2607`, traversal at
`2611–2615`, reporting at `2617–2622`, and the three visitor methods at `2716`,
`2730`, `2746`.

---

## Fixture Gap

The fixture at `example*/lib/core/prefer_final_fields_fixture.dart` should include:

1. **Same-file sibling-class mutation** — a holder class does `holder.count++` on a
   field declared by another class in the same file → expect **NO lint** on that
   field.
2. **Same-file mutation via `PrefixedIdentifier` assignment** — `other.flag = true`
   where `flag` is declared by a different class in the same file → expect **NO lint**.
3. **`this`-only mutation (control)** — a class that only mutates its own field via
   `this.x = ...` / `x++` → existing behavior, still **NO lint**.
4. **Genuinely-never-reassigned field (control)** — a field with no writes anywhere
   in the unit → expect **LINT** (true positive must still fire).
5. **Cross-file note** — if the rule is narrowed for visibility (item 3 of the fix),
   add a fixture documenting that a public field written from another file is
   intentionally **not** reported.

---

## Changes Made

`PreferFinalFieldsRule` (`lib/src/rules/core/class_constructor_rules.dart`) was
rewritten to scan the whole compilation unit and to narrow reporting to private
fields, removing both false positives:

1. **Unit-wide scan via `addCompilationUnit`** (was `addClassDeclaration`). The
   write-collection visitor now walks every declaration in the file, so a write
   to a field from a *sibling class* in the same file is seen (Case 1).
2. **Holder-agnostic write matching.** The new `_FieldWriteNameVisitor` records
   the written field name from any assignment / `++` / `--` target shape —
   `x`, `this.x`, `holder.x` (`PropertyAccess`), and `holder.x`
   (`PrefixedIdentifier`). The old visitor accepted only a bare `SimpleIdentifier`
   or a `PropertyAccess` whose `target is ThisExpression`, so `entry.count++` and
   `_ctx.flag = x` were both invisible.
3. **Private-only reporting (Case 2 soundness).** Only `_`-prefixed fields are
   flagged. A write to a public field can live in another library that a
   single-unit `custom_lint` rule never resolves, so suggesting `final` there
   could fail to compile. This matches the SDK's own `prefer_final_fields`, which
   is private-only for the same reason. `prefer_final_fields_always` still flags
   every non-final field for users who want public-field strictness.
4. **Multi-file-library guard.** If the unit has a `part` or `part of` directive,
   the rule reports nothing — a private field is library-scoped and could be
   written in a part this unit cannot see. Under-reporting is the safe direction.

**Design note — name-based, not element-based.** The bug report suggested
matching by resolved `Element`. The rule also runs under the parse-only scan CLI
(`parseString`, no resolved elements), where `writeElement` is null; an
element-based version is silent there. Name matching works in both the resolved
analyzer and the parse-only CLI. The only cost is that two private fields in
different classes that share a name conservatively suppress each other — that
under-reports a "could be final", never emits a non-compiling `final`.

---

## Tests Added

- `example/lib/class_constructor/prefer_final_fields_fixture.dart` — replaced the
  placeholder with five cases: (1) same-file sibling-class `holder._count++`
  mutation → no lint; (2) `PrefixedIdentifier` assignment `other._flag = x` from a
  free function → no lint; (3) `this`-only mutation control → no lint;
  (4) genuinely-never-reassigned private field → **lint** (true positive);
  (5) public field control → no lint (out of scope).
- Verified with the scan CLI against a copy outside `example/` (the scanner
  skips `example*/`): exactly one `prefer_final_fields` diagnostic, on the
  never-reassigned private field, and none on the four mutated/public fields.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 14.0.3
- Dart SDK version: 3.12.1
- custom_lint version: run via `custom_lint` CLI
- Triggering project/file: `saropa_drift_advisor` — `lib/src/server/rate_limiter.dart`
  (`_WindowEntry.count`) and `lib/src/server/server_context.dart` +
  `lib/src/server/router.dart` (`ServerContext.changeDetectionEnabled`)

---

## Finish Report (2026-06-19)

### Defect

`prefer_final_fields` reported "Field is never reassigned and could be final" on a
field that is reassigned, when the only reassignment reached the field through an
instance reference held by a different class (`entry.count++`, `ctx.flag = x`).
The rule counted only writes made inside the declaring class body and only when
the write target was a bare identifier or a `this`-qualified property access, so
any cross-holder write was invisible. The suggested fix (adding `final`) did not
compile.

### Resolution

`PreferFinalFieldsRule` (`lib/src/rules/core/class_constructor_rules.dart`) now:

- Registers on the compilation unit (`addCompilationUnit`) and scans every
  declaration in the file, so a write from a sibling class in the same file is
  counted. The previous registration walked one class body at a time.
- Collects the written field name from any assignment / `++` / `--` target shape
  via `_FieldWriteNameVisitor` — `SimpleIdentifier`, `PropertyAccess` on any
  target (not only `this`), and `PrefixedIdentifier`. The old
  `_AssignmentToFieldVisitor` recognized only the bare-name and `this`-property
  shapes and was removed.
- Reports only private (`_`-prefixed) fields. A write to a public field can live
  in another library that a single-unit `custom_lint` rule never resolves, so a
  `final` suggestion there could fail to compile; restricting to private fields
  matches the SDK's own `prefer_final_fields`. `prefer_final_fields_always` still
  flags every non-final field.
- Returns without reporting when the unit carries a `part` or `part of`
  directive, because a private field is library-scoped and could be written in a
  part the unit cannot see. Under-reporting is the safe direction.

Matching is by name rather than resolved element because the rule also runs under
the parse-only scan CLI (`parseString`), where `writeElement` is null and an
element-based check is silent. The single precision cost is that two private
fields in different classes that share a name conservatively suppress each
other — an under-report, never a non-compiling `final` suggestion.

### Verification

Scan CLI (`dart run saropa_lints scan ... --tier comprehensive`) against a copy
of the fixture outside `example/` (the scanner skips `example*/`) produced exactly
one `prefer_final_fields` diagnostic, on the genuinely-never-reassigned private
field; the sibling-class-mutated, `PrefixedIdentifier`-mutated, `this`-mutated,
and public-field controls were all silent. `dart analyze` on the rule file
reported no new issues (two pre-existing warnings at unrelated lines 1024/1109
predate this change). `dart test test/rules/core/class_constructor_rules_test.dart`
passed (50 tests).

### Files

- `lib/src/rules/core/class_constructor_rules.dart` — rule rewrite + doc update.
- `example/lib/class_constructor/prefer_final_fields_fixture.dart` — five cases
  (sibling-class mutation, prefixed-identifier mutation, `this`-only control,
  never-reassigned true positive, public-field control).
- `CHANGELOG.md` — `[Unreleased] / Fixed` entry.
