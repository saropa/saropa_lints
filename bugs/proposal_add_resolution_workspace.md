# PROPOSAL: Add Resolution Workspace

**Status: Open**

Created: 2026-09-02

## Summary

Flags a package's `pubspec.yaml` that lives inside a Dart/Flutter pub workspace (a sibling `pubspec.yaml` above it declares `workspace:`) but does not itself declare `resolution: workspace`.

## Motivation

Dart 3.6 introduced pub workspaces so a monorepo can share a single lockfile and resolve inter-package dependencies without `path:` overrides or `melos bootstrap`. A member package that omits `resolution: workspace` falls back to independent resolution — its own `pubspec.lock`, its own dependency graph — which silently defeats the workspace and reintroduces version drift between packages that are supposed to be locked together. This is easy to miss when scaffolding a new package into an existing monorepo, since `dart create` does not add the field automatically.

## Detection / Behavior

Fires when: the containing project root's `pubspec.yaml` (or an ancestor within the repo) has a top-level `workspace:` list naming this package's directory, AND this package's own `pubspec.yaml` has an `environment:` block without a `resolution: workspace` entry.

**BAD** (member package, root `pubspec.yaml` has `workspace: [packages/foo]`):
```yaml
# packages/foo/pubspec.yaml
name: foo
environment:
  sdk: ^3.6.0
```

**GOOD:**
```yaml
# packages/foo/pubspec.yaml
name: foo
environment:
  sdk: ^3.6.0
resolution: workspace
```

## Quick Fix

Insert `resolution: workspace` immediately after the `environment:` block (or after `sdk:` inside it, matching the layout `dart create` produces for workspace members).

## Alternatives Considered

Could instead flag the root pubspec for missing `workspace:` entries that point at directories with a `pubspec.yaml` — the inverse direction. Rejected as the primary scope: a missing `workspace:` line is a deliberate omission (the package isn't meant to join the workspace) far more often than a missing `resolution: workspace` is deliberate, so the member-side check has a much lower false-positive rate.

## Existing Coverage

None. Grepped `lib/src/` for `resolution`/`workspace` — no existing rule reasons about pub workspaces or the `resolution:` key. `lib/src/config/pubspec_constraint_parser.dart` and `lib/src/rules/config/pubspec_constraint_rules.dart` only parse version-constraint ranges (SDK/dependency bounds), not workspace membership, so this would need a new small parser (read the current pubspec plus walk parent directories for a `workspace:` list) rather than reusing that infrastructure directly. The existing `_reportPubspecOnce`-style pattern (read pubspec.yaml from disk once per root, attach diagnostic to the top of a `lib/` Dart file) is directly reusable for the reporting mechanics.
