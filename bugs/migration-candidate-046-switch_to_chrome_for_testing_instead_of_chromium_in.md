# Migration Candidate #046

**Source:** Flutter SDK 3.19.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** Switch, For, Testing, Chromium

---

## Release Note Entry

> Switch to Chrome For Testing instead of Chromium by @eyebrowsoffire in [46683](https://github.com/flutter/engine/pull/46683)
>
> Context: * [web] Stop using `flutterViewEmbedder` for platform views by @mdebbar in [46046](https://github.com/flutter/engine/pull/46046)

**PR:** https://github.com/flutter/engine/pull/46683

## PR Details

**Title:** Switch to Chrome For Testing instead of Chromium
**Author:** @eyebrowsoffire
**Status:** merged
**Labels:** platform-web, will affect goldens, autosubmit

### Description

This switches over to using Chrome for Testing instead of Chromium. This requires some changes from the recipes repo (https://flutter-review.googlesource.com/c/recipes/+/51482) in order to coordinate the change in filestructure on the mac versions.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Switch`
- `For`
- `Testing`
- `Chromium`

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
**Generated:** From Flutter SDK v3.19.0 release notes
