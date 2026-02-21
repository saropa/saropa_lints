# Migration Candidate #058

**Source:** Flutter SDK 3.10.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** Use, String.codeUnitAt, String.codeUnits, ParagraphBoundary, Renzo, Olivares

---

## Release Note Entry

> Use String.codeUnitAt instead of String.codeUnits[] in ParagraphBoundary by @Renzo-Olivares in [120234](https://github.com/flutter/flutter/pull/120234)
>
> Context: * Fix lerping for `NavigationRailThemeData` icon themes by @guidezpl in [120066](https://github.com/flutter/flutter/pull/120066)

**PR:** https://github.com/flutter/flutter/pull/120234

## PR Details

**Title:** Use String.codeUnitAt instead of String.codeUnits[] in ParagraphBoundary
**Author:** @Renzo-Olivares
**Status:** merged
**Labels:** a: text input, framework, autosubmit

### Description

This change changes `ParagraphBoundary` uses of `String.codeUnits[index]` to `String.codeUnitAt(index)` to avoid creating a new list when using the `.codeUnits` getter.

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I listed at least one issue that this PR fixes in the description above.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I added new tests to check the change I am making, or this PR is [test-exempt].
- [x] All existing and new tests are passing.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Use`
- `String.codeUnitAt`
- `String.codeUnits`
- `ParagraphBoundary`
- `Renzo`
- `Olivares`

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
