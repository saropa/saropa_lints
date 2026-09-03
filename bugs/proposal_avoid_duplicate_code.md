# PROPOSAL: Cross-File Duplicate-Code (AST Clone) Detector

**Status: Open**

Created: 2026-09-02
Type: New rule (cross-file analysis)
Related rules: none

---

## Summary

Add `avoid_duplicate_code` — a cross-file structural-clone detector that flags near-identical code blocks
(function bodies, method bodies) repeated across the project above a configurable token/line-count
threshold, independent of variable/literal renaming. This is a different class of check from any existing
saropa rule: it requires comparing AST shapes ACROSS files rather than a single-file/single-node visitor.

**Closes gap:** `solid_lints` `avoid_duplicate_code` (github.com/solid-software/solid_lints). Implementing
this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Copy-pasted logic is one of the most common sources of drift bugs: a fix applied to one copy and forgotten
in the other(s). saropa already has cross-file analysis infrastructure for other project-wide concerns
(unused files, circular dependencies — see `saropa-lints-diagnostics-and-tooling`'s project-health tooling),
so a clone detector is a natural extension of capability the engine already has some of, rather than a
wholly new analysis category. `solid_lints` ships this as prior art; it is the only alternative package in
the audit offering a true structural (not textual) clone detector.

---

## Detection / Behavior

### Should flag (bad code)

```dart
// lib/features/user/user_validator.dart
bool isValidEmail(String email) {
  if (email.isEmpty) return false;
  return email.contains('@') && email.contains('.');
}

// lib/features/admin/admin_validator.dart
bool checkEmailFormat(String value) { // LINT — avoid_duplicate_code: near-identical to isValidEmail in user_validator.dart
  if (value.isEmpty) return false;
  return value.contains('@') && value.contains('.');
}
```

### Should pass (good code)

```dart
// lib/core/validators/email_validator.dart
bool isValidEmail(String email) {
  if (email.isEmpty) return false;
  return email.contains('@') && email.contains('.');
}

// lib/features/user/user_validator.dart
import 'package:app/core/validators/email_validator.dart';
final valid = isValidEmail(email); // OK — shared implementation, no duplication
```

---

## Proposed Tier

Tier: Pedantic (opt-in — cross-file, project-scale analysis)
Justification: Cross-file structural comparison is computationally heavier than a single-file AST visitor and
carries real tuning/threshold risk (too sensitive → noisy on legitimately-similar-but-distinct code; too
loose → misses real duplication); matches saropa's placement for other project-wide, opt-in analyses rather
than default-on per-file rules.

---

## Edge Cases

1. **Structurally identical boilerplate that is idiomatically expected to repeat** (e.g. every `Bloc`'s
   `initState`-equivalent registration pattern, generated-looking constructor bodies) — needs discussion;
   likely needs a minimum statement-count/complexity threshold well above trivial boilerplate to avoid
   flooding on idiomatic repetition.
2. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression
   applies, and generated files are also the single highest-volume source of legitimate structural repetition.
3. **Two blocks identical except for variable names and literal values** (a "Type-2" clone in clone-detection
   terminology) — should flag; this is exactly the target case, matching `solid_lints`' scope of comparing
   AST shape rather than exact text.
4. **Test files with intentionally repeated arrange/act/assert scaffolding across many test cases** — needs
   discussion; test suites are a known high-false-positive zone for clone detectors — likely needs either a
   `test/` exemption or a higher threshold specifically for test files.
5. **Duplication spanning a large percentage of a huge generated or vendored file** — should pass; scope
   detection to project-authored source, matching saropa's existing generated/vendored exclusions.

---

## Alternatives Considered

- **Textual/token-hash diffing instead of AST-shape comparison** — rejected; token-level hashing catches
  exact-copy-paste but misses the common case of a paste-then-rename-variables clone, which is the more
  valuable case to catch per the source rule's own design intent.
- **Ship as a standalone CLI tool rather than a lint rule** — considered, since it's structurally closer to
  saropa's existing `project_health`/cross-file tooling than a per-file `SaropaLintRule`. Recommend
  prototyping via the existing cross-file analysis infrastructure first and deciding CLI-vs-rule placement
  during implementation, since the detection algorithm is shared either way.

---

## Decision

---

## Implementation Notes

- Load `Skill(saropa-lints-diagnostics-and-tooling)` before implementation — this is the closest existing
  precedent for project-wide, multi-file analysis in the codebase (unused-file/circular-dependency detection).
- Threshold tuning (minimum clone size, similarity percentage) will need real-world calibration against
  saropa's own codebase and a few sample projects before shipping a default; expect an iterative pass.

---

## Commits
