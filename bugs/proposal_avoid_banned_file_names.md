# PROPOSAL: Config-Driven Banned File Name Patterns

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_snake_case_files` (general naming-convention rule — this proposal is a config-driven ban/deny-list, not a fixed convention check)

---

## Summary

Add a config-driven rule that flags a source file whose file name matches a project-configured banned pattern (exact name, prefix, suffix, or glob), letting a team enforce house rules like "no file may be literally named `utils.dart`" or "no `*_impl.dart` files outside `src/internal/`".

**Closes gap:** DCM `avoid-banned-file-names` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

`saropa_lints` already validates that file names follow `snake_case` (`prefer_snake_case_files`) and that a file's class matches its file name in some contexts, but it has no mechanism for banning specific file-name *patterns* outright, independent of casing correctness. Teams commonly want to ban generically-named catch-all files — `utils.dart`, `helpers.dart`, `misc.dart`, `common.dart` — because they become unbounded dumping grounds that erode module boundaries over time, or to ban a legacy naming convention (`*_old.dart`, `*_deprecated.dart`) that should have been deleted rather than kept around.

DCM (dcm.dev) ships this as `avoid-banned-file-names`: a project configures a list of banned file-name patterns and the rule flags any file whose basename matches one. saropa_lints has no file-name ban-list mechanism at all — the closest rule (`prefer_snake_case_files`) checks casing style, not name content, so a correctly-`snake_case`d file named `utils.dart` passes it cleanly today.

---

## Detection / Behavior

Config-driven via a new `banned_file_names` key in `analysis_options_custom.yaml`: a list of entries with a `pattern` (exact match, `*` wildcard, or basename-only glob) and optional `reason`. The rule runs once per compiled unit via `context.addCompilationUnit`, extracts the basename from `context.filePath`, and matches it against the configured patterns — reporting at the start of the file (offset 0) since there is no single AST node that represents "the file's name."

### Should flag (bad code)

```dart
// analysis_options_custom.yaml:
// banned_file_names:
//   - pattern: "utils.dart"
//     reason: "Generic dumping-ground file names erode module boundaries. Name by responsibility instead."
//   - pattern: "*_old.dart"
//     reason: "Delete deprecated files instead of renaming them with a suffix."

// File: lib/src/utils.dart  → LINT, whole-file diagnostic
// File: lib/src/parser_old.dart → LINT, matches *_old.dart
```

### Should pass (good code)

```dart
// File: lib/src/string_formatting_utils.dart → OK — not an exact "utils.dart" match
// File: lib/src/json_parser.dart → OK — not in the ban list
```

---

## Proposed Tier

Tier: Comprehensive
Justification: empty-by-default config surface, same reasoning as the sibling `avoid_banned_annotations`/`avoid_banned_imports`/`avoid_banned_types` proposals — zero diagnostics until a project opts in with its own ban list, so it belongs alongside saropa's other team-governance rules rather than a universally-applicable tier.

---

## Edge Cases

1. **Generated files (`.g.dart`, `.freezed.dart`)** — a banned pattern like `*_old.dart` should not accidentally match a codegen-produced file with an unrelated naming coincidence; per the project's existing convention (see `.claude/rules/i18n.md` and the Common Pitfalls table in `bugs/ISSUE_REPORT_GUIDE.md`), the rule should skip `resolver.path` suffixes recognized as generated (`.g.dart`, `.freezed.dart`, `.gr.dart`) even if a literal pattern would otherwise match, since those names are not human-authored choices.
2. **Case sensitivity on case-insensitive filesystems (Windows)** — pattern matching should be case-sensitive by default (matching Dart's own `snake_case` convention and DCM's documented behavior), but should not silently mismatch on Windows where the actual file on disk may differ in case from what a glob author expects; document this rather than attempting filesystem-dependent normalization.
3. **Directory-scoped bans (`src/legacy/*_old.dart` vs. bare `*_old.dart`)** — v1 should support basename-only patterns (matching DCM's simplest form); full-path glob patterns that also scope to a directory are a natural follow-up but add meaningfully more parsing complexity (path separator normalization across platforms) for a case that can usually be handled by scoping the *reason* message rather than the pattern itself.

---

## Alternatives Considered

- **A pre-commit / CI shell script that greps file names** — rejected for the same reason as the sibling export-ban proposal: it runs outside the IDE feedback loop, so a developer only discovers the violation at commit or CI time instead of while creating the file.
- **Folding this into `prefer_snake_case_files`** — rejected because that rule validates a structural convention (casing) that is either satisfied or not, with no configuration surface; adding an arbitrary ban-list parameter to it would conflate "this name violates Dart casing" with "this name is banned by house style," which are different failure classes with different correction messages.

---

## Decision

---

## Implementation Notes

---

## Commits
