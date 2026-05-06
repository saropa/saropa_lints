# Migration Candidate #110

**Source:** Dart SDK 3.0.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** Metrics, Metric, Counter, Removed

---

## Release Note Entry

> - Removed the deprecated [`Metrics`][], [`Metric`][], [`Counter`][],
>
> Context: and [`Gauge`][] classes as they have been broken since Dart 2.0.

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `Metrics`
- `Metric`
- `Counter`
- `Removed`

---

## Proposed Lint Rule

**Rule Type:** `deprecation_migration`
**Estimated Difficulty:** medium

### Detection Strategy

Detect usage of the deprecated API via AST method/property invocation nodes

**Relevant AST nodes:**
- `MethodInvocation`
- `PropertyAccess`
- `PrefixedIdentifier`
- `SimpleIdentifier`

### Fix Strategy

Replace with the recommended alternative API

---

## Implementation Checklist

- [ ] Verify the API change in Flutter/Dart SDK source
- [ ] Determine minimum SDK version requirement
- [ ] Write detection logic (AST visitor)
- [ ] Write quick-fix replacement
- [ ] Create test fixture with bad/good examples
- [ ] Add unit tests
- [ ] Register rule in `all_rules.dart`
- [ ] Add to tier in `tiers.dart`
- [ ] Update ROADMAP.md
- [ ] Update CHANGELOG.md

---

**Status:** Not started
**Generated:** From Dart SDK v3.0.0 release notes
