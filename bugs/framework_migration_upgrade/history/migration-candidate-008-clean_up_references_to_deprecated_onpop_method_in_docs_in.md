# Migration Candidate #008

**Source:** Flutter SDK 3.35.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** Clean

---

## Release Note Entry

> Clean up references to deprecated onPop method in docs by @justinmc in [169700](https://github.com/flutter/flutter/pull/169700)
>
> Context: * IOSSystemContextMenuItem.toString to Diagnosticable by @justinmc in [169705](https://github.com/flutter/flutter/pull/169705)

**PR:** https://github.com/flutter/flutter/pull/169700

## PR Details

**Title:** Clean up references to deprecated onPop method in docs
**Author:** @justinmc
**Status:** merged
**Labels:** framework, f: routes

### Description

onPop is deprecated but was mentioned in the docs. I've put its replacement onPopWithResult in its place. Also, there was one unterminated square bracket that I've fixed.

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `Clean`

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
**Generated:** From Flutter SDK v3.35.0 release notes
