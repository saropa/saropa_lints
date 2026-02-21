# Migration Candidate #070

**Source:** Flutter SDK 3.7.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** double.isNaN, ... == double.nan, Use

---

## Release Note Entry

> Use `double.isNaN` instead of `... == double.nan` (which is always false) by @mkustermann in https://github.com/flutter/flutter/pull/115424
>
> Context: * InkResponse highlights can be updated by @bleroux in https://github.com/flutter/flutter/pull/115635

**PR:** https://github.com/flutter/flutter/pull/115424

## PR Details

**Title:** Use `double.isNaN` instead of `... == double.nan` (which is always false)
**Author:** @mkustermann
**Status:** merged
**Labels:** a: tests, framework, a: accessibility

### Description

This is needed after analyzer introduced a new warning in https://github.com/dart-lang/sdk/commit/254da6749515d03abb7b7e37f342b161e9c6fdac

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `double.isNaN`
- `... == double.nan`
- `Use`

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
**Generated:** From Flutter SDK v3.7.0 release notes
