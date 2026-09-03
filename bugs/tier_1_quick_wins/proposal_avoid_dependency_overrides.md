# PROPOSAL: Flag a Non-Empty `dependency_overrides:` Section in `pubspec.yaml`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_any_version` (companion pubspec-hygiene proposal)

---

## Summary

Add `avoid_dependency_overrides` to flag any entry present in a `pubspec.yaml` `dependency_overrides:`
section, which forces `pub` to resolve a package to a specific version/source regardless of what the normal
dependency graph would otherwise choose — a mechanism meant for temporary local debugging, not something
that should ship committed to a repository long-term.

**Closes gap:** `flutter_skill_lints` `avoid_dependency_overrides`
(github.com/sgaabdu4/flutter_skill_lints). Implementing this proposal as specified fully closes this
competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`dependency_overrides:` exists to let a developer temporarily force a specific package resolution — pointing
at a local path checkout while developing a fix upstream, or pinning around a broken published version. Left
committed, it silently diverges the project's actual resolved dependency graph from what its own version
constraints declare, which confuses `pub outdated`, hides real constraint conflicts that should be fixed
properly, and can mask an incompatibility that will resurface the moment the override is removed. It is a
debugging tool that regularly gets forgotten in the pubspec after the immediate problem is solved.

---

## Detection / Behavior

### Should flag (bad code)

```yaml
dependency_overrides:
  http: # LINT — avoid_dependency_overrides: overrides forgotten in committed pubspec.yaml
    path: ../local_http_fork
```

### Should pass (good code)

```yaml
# No dependency_overrides section — OK, or section present but empty
```

---

## Proposed Tier

Tier: Recommended
Justification: Real hygiene/reproducibility signal, but legitimate short-lived uses exist (actively working
around an upstream bug with a fix already submitted upstream), so it should be visible by default without
being an Essential-tier hard-stop; teams that intentionally maintain a long-term override (e.g. a monorepo
pinning strategy) can suppress per-entry.

---

## Edge Cases

1. **Empty `dependency_overrides:` section** (`dependency_overrides: {}` or the key present with no
   children) — should pass; nothing is actually being overridden.
2. **An override pointing at a `git:` ref pinned to a specific commit as a stopgap for an unpublished fix**
   — should still flag; the rule targets the presence of ANY override, and the specific reason doesn't change
   the reproducibility/staleness risk of leaving it committed.
3. **Melos/monorepo workspace pubspecs that use `dependency_overrides` as their standard sibling-package
   linking mechanism** — needs discussion; some monorepo tooling generates this section automatically as
   infrastructure rather than a debugging escape hatch — may warrant a workspace-aware exemption similar to
   the one considered for `avoid_any_version`.
4. **`// TODO(remove-before-release):`-style comment above the override** — should still flag; a comment
   documenting intent doesn't remove the risk of it being forgotten, and this rule's entire purpose is to
   catch exactly the case where the removal step got skipped.

---

## Alternatives Considered

- **Only flag overrides without an accompanying TODO/tracking comment** — rejected as the default behavior;
  detecting "is there a comment nearby" is a weak, easily-gamed signal, and a plain presence check is simpler
  and matches the source rule's own scope. A project wanting a permanent override can suppress the specific
  line with `// ignore:` and a one-line justification per saropa's standard suppression policy.

---

## Decision

---

## Implementation Notes

- This rule inspects `pubspec.yaml`, not `.dart` source files — same non-Dart-file entry-point consideration
  as `avoid_any_version`; consider implementing both together given the shared file-type handling.

---

## Commits
