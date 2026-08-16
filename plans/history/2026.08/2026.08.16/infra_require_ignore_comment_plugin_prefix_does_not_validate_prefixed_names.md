# BUG: `require_ignore_comment_plugin_prefix` — Already-Prefixed Rule Names Are Never Validated Against the Registry

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-08-16
Rule: `require_ignore_comment_plugin_prefix`
File: `lib/src/rules/stylistic/formatting_rules.dart` (line ~1143, `_hasBareRuleName` at ~1225)
Severity: False negative
Rule version: (see `formatting_rules.dart` header) | Since: — | Updated: —

---

## Summary

`_hasBareRuleName` (`formatting_rules.dart:1225-1241`) skips any ignore-comment
name that already starts with `saropa_lints/` (`if (name.startsWith(_prefix))
continue;`, line 1236) — it never checks whether the part *after* the prefix
is actually a registered rule name. A prefixed-but-misspelled name (e.g.
`saropa_lints/duplicate_ignore` instead of the real
`saropa_lints/duplicate_ignore_comment`) produces **no diagnostic at all**,
even though the suppression silently does nothing (the analyzer/custom_lint
matches ignore comments by exact registered id). This is the same class of
"ignore comment doesn't actually suppress anything" bug the rule exists to
catch for bare names — just unguarded on the prefixed side.

This is a real, not hypothetical, gap: a downstream fix session in
`d:\src\contacts` hand-discovered 3 such wrong bare→real-name mappings
(`duplicate_ignore` → `duplicate_ignore_comment`, `require_dispose` →
`require_field_dispose`, and a bogus `saropa_depend_on_referenced_packages`
that was never a registered name at all) with **zero tooling help** — this
rule fired on the bare originals (correctly), but would have stayed silent
had any of the three been mistakenly prefixed instead of left bare (e.g. if
someone had "fixed" `require_dispose` to `saropa_lints/require_dispose`
instead of the correct `saropa_lints/require_field_dispose`).

---

## Attribution Evidence

```bash
$ grep -rn "'require_ignore_comment_plugin_prefix'" lib/src/rules/
lib/src/rules/stylistic/formatting_rules.dart:<LintCode line>:    'require_ignore_comment_plugin_prefix',
```

**Emitter registration:** `lib/src/rules/stylistic/formatting_rules.dart:1143` (class), `_hasBareRuleName` at `1225-1241`
**Rule class:** `RequireIgnoreCommentPluginPrefixRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
class Example {
  // ignore: saropa_lints/duplicate_ignore -- WRONG name; real rule id is
  // `duplicate_ignore_comment`. This ignore suppresses NOTHING — the
  // analyzer looks up the exact id `saropa_lints/duplicate_ignore`, finds no
  // such registered rule, and the diagnostic this comment was meant to
  // silence still fires. NO LINT is produced here today (false negative);
  // a correct implementation would flag this line.
  void method() {}
}
```

**Frequency:** Always, for any prefixed name that is not in
`tiers.getAllDefinedRules()` — silently passes validation with zero warning.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | `[require_ignore_comment_plugin_prefix]`-style diagnostic (or a distinct "unknown rule name" diagnostic) on a `saropa_lints/<name>` ignore comment where `<name>` is not in `tiers.getAllDefinedRules()` |
| **Actual** | No diagnostic — `_hasBareRuleName` returns `false` for anything already carrying the `saropa_lints/` prefix, regardless of whether the suffix is a real registered rule |

---

## AST Context

```
CompilationUnit
  └─ Token (comment: "// ignore: saropa_lints/duplicate_ignore -- ...")
      └─ _checkPrecedingComments()
          └─ _hasBareRuleName("saropa_lints/duplicate_ignore -- ...")
              └─ name.startsWith(_prefix) → true → `continue` (line 1236)
                 ← validation stops here; suffix never checked against
                   `_allSaropaRuleNames`
```

---

## Root Cause

`_hasBareRuleName` (`formatting_rules.dart:1225-1241`) is written to detect
only the "forgot the prefix entirely" case — it iterates each comma-separated
name, and for anything already prefixed, calls `continue` without further
checking (line 1236). The registry lookup (`_allSaropaRuleNames.contains(bare)`,
line 1240) only ever runs on names that do **not** have the prefix. There is
no code path that validates a prefixed name's suffix against the registry at
all, so a typo'd/wrong prefixed name is structurally indistinguishable from a
correct one to this rule.

---

## Suggested Fix

In the `continue`-if-prefixed branch (line 1236), before continuing, strip
the prefix and check the remainder against `_allSaropaRuleNames` (same set
already used for the bare-name path). If the stripped suffix is not in the
registry, report — either reusing this rule's existing diagnostic with an
adjusted message ("prefixed but not a registered saropa_lints rule name") or
as a new sibling rule/diagnostic code, since the corrective action differs
(fix the typo, not add a prefix). Given the shared registry lookup already
exists (`_allSaropaRuleNames`, line 1180), this is a small, localized change
confined to `_hasBareRuleName`.

---

## Fixture Gap

The fixture for `require_ignore_comment_plugin_prefix` should include:

1. **Bare name that IS a registered saropa_lints rule** — expect LINT
   (existing, presumably already covered).
2. **Prefixed name where the suffix IS registered** — expect NO lint
   (existing, presumably already covered).
3. **Prefixed name where the suffix is NOT registered (typo/wrong name)** —
   expect LINT (new case; currently silently passes — this is the gap).
4. **Prefixed name where the suffix is a real CORE Dart/Flutter lint name
   that also happens to collide with a saropa_lints rule name** — related to
   `infra_rule_names_collide_with_core_dart_lints.md`; worth cross-referencing
   once that bug's fix direction is picked, since the "is this suffix valid"
   check interacts with the collision-name set.

---

## Changes Made

- `lib/src/rules/stylistic/formatting_rules.dart`: Added `_unknownPrefixedRuleCode` LintCode and `_hasUnknownPrefixedRuleName()` method. Updated `_checkPrecedingComments()` to check both bare-name and unknown-prefixed-name cases independently.
- `lib/src/fixes/formatting/require_ignore_comment_plugin_prefix_fix.dart`: found during deep review that `fixGenerators` are registered per-rule (both `LintCode`s share the rule name id `require_ignore_comment_plugin_prefix`), so `RequireIgnoreCommentPluginPrefixFix` was offered for the new `_unknownPrefixedRuleCode` diagnostic too. `_extractInsertions` correctly found no bare name to insert a prefix before within the diagnostic's own comment slice, but `compute()`'s `insertions ??= _findFirstBareLineInsertions(content)` fallback then silently rescanned the WHOLE FILE and "fixed" an unrelated bare-name ignore comment elsewhere. `_extractInsertions` now returns `[]` (not `null`) once it has located the diagnostic's own ignore-comment line, even when that line's insertions list is empty — this stops `compute()`'s fallback from ever triggering for a name that is already prefixed-but-unregistered, since `??=` only substitutes on `null`.

---

## Tests Added

- `example/lib/formatting/require_ignore_comment_plugin_prefix_fixture.dart`: Added 5 new BAD cases for prefixed names with unregistered suffixes (`duplicate_ignore`, `require_dispose`, `totally_made_up_rule_name`, `nonexistent_rule`, `bogus_rule` with trailing comment). Each expects a LINT.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: resolved via `d:\src\contacts\pubspec.yaml` (pub cache; local checkout at `d:\src\saropa_lints` had an unrelated pre-existing compile error at report time, not used for detection)
- Dart SDK version: (not captured this session)
- custom_lint version: (not captured this session)
- Triggering project/file: discovered via code inspection while investigating `d:\src\contacts`'s ignore-prefix bulk-fix backlog; the 3 real-world wrong-bare-name cases it hand-fixed are documented in `d:\src\contacts\docs\handover\20260816_1657_lint_audit_backlog_sampling.md` (Completed task #2).

---

## Related

- `infra_rule_names_collide_with_core_dart_lints.md` — a correctly-prefixed
  name can still be ambiguous when the suffix collides with a core Dart lint
  name; that bug and this one are adjacent but distinct (that one is about
  which *rule* actually gets suppressed when names collide; this one is about
  whether the *name itself* is even valid).
