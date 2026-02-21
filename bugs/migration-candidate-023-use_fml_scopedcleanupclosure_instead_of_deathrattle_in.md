# Migration Candidate #023

**Source:** Flutter SDK 3.24.0
**Category:** Replacement / Migration
**Relevance Score:** 10
**Detected APIs:** fml::ScopedCleanupClosure, DeathRattle, Use, ScopedCleanupClosure

---

## Release Note Entry

> Use `fml::ScopedCleanupClosure` instead of `DeathRattle`. by @matanlurey in [51834](https://github.com/flutter/engine/pull/51834)
>
> Context: * Return an empty optional in HardwareBuffer::GetSystemUniqueID if the underlying NDK API is unavailable by @jason-simmons in [51839](https://github.com/flutter/engine/pull/51839)

**PR:** https://github.com/flutter/engine/pull/51834

## PR Details

**Title:** Use `fml::ScopedCleanupClosure` instead of `DeathRattle`.
**Author:** @matanlurey
**Status:** merged
**Labels:** e: impeller, autosubmit

### Description

Closes https://github.com/flutter/flutter/issues/146105.

Originally when we authored these suites, `ScopedCleanupClosure` disallowed move-semantics, but that was fixed in https://github.com/flutter/engine/pull/45772, so there is no reason to have a copy of these in different tests.

/cc @jonahwilliams

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `fml::ScopedCleanupClosure`
- `DeathRattle`
- `Use`
- `ScopedCleanupClosure`

---

## Proposed Lint Rule

**Rule Type:** `prefer_replacement`
**Estimated Difficulty:** medium

### Detection Strategy

Detect old pattern and suggest the replacement

**Relevant AST nodes:**
- `MethodInvocation`
- `PropertyAccess`
- `SimpleIdentifier`

### Fix Strategy

Replace old API/pattern with the new recommended approach

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
**Generated:** From Flutter SDK v3.24.0 release notes
