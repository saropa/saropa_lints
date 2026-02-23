# Migration Candidate #002

**Source:** Flutter SDK 3.41.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** Fix, Drawer.child, ListView, SliverList

---

## Release Note Entry

> Fix Drawer.child docstring to say ListView instead of SliverList by @nathannewyen in [180326](https://github.com/flutter/flutter/pull/180326)
>
> Context: * Raw tooltip with smaller API surface that exposes tooltip widget by @victorsanni in [177678](https://github.com/flutter/flutter/pull/177678)

**PR:** https://github.com/flutter/flutter/pull/180326

## PR Details

**Title:** Fix Drawer.child docstring to say ListView instead of SliverList
**Author:** @nathannewyen
**Status:** merged
**Labels:** framework, f: material design

### Description

## Description

The docstring says "Typically a [SliverList]" but the class example uses `ListView`. 

`SliverList` is used inside `CustomScrollView`, not as a direct child of `Drawer`.

## Related Issue

Fixes #100268

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Fix`
- `Drawer.child`
- `ListView`
- `SliverList`

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
**Generated:** From Flutter SDK v3.41.0 release notes
