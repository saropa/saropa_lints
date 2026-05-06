# Migration Candidate #014

**Source:** Flutter SDK 3.32.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** flutter_tools, fail, throw StateError, Make, Use, StateError

---

## Release Note Entry

> Make developing `flutter_tools` nicer: Use `fail` instead of `throw StateError`. by @matanlurey in [163094](https://github.com/flutter/flutter/pull/163094)
>
> Context: * explicitly set packageConfigPath for strategy providers by @jyameo in [163080](https://github.com/flutter/flutter/pull/163080)

**PR:** https://github.com/flutter/flutter/pull/163094

## PR Details

**Title:** Make developing `flutter_tools` nicer: Use `fail` instead of `throw StateError`.
**Author:** @matanlurey
**Status:** merged
**Labels:** tool

### Description

Closes https://github.com/flutter/flutter/issues/163091.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `flutter_tools`
- `fail`
- `throw StateError`
- `Make`
- `Use`
- `StateError`

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
**Generated:** From Flutter SDK v3.32.0 release notes
