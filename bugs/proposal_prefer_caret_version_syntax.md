# PROPOSAL: Prefer Caret Version Syntax

**Status: Open**

Created: 2026-09-02

**Conflicts with:** [`prefer_pinned_version_syntax`](proposal_prefer_pinned_version_syntax.md) — mutually exclusive; a project enables at most one.

## Summary

Flags a verbose version-range constraint in `pubspec.yaml` (e.g. `">=1.2.3 <2.0.0"`) that is equivalent to a caret constraint, and suggests the shorter `^1.2.3` form.

## Motivation

`^1.2.3` and `">=1.2.3 <2.0.0"` resolve identically under pub's versioning rules, but the caret form is shorter, is what `dart pub add` writes by default, and reads unambiguously as "compatible with 1.2.3." A verbose range forces a reviewer to mentally re-derive that it means the same thing as a caret constraint, and makes it easy to introduce a subtly wrong upper bound (e.g. `<2.0.1` instead of `<2.0.0`) by hand.

## Detection / Behavior

Fires when a dependency's version constraint is a `>=X.Y.Z <A.B.C` range whose bounds are exactly what `^X.Y.Z` would produce (upper bound is the next breaking version per pub's caret rules), and the constraint is not already caret syntax.

**BAD:**
```yaml
dependencies:
  http: ">=1.2.3 <2.0.0"
```

**GOOD:**
```yaml
dependencies:
  http: ^1.2.3
```

## Quick Fix

Rewrite the constraint string to `^<lower-bound>`.

## Alternatives Considered

**Scope: applications vs. packages.** This rule suits applications and internal packages that want a single, easy-to-read source-controlled constraint and don't need to encode an unusual/asymmetric range — caret syntax always implies pub's standard "next breaking version" cutoff. It is a poor fit for **published packages that need a wider or hand-tuned range for consumer compatibility** (e.g. supporting two major versions of a peer dependency, or a narrower-than-caret range to exclude a known-bad point release) — those legitimately need the verbose `>=`/`<` form and should not be pushed toward caret. Mutually exclusive with `prefer_pinned_version_syntax`, which pushes the opposite direction (exact pins, no range at all) for teams prioritizing build reproducibility over consumer flexibility.

## Existing Coverage

Partial infrastructure exists. `lib/src/config/pubspec_constraint_parser.dart` already parses each constraint into a `ParsedConstraint` with `isCaret`, `hasLower`, `hasUpper`, `lower`, and `upper` (`SemverParts`) — everything needed to detect "this range's bounds equal what `^lower` would produce" without writing a new parser. `lib/src/rules/config/pubspec_constraint_rules.dart` already has five sibling rules built on this exact parser (`RequireSdkUpperBoundRule` and four others) using the shared `_reportPubspecOnce` helper, so this rule would slot into that file as a sixth rule rather than needing new plumbing.
