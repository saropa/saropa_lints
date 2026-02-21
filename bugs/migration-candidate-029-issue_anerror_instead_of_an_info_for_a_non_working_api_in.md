# Migration Candidate #029

**Source:** Flutter SDK 3.24.0
**Category:** Replacement / Migration
**Relevance Score:** 6
**Detected APIs:** ERROR, INFO, Issue

---

## Release Note Entry

> Issue an`ERROR` instead of an `INFO` for a non-working API. by @matanlurey in [52892](https://github.com/flutter/engine/pull/52892)
>
> Context: * Fix another instance of platform view breakage on Android 14 by @johnmccutchan in [52980](https://github.com/flutter/engine/pull/52980)

**PR:** https://github.com/flutter/engine/pull/52892

## PR Details

**Title:** Issue an`ERROR` instead of an `INFO` for a non-working API.
**Author:** @matanlurey
**Status:** merged
**Labels:** platform-android

### Description

Work toward https://github.com/flutter/flutter/issues/139702.

I think we should also `@Deprecate`/cleanup the API surface in `FlutterView`, but that needs a bit more a discussion.

/cc @johnmccutchan

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `ERROR`
- `INFO`
- `Issue`

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
