# Plan #018

**Source:** Flutter SDK 3.29.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** SurfaceProducer.onSurfaceCleanup, onSurfaceDestroyed, Add

---

## Release Note Entry

> Add `SurfaceProducer.onSurfaceCleanup`, deprecate `onSurfaceDestroyed`. by @matanlurey in 160937
>
> Context: * Fix docImport issues by @goderbauer in 160918

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `SurfaceProducer.onSurfaceCleanup`
- `onSurfaceDestroyed`
- `Add`

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

- [x] Verify the API change in Flutter/Dart SDK source
- [x] Determine minimum SDK version requirement
- [x] Write detection logic (AST visitor)
- [x] Write quick-fix replacement
- [ ] Create test fixture with bad/good examples (requires Flutter SDK for type resolution)
- [x] Add unit tests
- [x] Register rule in `all_rules.dart`
- [x] Add to tier in `tiers.dart`
- [ ] Update ROADMAP.md
- [x] Update CHANGELOG.md

**Rule:** `avoid_deprecated_on_surface_destroyed` in `lib/src/rules/config/migration_rules.dart`.

---

**Status:** Implemented
**Generated:** From Flutter SDK v3.29.0 release notes
