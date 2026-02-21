# Migration Candidate #048

**Source:** Flutter SDK 3.16.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** useMaterial3, ThemeData.copyWith(), Deprecate, ThemeData.copyWith, QuncCccccc

---

## Release Note Entry

> Deprecate `useMaterial3` parameter in `ThemeData.copyWith()` by @QuncCccccc in [131455](https://github.com/flutter/flutter/pull/131455)
>
> Context: * Update `BottomSheet.enableDrag` & `BottomSheet.showDragHandle` docs for animation controller by @TahaTesser in [131484](https://github.com/flutter/flutter/pull/131484)

**PR:** https://github.com/flutter/flutter/pull/131455

## PR Details

**Title:** Deprecate `useMaterial3` parameter in `ThemeData.copyWith()`
**Author:** @QuncCccccc
**Status:** merged
**Labels:** framework, f: material design, c: tech-debt

### Description

This PR is to deprecate `useMaterial3` parameter in `ThemeData.copyWith()`.

Setting `useMaterial3` to false in `ThemeData.copyWith()` doesn't force Flutter to use Material 2, instead, we should set it in `ThemeData()` directly. The documentation of `useMaterial3` has covered this limitation: https://api.flutter.dev/flutter/material/ThemeData/useMaterial3.html, but it still likely to be misused in the `.copyWith()` method.

A related issue happens in b/292560771

Related to #131041

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I listed at least one issue that this PR fixes in the description above.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I added new tests to check the change I am making, or this PR is [test-exempt].
- [x] All existing and new tests are passing.

If you need help, consider asking for advice on the #hackers-new channel on [Discord].

<!-- Links -->
[Contributor Guide]: https://github.com/flutter/flutter/wiki/Tree-hygiene#overview
[Tree Hygiene]: https://github.com/flutter/flutter/wiki/Tree-hygiene
[test-exempt]: https://github.com/flutter/flutter/wiki/Tree-hygiene#tests
[Flutter Style Guide]: https://githu

[... truncated]

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `useMaterial3`
- `ThemeData.copyWith()`
- `Deprecate`
- `ThemeData.copyWith`
- `QuncCccccc`

---

## Proposed Lint Rule

**Rule Type:** `deprecation_migration`
**Estimated Difficulty:** easy

### Detection Strategy

Detect usage of the deprecated API via AST method/property invocation nodes

**Relevant AST nodes:**
- `MethodInvocation`
- `PropertyAccess`
- `PrefixedIdentifier`
- `SimpleIdentifier`

### Fix Strategy

Replace with the recommended alternative API

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
**Generated:** From Flutter SDK v3.16.0 release notes
