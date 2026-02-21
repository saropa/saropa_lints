# Migration Candidate #017

**Source:** Flutter SDK 3.29.0
**Category:** Deprecation
**Relevance Score:** 7
**Detected APIs:** ButtonStyleButton.iconAlignment, Deprecate, TahaTesser

---

## Release Note Entry

> Deprecate unused `ButtonStyleButton.iconAlignment` property by @TahaTesser in 160023
>
> Context: * Add script to check format of changed dart files by @goderbauer in 160007

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `ButtonStyleButton.iconAlignment`
- `Deprecate`
- `TahaTesser`

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
**Generated:** From Flutter SDK v3.29.0 release notes
