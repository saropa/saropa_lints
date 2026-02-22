# Migration Candidate #049

**Source:** Flutter SDK 3.16.0
**Category:** New Feature / API
**Relevance Score:** 5
**Detected APIs:** ListView, New, Allowing

---

## Release Note Entry

> [New feature] Allowing the `ListView` slivers to have different extents while still having scrolling performance by @xu-baolin in [131393](https://github.com/flutter/flutter/pull/131393)
>
> Context: * Revert "Adds a parent scope TraversalEdgeBehavior and fixes modal rou… by @chunhtai in [134550](https://github.com/flutter/flutter/pull/134550)

**PR:** https://github.com/flutter/flutter/pull/131393

## PR Details

**Title:** [New feature] Allowing the `ListView` slivers to have different extents while still having scrolling performance
**Author:** @xu-baolin
**Status:** merged
**Labels:** c: new feature, framework, f: material design, f: scrolling, autosubmit

### Description

Fixes https://github.com/flutter/flutter/issues/113431

Currently we only support specifying all slivers to have the same extent.
This patch introduces an `itemExtentBuilder` property for `ListView`, allowing the slivers to have different extents while still having scrolling performance, especially when the scroll position changes drastically(such as scrolling by the scrollbar or controller.jumpTo()).

@Piinks Hi, Any thoughts about this?  :)

---

## Migration Analysis

### What Changed

A new API has been introduced that simplifies a common pattern. Users can benefit from adopting it.

### APIs Involved

- `ListView`
- `New`
- `Allowing`

---

## Proposed Lint Rule

**Rule Type:** `prefer_new_api`
**Estimated Difficulty:** medium

### Detection Strategy

Detect verbose/old pattern that could use the new API

**Relevant AST nodes:**
- `MethodInvocation`
- `ExpressionStatement`

### Fix Strategy

Suggest using the new, more concise API

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
**Generated:** From Flutter SDK v3.16.0 release notes
