# Plan #064

**Source:** Flutter SDK 3.7.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** AnimatedListItemBuilder, AnimatedListRemovedItemBuilder, Deprecate

---

## Release Note Entry

> Deprecate `AnimatedListItemBuilder` and `AnimatedListRemovedItemBuilder` by @gspencergoog in https://github.com/flutter/flutter/pull/113131
>
> Context: * `AutomatedTestWidgetsFlutterBinding.pump` provides wrong pump time stamp, probably because of forgetting the precision by @fzyzcjy in https://github.com/flutter/flutter/pull/112609

**PR:** https://github.com/flutter/flutter/pull/113131

## PR Details

**Title:** Deprecate `AnimatedListItemBuilder` and `AnimatedListRemovedItemBuilder` 
**Author:** @gspencergoog
**Status:** merged
**Labels:** c: contributor-productivity, framework, f: scrolling, d: api docs, d: examples, autosubmit

### Description

## Description



Deprecate `AnimatedListItemBuilder` and `AnimatedListRemovedItemBuilder` in favor of `AnimatedItemBuilder` and `AnimatedRemovedItemBuilder`, since they have the same signature, and just need a new, more appropriate, name.



## Tests

 - No tests needed: just a refactor without a semantic difference.

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `AnimatedListItemBuilder`
- `AnimatedListRemovedItemBuilder`
- `Deprecate`

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
- [ ] Create test fixture with bad/good examples (requires Flutter SDK for type resolution)
- [x] Add unit tests
- [x] Register rule in `all_rules.dart`
- [x] Add to tier in `tiers.dart`
- [ ] Update ROADMAP.md
- [x] Update CHANGELOG.md

**Rule:** `avoid_deprecated_animated_list_typedefs` in `lib/src/rules/config/migration_rules.dart`.

---

**Status:** Implemented
**Generated:** From Flutter SDK v3.7.0 release notes
