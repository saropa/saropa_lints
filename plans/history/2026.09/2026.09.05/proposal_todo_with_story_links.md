# PROPOSAL: Require TODO/FIXME Comments to Reference a Tracked Issue

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_todo_format`, `prefer_fixme_format`, `prefer_hack_format`

---

## Summary

Add `todo_with_story_links` to require every `// TODO`/`// FIXME` comment to include a reference to a tracked issue (a URL, or a `#123`/`PROJ-123`-shaped ticket ID), not just a free-text explanation or an author name.

**Closes gap:** `ripplearc_linter`'s general "TODO must reference a ticket" concept (no specific rule name given upstream). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Documentation conventions" gap theme.

---

## Motivation

saropa already ships `prefer_todo_format`/`prefer_fixme_format`/`prefer_hack_format`, which enforce marker *format* (`// TODO(name): ...`), but none of them require the comment to point at a place where the work is actually tracked. An untracked TODO is a promise nobody can find again — it survives in the codebase indefinitely because there's no issue to close it out. Many_lints' `avoid_todo_comments` has the same gap noted in `GAP_ANALYSIS.md` (Partial: "checks marker format, not whether an issue/URL reference is present").

---

## Detection / Behavior

Flag a `// TODO(...)`/`// FIXME(...)` comment token whose text does not contain a configured issue-reference pattern (default: a URL, or `#\d+`, or a configurable ticket-prefix regex such as `PROJ-\d+`).

### Should flag (bad code)

```dart
// TODO(alice): clean this up later
void legacyMigration() {} // LINT — no issue reference
```

### Should pass (good code)

```dart
// TODO(alice): remove after PROJ-4821 ships
void legacyMigration() {} // OK — ticket reference present

// FIXME(bob): https://github.com/saropa/app/issues/512
void hackyWorkaround() {} // OK — URL reference present
```

---

## Proposed Tier

Tier: Recommended
Justification: Untracked TODOs are a real maintenance-debt risk, but the required ticket-prefix pattern is project-specific configuration, so it sits just above Essential.

---

## Edge Cases

1. **`// TODO` with no author/parentheses at all** — should flag; missing both author and issue reference.
2. **Ticket reference inside a following line, not the same comment** — should discuss; simplest implementation only inspects the single comment token, which may miss multi-line TODO blocks.
3. **Generated code TODOs (e.g. from `freezed`/`json_serializable` templates)** — should pass; standard generated-file suppression applies.
4. **A TODO referencing an internal doc link instead of an issue tracker (e.g. a Notion/Confluence URL)** — should pass under the default "any URL" pattern; teams wanting stricter tracker-only enforcement can narrow the configured regex.

---

## Alternatives Considered

- **Fold into `prefer_todo_format` as a stricter mode instead of a new rule** — rejected; format vs. traceability are separable concerns and some teams want format enforcement without mandating ticket links (or vice versa).

---

## Decision

---

## Implementation Notes

---

## Commits
