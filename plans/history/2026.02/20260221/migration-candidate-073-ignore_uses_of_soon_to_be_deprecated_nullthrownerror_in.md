# Migration Candidate #073

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
**Generated:** From Flutter SDK v3.3.0 release notes
