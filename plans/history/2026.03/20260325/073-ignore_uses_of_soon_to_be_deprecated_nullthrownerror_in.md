# Plan #073

**Source:** Flutter SDK 3.3.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** NullThrownError, Ignore

---

## Release Note Entry

> Ignore uses of soon-to-be deprecated `NullThrownError`. by @lrhn in https://github.com/flutter/flutter/pull/105693
>
> Context: * Fix `StretchingOverscrollIndicator` clipping and add `clipBehavior` parameter by @TahaTesser in https://github.com/flutter/flutter/pull/105303

**PR:** https://github.com/flutter/flutter/pull/105693

## PR Details

**Title:** Ignore uses of soon-to-be deprecated `NullThrownError`.
**Author:** @lrhn
**Status:** merged
**Labels:** c: contributor-productivity, framework, c: tech-debt, autosubmit

### Description

The `NullThrownError` is not used in null safe Dart,

and is planned to go away when pre-null-safety code stops being supported.

The error class will soon be deprecated.



The deprecation recommends using `TypeError` instead, because that is what should be thrown in null-safe code if you do `throw (null as dynamic)`, because `null` cannot be down-cast from `dynamic` to `Object`.

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `NullThrownError`
- `Ignore`

---

## Proposed Lint Rule

**Rule Type:** `deprecation_migration`
**Estimated Difficulty:** medium

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

- [x] Verify the API change in Flutter/Dart SDK source
- [x] Determine minimum SDK version requirement
- [x] Write detection logic (AST visitor)
- [x] Write quick-fix replacement
- [x] Create test fixture with bad/good examples
- [x] Add unit tests
- [x] Register rule in `all_rules.dart`
- [x] Add to tier in `tiers.dart`
- [ ] Update ROADMAP.md
- [x] Update CHANGELOG.md

**Rule:** `avoid_removed_null_thrown_error` in `lib/src/rules/config/dart_sdk_3_removal_rules.dart`.

---

**Status:** Implemented
**Generated:** From Flutter SDK v3.3.0 release notes
