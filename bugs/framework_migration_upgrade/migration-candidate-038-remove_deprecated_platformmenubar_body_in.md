# Migration Candidate #038

**Source:** Flutter SDK 3.19.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** PlatformMenuBar.body, Remove

---

## Release Note Entry

> Remove deprecated `PlatformMenuBar.body` by @gspencergoog in [138509](https://github.com/flutter/flutter/pull/138509)
>
> Context: * Refactor to use Apple system fonts by @MitchellGoodwin in [137275](https://github.com/flutter/flutter/pull/137275)

**PR:** https://github.com/flutter/flutter/pull/138509

## PR Details

**Title:** Remove deprecated `PlatformMenuBar.body`
**Author:** @gspencergoog
**Status:** merged
**Labels:** framework, f: material design, f: cupertino, c: tech-debt, autosubmit

### Description

Part of https://github.com/flutter/flutter/issues/139243

## Description

This removes the `PlatformMenuBar.body` attribute and constructor parameter, since its deprecation period has elapsed.

## Tests
 - No tests were using the deprecated attribute, so no tests were removed.

#FlutterDeprecations

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `PlatformMenuBar.body`
- `Remove`

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
**Generated:** From Flutter SDK v3.19.0 release notes
