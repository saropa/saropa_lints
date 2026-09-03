# PROPOSAL: Prefer Commenting Pubspec Ignores

**Status: Open**

Created: 2026-09-02

## Summary

Flags a `dependency_overrides:` entry, or a `# ignore:`-style suppression comment, in `pubspec.yaml` that has no explanatory comment above it.

## Motivation

`dependency_overrides:` forces a specific version of a transitive dependency, silently overriding whatever the rest of the graph resolves to — it is a deliberate, load-bearing exception, not a routine dependency add. Without a comment explaining why the override exists (a security patch, a workaround for an upstream bug, a temporary pin pending a fix), the next contributor has no way to tell whether it is safe to remove, and it tends to survive long after the reason for it is gone because nobody wants to touch an unexplained override.

## Detection / Behavior

Fires when a top-level entry under `dependency_overrides:` in `pubspec.yaml` (or a suppression-style comment such as `# ignore:` appearing directly in the file) has no comment on the line(s) immediately preceding it.

**BAD:**
```yaml
dependency_overrides:
  meta: 1.11.0
```

**GOOD:**
```yaml
dependency_overrides:
  # Pin meta to 1.11.0: 1.12.0 breaks build_runner codegen, see #482.
  # Remove once build_runner 2.5 ships.
  meta: 1.11.0
```

## Quick Fix

None — manual refactor required. An auto-fix cannot fabricate the reason for an override; the rule can only flag the missing comment, not write it.

## Alternatives Considered

Could scope this narrower to `dependency_overrides:` only, leaving `# ignore:`-style comment-suppressions out of the rule's remit (those already carry a "why" convention enforced project-wide per `CLAUDE.md`, arguably making a dedicated pubspec check redundant with reviewer diligence rather than lint enforcement). Kept both in scope in this proposal since both are "silent override with no audit trail" in the same file, but the implementation could ship the `dependency_overrides:` check first and treat the comment-suppression half as a stretch goal.

## Existing Coverage

None found. No rule in `lib/src/rules/config/` inspects `dependency_overrides:` or requires comments on it; `SortPubDependenciesRule` treats `dependency_overrides:` only as a section to sort, not to require justification for. Would need a new line-based scanner (read pubspec.yaml, find `dependency_overrides:` entries, check the preceding non-blank line for a `#` comment), following the same `_reportPubspecOnce`-style reporting pattern as the other pubspec rules.
