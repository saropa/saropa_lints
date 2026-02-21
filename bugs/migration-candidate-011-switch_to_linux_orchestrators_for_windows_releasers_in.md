# Migration Candidate #011

**Source:** Flutter SDK 3.35.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** Switch

---

## Release Note Entry

> Switch to Linux orchestrators for Windows releasers. by @matanlurey in [168941](https://github.com/flutter/flutter/pull/168941)
>
> Context: * Revert "fix: update experiment to use different setup (#169728)" and "feat: experimental workflow for Linux tool-tests-general (#169706)" by @jason-simmons in [169770](https://github.com/flutter/flutter/pull/169770)

**PR:** https://github.com/flutter/flutter/pull/168941

## PR Details

**Title:** Switch to Linux orchestrators for Windows releasers.
**Author:** @matanlurey
**Status:** merged
**Labels:** engine

### Description

Towards https://github.com/flutter/flutter/issues/168934.

/cc @reidbaker as release engineer

/cc @zanderso (we talked about this offline)

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Switch`

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
**Generated:** From Flutter SDK v3.35.0 release notes
