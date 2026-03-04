# Migration Candidate #024

**Source:** Flutter SDK 3.24.0
**Category:** Replacement / Migration
**Relevance Score:** 8
**Detected APIs:** Iterable.cast, Switch

---

## Release Note Entry

> Switch to `Iterable.cast` instance method by @parlough in [150185](https://github.com/flutter/flutter/pull/150185)
>
> Context: * Add tests for navigator.0.dart by @ValentinVignal in [150034](https://github.com/flutter/flutter/pull/150034)

**PR:** https://github.com/flutter/flutter/pull/150185

## PR Details

**Title:** Switch to `Iterable.cast` instance method
**Author:** @parlough
**Status:** merged
**Labels:** a: tests, framework, f: scrolling, will affect goldens, autosubmit

### Description

Switch away from the `Iterable.castFrom` static method to the `Iterable.cast` instance method which is more readable and more consistent with other iterable usages.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Iterable.cast`
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
**Generated:** From Flutter SDK v3.24.0 release notes
