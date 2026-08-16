# Infra: Rule Name Collision Audit and Rename Plan

38 saropa_lints rules were registered under string IDs identical to core Dart/Flutter
analyzer lints, causing duplicate diagnostics and confusing `require_ignore_comment_plugin_prefix`
warnings in downstream projects. This task audited the full collision set, analyzed each
rule's behavioral differences, and produced a rename/drop map.

## Finish Report (2026-08-16)

### What changed

- Bug report filed: `bugs/infra_rule_names_collide_with_core_dart_lints.md`
  - Corrected count from 35 to 38 (added `missing_code_block_language_in_doc_comment`,
    `use_truncating_division`, recounted existing list)
  - Severity raised from Medium to High (zero-conflict policy)
  - Removed hypotheses A/B and multi-option fix section — replaced with decided fix
  - Complete rename map: 35 rules get semantic suffixes, 3 rules dropped

- CHANGELOG bumped from 15.0.5 to 15.1.0 (breaking change)

### Rename convention

Semantic suffixes based on behavioral analysis of each rule vs. its core Dart counterpart:
- `_strict` (7 rules) — stricter detection or elevated severity
- `_with_fix` (13 rules) — adds a quick fix the core lint lacks
- `_extended` (6 rules) — covers additional AST patterns
- `_enforced` (2 rules) — equivalent detection, opinionated scope
- Unique suffixes (7 rules): `_relaxed`, `_safe`, `_local`, `_class_methods`,
  `_resolved`, `_no_maps`, `_null_branch`, `_widget_scoped`, `_no_private`

### Rules dropped (no behavioral difference from core)

1. `avoid_private_typedef_functions` — `lib/src/rules/data/type_rules.dart:2856`
2. `missing_code_block_language_in_doc_comment` — `lib/src/rules/core/documentation_rules.dart:1239`
3. `prefer_initializing_formals` — `lib/src/rules/stylistic/stylistic_whitespace_constructor_rules.dart:843`

### Guard rail: publish-time collision check

Check 8 added to `scripts/modules/_tier_integrity.py`: intersects all registered
saropa_lints rule names against `CORE_DART_LINT_NAMES` (a maintained frozenset of
~200 core Dart/Flutter linter rule names). Any collision fails the publish audit,
blocking release. This runs as part of the existing `check_tier_integrity()` pipeline
invoked by `scripts/publish.py`.

### Implementation not started (renames)

The rename map is documented but no rule-level code changes have been made.
Implementation requires updating each rule's LintCode string, tier registration,
tests, fixtures, ROADMAP, and the `--fix-ignores` migration tool.

### Files changed

- `bugs/infra_rule_names_collide_with_core_dart_lints.md` (new — bug report)
- `CHANGELOG.md` (version bump 15.0.5 → 15.1.0, breaking-change summary)
- `scripts/modules/_tier_integrity.py` (Check 8: core lint collision guard rail)
