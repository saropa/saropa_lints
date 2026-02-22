# Migration Candidate #064

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
**Generated:** From Flutter SDK v3.7.0 release notes
