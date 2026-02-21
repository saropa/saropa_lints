# Migration Candidate #003

**Source:** Flutter SDK 3.38.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** AssetManifest.json, Remove

---

## Release Note Entry

> Remove deprecated `AssetManifest.json` file by @matanlurey in [172594](https://github.com/flutter/flutter/pull/172594)
>
> Context: * fix(scrollbar): Update padding type to EdgeInsetsGeometry by @SalehTZ in [172056](https://github.com/flutter/flutter/pull/172056)

**PR:** https://github.com/flutter/flutter/pull/172594

## PR Details

**Title:** Remove deprecated `AssetManifest.json` file
**Author:** @matanlurey
**Status:** merged
**Labels:** a: tests, tool, framework, team-android, team-ios

### Description

Closes https://github.com/flutter/flutter/issues/143577.

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `AssetManifest.json`
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
**Generated:** From Flutter SDK v3.38.0 release notes
