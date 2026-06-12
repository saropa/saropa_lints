# BUG: `prefer_reusing_assigned_local` — NEW RULE PROPOSAL: local already holds the value, but the identical expression is recomputed instead of reused

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

## Implementation Notes (2026-06-04)

Shipped as a **Recommended**-tier INFO rule with a quick fix.

- Rule: `PreferReusingAssignedLocalRule` in
  [lib/src/rules/code_quality/unnecessary_code_rules.dart](../lib/src/rules/code_quality/unnecessary_code_rules.dart)
- Quick fix: `ReuseAssignedLocalFix` in
  [lib/src/fixes/unnecessary_code/reuse_assigned_local_fix.dart](../lib/src/fixes/unnecessary_code/reuse_assigned_local_fix.dart)
- Registered in `lib/saropa_lints.dart` and added to `recommendedOnlyRules` in `lib/src/tiers.dart`
- Fixture: `example/lib/unnecessary_code/prefer_reusing_assigned_local_fixture.dart` (all 8 proposal scenarios)

Detection matches the design below: a single-pass block scan records pure-read
local declarations and every later occurrence of an identical expression, then
reports reads that occur before any mutation of the local or the expression's
identifiers. Verified against the fixture via the scan CLI — fires on the 3 BAD
cases, silent on all GOOD cases (non-deterministic call, write target, mutation
between, string-literal mention, receiver reassignment).

Created: 2026-06-04
Rule: `prefer_reusing_assigned_local` (PROPOSED — does not exist yet)
File: would live in `lib/src/rules/code_quality/unnecessary_code_rules.dart` (sibling to the `avoid_unnecessary_*` family) OR `lib/src/rules/core/performance_rules.dart` (next to `prefer_cached_getter`)
Severity: False negative (no rule catches this) — proposing a new rule
Rule version: n/a — new

---

## Summary

When a local variable is assigned an expression and that **same expression is
re-evaluated verbatim** within scope — instead of reusing the local that
already holds the result — nothing flags it. The developer already paid to
compute and name the value; recomputing it is redundant work, and (worse) the
duplicated expression can silently drift from the local if one copy is edited.

This is distinct from the existing `prefer_cached_getter` rule (see
[Relationship](#relationship-to-prefer_cached_getter) below): that rule fires
when a value is read multiple times and **no** local caches it, and its fix is
"create a local." The proposed rule is the **complement** — a local *already
exists* with the identical right-hand side, but a sibling read bypasses it. The
fix is "reuse the existing local," and because the local + its RHS are already
present, the rule has near-zero false-positive surface.

---

## Attribution Evidence

This is a NEW rule proposal, so the positive grep is intentionally empty — that
is the point (no rule catches this pattern today).

```bash
# No existing rule for assign-then-recompute / reuse-the-local
grep -rn "recomput\|reusing\|assigned_local\|redundant_expr\|recomputing\|reuse_local" lib/src/rules/
# → only unrelated matches: prefer_cached_getter (different mechanism),
#   prefer_http_connection_reuse, avoid_hive_field_index_reuse, etc.
#   None target "a local already holds this expression; reuse it."
```

**Closest existing rule:** `prefer_cached_getter`
(`lib/src/rules/core/performance_rules.dart:615`, code string at line 631–638).
Different trigger and fix — see Relationship section.

**Diagnostic that actually fired on the canonical case:**
`avoid_variable_shadowing` — but only because the two switch cases happened to
reuse the name `host`. Had the names differed, the redundant recompute would
have shipped with **no diagnostic at all**, which is exactly the gap this rule
closes.

---

## Reproducer

Canonical case (from Saropa Contacts `lib/views/home/contact_tab.dart`, the
`Website` branch of a search-subtitle switch — shown in its pre-fix form):

```dart
case ContactSearchToggleEnum.Website:
  if (!contact.hasAnyWebsite) {
    return null;
  }

  // Local already holds the computed value...
  final String? websiteHost = contact.websites?.firstOrNull?.host;
  if (websiteHost == null) {
    return null;
  }

  return CommonIconText(
    // ...but the IDENTICAL chain is re-walked here instead of reusing
    // `websiteHost`. EXPECT LINT — reuse the local.
    text: contact.websites?.firstOrNull?.host,   // LINT
    iconCommon: ThemeCommonIcon.Website,
  );
```

**This is not a contrived snippet.** A heuristic scan of the Saropa Contacts
`lib/` (decl whose RHS re-appears verbatim within ~12 lines) surfaced three
further genuine instances, each a method/function-call recompute (more
expensive than a field read), all trivially fixable by reusing the local:

1. `lib/models/contact/contact_name_model.dart:156` →
   `final String? jsonGivenName = JsonTypeUtils.toStringJson(map[jsonKeyGivenName]);`
   then line 161 re-evaluates `JsonTypeUtils.toStringJson(map[jsonKeyGivenName])`
   in the else-branch of a ternary instead of `jsonGivenName`.

2. `lib/components/primitive/text/text_notifier_field.dart:283` →
   `final Color color = ThemeCommonColor.ThemeOnSurfaceDim.from(context);`
   then line 295 re-evaluates `ThemeCommonColor.ThemeOnSurfaceDim.from(context)`
   inside the same `InputDecoration` build instead of `color`.

3. `lib/utils/primitive/date_time/duration_utils.dart:45` →
   `final int minRemainder = inMinutes.remainder(60);`
   then line 55 re-evaluates `inMinutes.remainder(60)` instead of `minRemainder`.

**Frequency:** Only with specific patterns (a local declaration whose exact RHS
expression re-appears as a pure read in the same block/scope).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | INFO/WARNING at the recomputed expression: "value already assigned to local `X`; reuse `X` instead of recomputing." Quick fix replaces the duplicated expression with `X`. |
| **Actual** | No diagnostic. The redundant recompute is invisible unless an unrelated rule (e.g. `avoid_variable_shadowing`) happens to fire for a different reason. |

---

## AST Context

```
Block (method / case body)
  ├─ VariableDeclarationStatement
  │    └─ VariableDeclaration (name = websiteHost)
  │         └─ <RHS expression E>            ← capture E's source/structure
  │              e.g. PropertyAccess
  │                     contact.websites?.firstOrNull?.host
  │
  └─ (later, same enclosing block or nested non-reassigning scope)
       ReturnStatement / Expression
         └─ <expression E'>  where E' is structurally identical to E   ← REPORT here
```

The rule walks a block, records each `VariableDeclaration` whose initializer is
a **pure read** (member-access chain, indexed access, or a call to a method the
rule treats as side-effect-free), then reports any later occurrence of a
structurally-identical expression — provided the local is still in scope and
neither the local nor any sub-target of `E` has been reassigned in between.

---

## Proposed Rule Design

**Detection (high-confidence, low false-positive):**

1. Register `addBlock` (or method/function-body visitors). For each block,
   collect `VariableDeclaration`s with a non-null initializer.
2. Normalize the initializer to a canonical source string (or compare AST
   structurally). Only consider initializers that are **pure reads**:
   member-access / property chains (`a.b`, `a?.b?.c`), index access (`m[k]`),
   and calls whose target is in a known-pure set is NOT required — restricting
   to *identical token sequence* re-use is enough for v1 and keeps it safe.
3. Scan subsequent statements in the same scope (and nested scopes that do not
   reassign) for an expression whose source matches the initializer verbatim.
4. **Bail conditions (avoid false positives):**
   - The local OR any identifier appearing in `E` is reassigned between the
     declaration and the re-use (value may have changed). This kills the
     `DateTime.now()` / before-vs-after-`removeAt` / save-old-then-write cases.
   - `E` contains a call to a non-getter method that could have side effects
     and the two calls are intended to differ (conservative: if unsure, only
     fire for `?.`/`.` property chains and known-pure resolvers like
     `ThemeCommon*.from(context)` — though even general method calls are safe
     to flag when no intervening reassignment touches the receiver).
   - The re-use appears inside a **string literal** (debug/log/l10n messages
     such as `'Missing [service.phones]'`) — these reference the expression
     textually, they do not evaluate it. (This was the dominant false-positive
     source in the heuristic scan; the AST-level rule avoids it for free since
     a string literal is not an expression node matching `E`.)

**Quick fix:** replace the duplicated expression node with a `SimpleIdentifier`
naming the existing local. `sourceRange` = the exact span of the duplicated
expression.

**Correction message:** "`<local>` already holds this value — reuse it instead
of recomputing the expression."

---

## Relationship to `prefer_cached_getter`

These are complementary, not duplicates. Keep both.

| | `prefer_cached_getter` (exists) | `prefer_reusing_assigned_local` (proposed) |
|---|---|---|
| Trigger | Same value read 2+ times, **no local caches it** | A local **already exists** holding the value, identical expression recomputed elsewhere |
| Fix | "Create a local and cache it" | "Reuse the existing local" |
| Confidence | Heuristic (is it worth caching?) | High (the dev already decided to cache — they just bypassed it) |
| Canonical case here | n/a | The `websiteHost` reproducer above |

`prefer_cached_getter` did **not** fire on the canonical case (the diagnostic
that surfaced it was `avoid_variable_shadowing`), confirming the gap. Whether
that is because the collector keys on getter names rather than full `?.` chains,
or because the case sits inside a switch/closure the method-declaration visitor
treats differently, is worth checking during implementation — but even if it
were tweaked to fire, its fix ("create a local") is wrong here: the local
already exists.

---

## Fixture Gap

A new fixture (e.g.
`example*/lib/code_quality/prefer_reusing_assigned_local_fixture.dart`) should
cover:

1. **Property chain reused after assignment** — `final x = a?.b?.c; ... use a?.b?.c` → expect LINT
2. **Resolver call reused** — `final c = Theme...from(ctx); ... Theme...from(ctx)` → expect LINT
3. **Method-with-arg reused** — `final m = f(map[k]); ... f(map[k])` → expect LINT
4. **Reassignment between decl and reuse** — `final t = DateTime.now(); ... DateTime.now()` → expect NO lint (different value)
5. **Save-old-then-write** — `final old = obj.field; ... obj.field = x;` → expect NO lint (the reuse is a write target, not a redundant read)
6. **Before/after a mutation** — `final n = list.length; list.removeAt(0); ... list.length` → expect NO lint (length changed)
7. **Expression referenced only inside a string literal** — `final p = svc.phones; debug('[svc.phones]')` → expect NO lint
8. **Receiver reassigned** — `final v = a.b; a = other; ... a.b` → expect NO lint

---

## Environment

- saropa_lints version: (current main)
- Dart SDK version: (Flutter stable in Saropa Contacts)
- custom_lint version: n/a — saropa_lints is a native `analysis_server_plugin`
- Triggering project/file: `d:\src\contacts\lib\views\home\contact_tab.dart` (Website search-subtitle case)

---

## Finish Report (2026-06-04)

### Scope

(A) Dart lint rules / analyzer plugin. Touches `lib/` (rule + fix), `lib/src/tiers.dart`,
`lib/saropa_lints.dart`, Dart `test/`, `example/`, and `CHANGELOG.md`.

### Deep Review

- **Logic & Safety:** The rule runs per `Block`, does one `RecursiveAstVisitor`
  pass to collect matching expressions and mutation points, then reports. No
  recursion risk (`_rootIdentifierName` strictly descends `target`/`prefix`
  toward a leaf and returns on any non-chain node, so the `while` terminates).
  No shared mutable state across blocks (a fresh `_BlockReuseScanner` per block).
- **Architecture & Adherence:** Follows the `SaropaLintRule` + `SaropaFixProducer`
  pattern (matches `AvoidUnnecessaryCallRule` / `RemoveUnnecessaryCallFix`). Fix
  reuses `coveringNode` / `addSimpleReplacement`; no ad-hoc AST plumbing.
- **Linter-Specific Integrity:** Rule placed alongside the `avoid_unnecessary_*`
  family in `unnecessary_code_rules.dart`. Registered in `_allRuleFactories` and
  added to `recommendedOnlyRules` (Recommended tier, the user-requested tier).
  `LintImpact.info`, `RuleCost.medium`, `RuleType.codeSmell`. Problem message
  carries the `[rule_name]` prefix and a `correctionMessage`. Quick fix is a real
  code change (not a no-op ignore-insert).
- **Heuristics / false positives:** Purity gate rejects non-deterministic calls
  (`now`/`random`/`next*`/`elapsed*`), object allocation, closures, await,
  assignment, cascade, throw. A per-local mutation barrier suppresses any reuse
  occurring after the receiver or local is written (assignment, `++`/`--`, or a
  known mutating method). Write targets and string-literal mentions never match.

### Testing Validation

- **Audit:** Grepped `test/` for `prefer_reusing_assigned_local`,
  `PreferReusingAssignedLocalRule`, `ReuseAssignedLocalFix`, `reuseAssignedLocal`
  — the only hit is the edited file (`unnecessary_code_rules_test.dart`). No
  other test pinned the changed symbols.
- **New tests:** Added an instantiation pin, a fixture-presence entry, and a
  fix-generator presence check; bumped the file's rule-count doc comment to 15.
- **Runs (executed in this environment):**
  - `dart test test/rules/code_quality/unnecessary_code_rules_test.dart test/integrity/saropa_lints_test.dart` → All tests passed (53, 1 skipped).
  - `dart test test/integrity/` → All tests passed (370, 1 skipped) — confirms tier coverage ("all plugin rules must be in tiers.dart").
  - `dart analyze lib/` → No issues found.
- **Behavioral verification (scan CLI):** Ran the rule against the fixture (copied
  to a non-`fixture`-named file under `d:\tmp`, because the scan CLI skips files
  whose name contains `fixture`). Result: fired on exactly the 3 BAD cases
  (property chain, resolver call, method-with-arg) and zero of the GOOD cases
  (non-deterministic, write target, mutation-between, string-literal,
  receiver-reassigned). Confirmed it does NOT load under the `recommended` tier
  before the tier fix and DOES after — the tier placement is verified, not assumed.

### Project Maintenance

- CHANGELOG: new `[Unreleased]` section + `### Added` bullet.
- README counts (2134 / 2118): left as-is — these are tooling-generated snapshots
  (they already disagree with each other and with CLAUDE.md's "2106+"), refreshed
  by the publish script, not hand-maintained per rule.
- ROADMAP: no entry to remove — this rule was not a roadmap item (the ROADMAP
  tracks pending cross-file rules; sibling `prefer_cached_getter` is likewise
  absent).
- Bug archived: `bugs/prefer_reusing_assigned_local_new_rule_proposal.md` →
  `plans/history/2026.06/2026.06.04/prefer_reusing_assigned_local_new_rule_proposal.md`.

### Outstanding

None. Rule, fix, registration, tier, fixture, tests, and changelog are complete
and verified.
