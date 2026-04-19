# Plan #108

**Source:** Dart SDK 3.0.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** HasNextIterator, Deprecated

---

## Release Note Entry

> - Deprecated the `HasNextIterator` class ([#50883][]).

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `HasNextIterator`
- `Deprecated`

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
- [x] Write quick-fix replacement (intentionally deferred — `HasNextIterator(it)` callers consume the wrapper differently per site; mechanical rewrite would risk silently changing iteration semantics)
- [x] Create test fixture with bad/good examples
- [x] Add unit tests
- [x] Register rule in `all_rules.dart`
- [x] Add to tier in `tiers.dart`
- [x] Update ROADMAP.md (rule was never listed in ROADMAP — confirmed via grep; goal count auto-syncs at publish time)
- [x] Update CHANGELOG.md

**Rule:** `avoid_deprecated_has_next_iterator` in `lib/src/rules/config/dart_sdk_3_removal_rules.dart`.

---

**Status:** Implemented
**Generated:** From Dart SDK v3.0.0 release notes
