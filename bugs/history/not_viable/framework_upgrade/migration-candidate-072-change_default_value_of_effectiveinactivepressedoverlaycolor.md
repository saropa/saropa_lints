# Migration Candidate #072

**Source:** Flutter SDK 3.7.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** effectiveInactivePressedOverlayColor, effectiveInactiveThumbColor, Change, Switch, QuncCccccc

---

## Release Note Entry

> Change default value of `effectiveInactivePressedOverlayColor` in Switch to refer to `effectiveInactiveThumbColor` by @QuncCccccc in https://github.com/flutter/flutter/pull/108477
>
> Context: * Guard against usage after async callbacks in RenderAndroidView, unregister listener by @dnfield in https://github.com/flutter/flutter/pull/108496

**PR:** https://github.com/flutter/flutter/pull/108477

## PR Details

**Title:** Change default value of `effectiveInactivePressedOverlayColor` in Switch to refer to `effectiveInactiveThumbColor`
**Author:** @QuncCccccc
**Status:** merged
**Labels:** framework, f: material design

### Description

The default value of `effectiveInactivePressedOverlayColor` was determined by `effectiveActiveThumbColor` which supposed to be `effectiveInactiveThumbColor`.

This PR fixes the typo.

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I listed at least one issue that this PR fixes in the description above.
- [ ] I updated/added relevant documentation (doc comments with `///`).
- [x] I added new tests to check the change I am making, or this PR is [test-exempt].
- [x] All existing and new tests are passing.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `effectiveInactivePressedOverlayColor`
- `effectiveInactiveThumbColor`
- `Change`
- `Switch`
- `QuncCccccc`

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
