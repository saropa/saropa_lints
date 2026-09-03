# PROPOSAL: Prefer Pinned Version Syntax

**Status: Open**

Created: 2026-09-02

**Conflicts with:** [`prefer_caret_version_syntax`](proposal_prefer_caret_version_syntax.md) — mutually exclusive; a project enables at most one.

**Tier disposition — conflicting pair.** Both rules ship in the **stylistic tier** per the established `tiers.dart` convention for opposed rules (documented at the top of `stylisticRules`, e.g. `prefer_single_quotes_strict` vs `prefer_double_quotes_with_fix`): neither is enabled by default and the project explicitly opts into one. Add both to `stylisticRules` and list the pair in `README_STYLISTIC.md`. Never assign either to a default-on tier — there is no correct default here (apps favor reproducible pins, published packages need ranges so consumers can resolve).

## Summary

Flags a caret-range version constraint in `pubspec.yaml` (e.g. `^1.2.3`) and suggests pinning to the exact resolved version (`1.2.3`) instead.

## Motivation

A caret range lets `dart pub get` silently resolve to any non-breaking version up to the next major — which means two developers running `pub get` on the same commit at different times, or a CI run days after the last commit, can end up building against different dependency versions even with a checked-in `pubspec.lock` if the lock file itself isn't strictly respected (e.g. `pub upgrade`, a stale lock deleted in CI, or a Renovate/Dependabot bot that bumps the lock without review). For teams that need bit-for-bit reproducible builds — release pipelines, security-sensitive apps — an exact pin in `pubspec.yaml` removes that ambiguity at the source instead of relying entirely on lockfile discipline.

## Detection / Behavior

Fires when a dependency's version constraint uses caret syntax (`^X.Y.Z`) or an open range, rather than an exact version.

**BAD:**
```yaml
dependencies:
  http: ^1.2.3
```

**GOOD:**
```yaml
dependencies:
  http: 1.2.3
```

## Quick Fix

Rewrite the constraint string to the exact lower-bound version (`^1.2.3` → `1.2.3`).

## Alternatives Considered

**Scope: applications vs. packages.** This rule suits **applications** (`publish_to: none`) that own their entire deployment pipeline and want every build reproducible without depending on lockfile hygiene — the exact version is the single source of truth. It is a poor fit for **published packages**, where pinning every dependency to an exact version needlessly narrows what consumers can resolve against and causes version-conflict errors for any consumer who also depends on a slightly different version of the same package — packages should almost always prefer `prefer_caret_version_syntax`'s range form instead. Mutually exclusive with `prefer_caret_version_syntax` for that reason; both firing on the same project would produce contradictory guidance on every dependency line.

## Existing Coverage

Partial infrastructure exists, same as its conflicting counterpart. `lib/src/config/pubspec_constraint_parser.dart`'s `ParsedConstraint.isCaret` / `hasLower` / `hasUpper` fields already distinguish an exact pin from a caret or open range without new parsing work, and `lib/src/rules/config/pubspec_constraint_rules.dart` already hosts five sibling rules on this parser using the shared `_reportPubspecOnce` reporting helper — this rule would be a sixth addition to that file, not new plumbing.
