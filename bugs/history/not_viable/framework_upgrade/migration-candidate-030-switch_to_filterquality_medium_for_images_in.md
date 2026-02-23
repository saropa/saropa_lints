# Migration Candidate #030

**Source:** Flutter SDK 3.24.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** Switch, FilterQuality.medium

---

## Release Note Entry

> Switch to FilterQuality.medium for images by @goderbauer in [148799](https://github.com/flutter/flutter/pull/148799)
>
> Context: * Fix InputDecorator default hint text style on M3 by @bleroux in [148944](https://github.com/flutter/flutter/pull/148944)

**PR:** https://github.com/flutter/flutter/pull/148799

## PR Details

**Title:** Switch to FilterQuality.medium for images
**Author:** @goderbauer
**Status:** merged
**Labels:** framework, f: material design, f: scrolling, will affect goldens, autosubmit

### Description

https://github.com/flutter/flutter/issues/148253

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Switch`
- `FilterQuality.medium`

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
