# Migration Candidate #061

**Source:** Flutter SDK 3.10.0
**Category:** Replacement / Migration
**Relevance Score:** 6
**Detected APIs:** ThemeData.visualDensity, ThemeData.platform, defaultTargetPlatform, Initialize

---

## Release Note Entry

> Initialize `ThemeData.visualDensity` using `ThemeData.platform` instead of `defaultTargetPlatform` by @gspencergoog in [124357](https://github.com/flutter/flutter/pull/124357)
>
> Context: * Revert "Refactor reorderable list semantics" by @XilaiZhang in [124368](https://github.com/flutter/flutter/pull/124368)

**PR:** https://github.com/flutter/flutter/pull/124357

## PR Details

**Title:** Initialize `ThemeData.visualDensity` using `ThemeData.platform` instead of `defaultTargetPlatform`
**Author:** @gspencergoog
**Status:** merged
**Labels:** framework, f: material design, autosubmit

### Description

## Description

This changes the initialization of `ThemeData.visualDensity` to use the `ThemeData`'s `platform` instead of always using `defaultTargetPlatform`.  Before this change, setting the platform on the `ThemeData` had an effect on all the platform-dependent properties _except_ for `visualDensity`.

## Related Issues
 - https://github.com/flutter/flutter/issues/123773

## Tests
 - Added tests for the new static `defaultDensityForPlatform` and verified that the theme data uses the passed-in platform.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `ThemeData.visualDensity`
- `ThemeData.platform`
- `defaultTargetPlatform`
- `Initialize`

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
**Generated:** From Flutter SDK v3.10.0 release notes
