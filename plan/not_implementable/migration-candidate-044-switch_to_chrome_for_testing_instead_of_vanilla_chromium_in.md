# Migration Candidate #044

**Source:** Flutter SDK 3.19.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** Switch, Testing, Chromium

---

## Release Note Entry

> Switch to Chrome for Testing instead of vanilla Chromium. by @eyebrowsoffire in [136214](https://github.com/flutter/flutter/pull/136214)
>
> Context: * [Windows Arm64] Add the 'platform_channel_sample_test_windows' Devicelab test by @loic-sharma in [136401](https://github.com/flutter/flutter/pull/136401)

**PR:** https://github.com/flutter/flutter/pull/136214

## PR Details

**Title:** Switch to Chrome for Testing instead of vanilla Chromium.
**Author:** @eyebrowsoffire
**Status:** merged
**Labels:** autosubmit

### Description

This switches over to using Chrome for Testing instead of Chromium. This should ensure that we are consistently using an official and consistent build of Chrome on all platforms, rather than whatever we can get from the continuous builds archive, which can potentially put platforms out of sync with each other.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Switch`
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
