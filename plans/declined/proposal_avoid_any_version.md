# PROPOSAL: Flag `any` Version Constraints in `pubspec.yaml`

**Status: Declined — duplicate of shipped rule**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_any_version` to flag a `pubspec.yaml` dependency declared with the `any` version constraint
(`package_name: any`), which accepts every published version of the package with no lower or upper bound —
the widest, least safe constraint form available in `pub`.

**Closes gap:** `flutter_skill_lints` `avoid_any_version` (github.com/sgaabdu4/flutter_skill_lints).
Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`any` disables `pub`'s version resolution safety net entirely: a fresh `pub get` can silently pull in a
brand-new major version with breaking API changes, and there is no way to tell from the pubspec what version
range the project was actually built and tested against. This is materially worse than even an unbounded
caret constraint (`^1.0.0`, which at least fixes a compatible major version) and worse than a loose range
(`>=1.0.0 <3.0.0`, which at least documents intent). It typically appears from a hasty `dependency: any` add
during prototyping that never gets tightened before shipping.

---

## Detection / Behavior

### Should flag (bad code)

```yaml
dependencies:
  http: any # LINT — avoid_any_version: unbounded version constraint, pin a range
```

### Should pass (good code)

```yaml
dependencies:
  http: ^1.2.0 # OK — caret constraint bounds the accepted major version
```

---

## Proposed Tier

Tier: Essential
Justification: `pubspec.yaml` hygiene rule with a real supply-chain/reproducibility risk and effectively zero
false-positive surface — `any` has no legitimate use case in an application or published package pubspec,
making it safe for the default-on tier.

---

## Edge Cases

1. **`any` used in `dependency_overrides:`** — should still flag; even a temporary override benefits from a
   bounded constraint, and an unbounded override is arguably higher-risk than an unbounded primary dependency
   since overrides are easy to forget about.
2. **`any` used for a `dev_dependencies:` entry** — needs discussion; dev-only tooling dependencies carry
   lower production risk, but still forfeit reproducible builds — likely still flag, perhaps at a lower
   default severity.
3. **Git/path dependency with no `version:` key at all** (`http: {git: ...}`) — should pass; this is a
   different declaration shape (no semver constraint field exists to be `any`), not the same defect.
4. **Melos/monorepo workspace pubspec using `any` deliberately for a workspace-internal package meant to
   always resolve to the local path** — needs discussion; may warrant an exemption when combined with
   `workspace:` resolution, since the intent there is "always use the local sibling package" not "accept any
   published version."

---

## Alternatives Considered

- **Fold into an existing pubspec-hygiene rule rather than a standalone rule** — checked `bugs/` for an
  existing pubspec-ordering/hygiene proposal; none currently target version-constraint strictness
  specifically, so a standalone rule matches the source package's own granularity.

---

## Decision

**Declined — this exact rule already shipped.** `AvoidUnboundedDependencyRule`
(`avoid_unbounded_dependency`) in
`lib/src/rules/config/pubspec_constraint_rules.dart` has flagged `package: any` (and the empty
constraint) since v14.1.0 (`plans/history/2026.06/2026.06.18/PLAN_PUBSPEC_REVIEWER.md`). Its message
text, correction message, and bad/good examples are near-identical to this proposal's. The gap-analysis
note that opened this proposal (`flutter_skill_lints` `avoid_any_version`) was already closed by that
rule; the proposal was raised without checking the existing rule set first.

Answers to the proposal's open questions, recorded here for whoever next touches
`avoid_unbounded_dependency`, since the questions themselves are still valid — they just apply to the
existing rule, not a new one:

- **`dev_dependencies: any` severity** — already flagged, no severity split. The parser's
  `_depSectionHeader` regex matches both `dependencies:` and `dev_dependencies:` and the rule applies one
  WARNING severity to both. No FP risk: `any` in `dev_dependencies` still breaks reproducible CI/codegen
  tooling versions, so a single severity is correct and matches the project's single-source-of-truth
  principle — do not special-case dev deps.
- **`dependency_overrides: any` during migration** — NOT covered. `_depSectionHeader` in
  `lib/src/config/pubspec_constraint_parser.dart` only matches `dependencies:` / `dev_dependencies:`, so
  an `any` inside `dependency_overrides:` is currently silent. This is a real gap, but the right fix is
  `plans/tier_1_quick_wins/proposal_avoid_dependency_overrides.md` (still Open), which already proposes
  flagging the presence of ANY `dependency_overrides` entry outright — a temporary-migration `any` override
  is a strict subset of that proposal's scope. Extending `avoid_unbounded_dependency` to also walk
  `dependency_overrides:` would be redundant once that proposal ships; do not build both.
- **Melos/workspace `any` for workspace-internal packages** — real, currently UNGUARDED false-positive
  risk on the shipped rule. `parsePubspecConstraints` has no awareness of Dart/Flutter pub workspaces
  (`resolution: workspace`) or melos path-override conventions, so a monorepo root pubspec declaring
  `package: any` for a sibling workspace package will fire today. Proposed heuristic for a future fix: skip
  a dependency when the same package name has a `path:`-block entry under `dependency_overrides:` in the
  same pubspec (the common melos/workspace pattern of `any` + a local path override), rather than trying to
  detect melos/workspace config directly. Not implemented as part of this decision — file as a follow-up FP
  report against `avoid_unbounded_dependency` if/when a real project hits it.
- **Non-Dart-file pattern confirmed** — `lib/src/rules/config/pubspec_constraint_rules.dart` already
  establishes and documents the pattern (read `pubspec.yaml` from disk once per project root via
  `_reportPubspecOnce`, attach the diagnostic to the top of a `lib/` Dart file, dedupe per root because
  `custom_lint` only analyzes `.dart` files). Confirmed working and shared by five existing rules; no new
  entry point needed.

No implementation work follows from this proposal. Moved to `plans/declined/`.

---

## Implementation Notes

- This rule inspects `pubspec.yaml`, not `.dart` source files — confirm saropa's existing pattern for
  non-Dart-file rules (if any) before implementation; if no such pattern exists yet, this may need a new
  file-type entry point rather than the standard AST visitor.

---

## Finish Report (2026-09-06)

The proposed `avoid_any_version` rule duplicates a rule already shipped in v14.1.0. No new lint code
was written; the review confirmed `AvoidUnboundedDependencyRule` (`avoid_unbounded_dependency`,
`lib/src/rules/config/pubspec_constraint_rules.dart`) already flags `package: any` in both
`dependencies:` and `dev_dependencies:` with message text and examples matching this proposal almost
verbatim.

Cross-references updated to stop pointing at the now-declined proposal as if it were open work:
`doc/guides/migration_guides/migration_from_flutter_skill_lints.md` (the `flutter_skill_lints`
parity table row for `avoid_any_version` now points at `avoid_unbounded_dependency` instead of a TODO
proposal link) and `plans/tier_1_quick_wins/duplicate_manifest.json` (the automated dedup scan's entry
for this file was corrected from `status: new` to `status: duplicate`, since its rule-name-only
matching missed the conceptual overlap with `avoid_unbounded_dependency`).

Two follow-up items were surfaced but not built, per the proposal's own edge cases:
- `avoid_unbounded_dependency` does not currently walk `dependency_overrides:`, so `any` there is
  silent. The correct owner for that gap is `plans/tier_1_quick_wins/proposal_avoid_dependency_overrides.md`
  (still open), not a change to this rule.
- `avoid_unbounded_dependency` has no melos/pub-workspace awareness and will false-positive on a
  monorepo root pubspec that deliberately declares `package: any` for a workspace-internal sibling. No
  bug report was filed since this is theoretical pending a real project hitting it; a possible fix
  (skip when the same package name has a `path:` `dependency_overrides` entry) is recorded above for
  whoever picks it up.

## Commits
