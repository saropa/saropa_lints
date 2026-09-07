# HARDENING SPEC: `avoid_unbounded_dependency` — Melos/Workspace False Positive

**Status: Implemented**

Created: 2026-09-06
Type: Hardening (false-positive guard) on a shipped rule
Related: `avoid_unbounded_dependency` in `lib/src/rules/config/pubspec_constraint_rules.dart`;
parser in `lib/src/config/pubspec_constraint_parser.dart`. Filed after `proposal_avoid_any_version.md`
was found to duplicate this already-shipped rule.

---

## Summary

`AvoidUnboundedDependencyRule` flags any dependency whose constraint is `any` or empty. This is correct
for a normal package/app pubspec, but produces a false positive in a pub workspace or Melos monorepo root
pubspec, where a workspace-internal package is legitimately declared with `any` because its real version
resolution happens through a `path:` entry in `dependency_overrides:`, not through the version range.

---

## Current behavior (confirmed by reading the code)

- `AvoidUnboundedDependencyRule.runWithReporter` (pubspec_constraint_rules.dart:176-184) calls
  `parsed.dependencies.any((dep) => dep.constraint.isAny)` and reports once per project root if any
  dependency is unbounded. It has no knowledge of `dependency_overrides:` at all.
- `parsePubspecConstraints` (pubspec_constraint_parser.dart:256-304) only tracks two top-level blocks:
  `environment:` and `dependencies:`/`dev_dependencies:` (via `_depSectionHeader`, which matches literally
  `dependencies` or `dev_dependencies`, not `dependency_overrides`). Any `dependency_overrides:` section is
  silently skipped — `inDepSection` never becomes true for it, so none of its child lines (including
  `path:` sub-map entries) are parsed or represented anywhere in `ParsedPubspec`.
- Confirmed: **no existing awareness of `dependency_overrides:` or `path:` entries.** This is a real gap,
  not a misunderstanding of already-handled logic.

---

## False-positive scenario

A Melos/pub-workspace root `pubspec.yaml` (or a package pubspec inside the workspace) declares an
internal sibling package with an unbounded constraint because the workspace tooling resolves it locally,
and pins the actual source via `dependency_overrides:`:

```yaml
name: my_workspace_root
publish_to: none

dependencies:
  saropa_core: any        # unbounded — flagged today, but resolved via path below

dependency_overrides:
  saropa_core:
    path: ../saropa_core
```

Today this fires `avoid_unbounded_dependency` on `saropa_core`, even though the effective resolved
version is fully pinned to a local path — the `any` in `dependencies:` is inert, not a real reproducibility
risk. This matches the standard Melos/pub-workspace convention (see `pub workspace` docs and Melos
`melos.yaml` bootstrap behavior), so any monorepo using this pattern gets a permanent, unfixable false
positive on its root pubspec.

---

## Proposed fix

Skip flagging a dependency when the **same package name** has a `path:` entry (block form) in
`dependency_overrides:`. The override, not the version constraint, is what pub actually resolves against,
so the constraint's looseness carries no reproducibility risk for that specific package.

### Parser change (`lib/src/config/pubspec_constraint_parser.dart`)

1. Extend `_depSectionHeader` (or add a second regex) to also recognize a `dependency_overrides:`
   top-level header, e.g.:
   ```dart
   final RegExp _overridesSectionHeader = RegExp(r'^dependency_overrides:\s*$');
   ```
2. Add a third section-tracking flag, `inOverridesSection`, alongside `inDepSection`/`inEnvironment` in
   `parsePubspecConstraints`.
3. While inside `dependency_overrides:`, reuse `_depEntry` to capture each overridden package name, then
   look at the following indented lines for a `path:` key (4-space indent, sibling of the 2-space package
   name line — same nesting pattern the `git:`/`hosted:` block parsing would need). Collect matching names
   into a new field, e.g. `Set<String> pathOverriddenPackages`, on `ParsedPubspec`.
   - Only `path:` overrides matter for this guard — a `git:` or `hosted:` override still resolves through
     pub's normal (bounded) version negotiation against a constraint, so it does not neutralize an `any`
     the way a local path does.
4. Add `pathOverriddenPackages` to `ParsedPubspec`'s constructor and fields, with a doc comment explaining
   it exists specifically to suppress the workspace `any` false positive (WHY, not just WHAT — required by
   project comment policy).

### Rule change (`lib/src/rules/config/pubspec_constraint_rules.dart`)

In `AvoidUnboundedDependencyRule.runWithReporter`, change the predicate from:

```dart
return parsed.dependencies.any((dep) => dep.constraint.isAny);
```

to something that excludes names present in `parsed.pathOverriddenPackages`:

```dart
return parsed.dependencies.any(
  (dep) => dep.constraint.isAny &&
      !parsed.pathOverriddenPackages.contains(dep.name),
);
```

Add a comment at this line explaining the exclusion is deliberate: an `any` constraint whose package is
locally path-overridden is not a real reproducibility risk because pub never consults the loose constraint
for resolution.

### Rule doc comment update

Update the DartDoc `**GOOD:**` example on `AvoidUnboundedDependencyRule` to also show the workspace
exemption, so users understand it's intentional rather than assuming the rule has a gap:

```dart
/// **GOOD (workspace-internal package resolved locally):**
/// ```yaml
/// dependencies:
///   saropa_core: any
/// dependency_overrides:
///   saropa_core:
///     path: ../saropa_core
/// ```
```

---

## Edge cases to test

1. **Baseline regression** — a plain unbounded dependency with no `dependency_overrides:` section at all
   must still flag (the common, real case this rule exists for).
2. **`any` + `path:` override for the same package** — must NOT flag (the target fix).
3. **`any` + `git:` override for the same package** — MUST still flag; a git override still resolves
   through a real (if pinned) source, and the loose constraint is still what a fresh `pub get` without the
   override would use. Only `path:` neutralizes the risk.
4. **`any` + `hosted:` override for the same package** — MUST still flag, same reasoning as `git:`.
5. **`dependency_overrides:` present but for a *different* package than the unbounded one** — the unbounded
   package must still flag; the override doesn't apply to it.
6. **Empty `dependency_overrides: {}`** — must behave identically to no section at all (still flags any
   unbounded dependency).
7. **Case where `dependency_overrides:` appears before `dependencies:` in file order** — parser must not
   assume section order; `pathOverriddenPackages` must be fully collected regardless of whether the
   overrides section is above or below the dependency list (single top-to-bottom parse pass already handles
   this if the override-name collection doesn't gate on having already seen `dependencies:`).
8. **Multiple unbounded dependencies, only one of which has a `path:` override** — only the non-overridden
   one should flag; verifies the exclusion is per-package, not all-or-nothing for the whole file.
9. **`path:` value that is itself malformed/missing** (e.g. `dependency_overrides:\n  foo:\n` with no
   child `path:` line) — must NOT suppress; only an actual `path:` key found under the override entry
   counts. Falls through to still-flag behavior for `foo` if `foo` is also unbounded elsewhere.
10. **Non-workspace apps that use `dependency_overrides` for unrelated packages while separately having an
    unrelated unbounded `any` dependency** — must still flag the unrelated `any` dependency; the guard is
    scoped strictly by package name equality, not "any override present anywhere in the file."

---

## Decision

Not yet implemented — this document is the spec only, per instruction not to implement code changes.

---

## Commits

(none — spec only)
