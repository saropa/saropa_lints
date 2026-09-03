# PROPOSAL: Flag `any` Version Constraints in `pubspec.yaml`

**Status: Open**

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

---

## Implementation Notes

- This rule inspects `pubspec.yaml`, not `.dart` source files — confirm saropa's existing pattern for
  non-Dart-file rules (if any) before implementation; if no such pattern exists yet, this may need a new
  file-type entry point rather than the standard AST visitor.

---

## Commits
