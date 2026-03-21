# Migration Candidate #114

**Source:** Dart SDK 3.0.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** maxUserTags, Use

---

## Release Note Entry

> Use [`maxUserTags`][] instead.
>
> Context: - Callbacks passed to `registerExtension` will be run in the zone from which

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `maxUserTags`
- `Use`

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

- [x] Verify the API change in Flutter/Dart SDK source (same as migration candidate #109)
- [x] Determine minimum SDK version requirement
- [x] Write detection logic (AST visitor)
- [x] Write quick-fix replacement
- [x] Create test fixture with bad/good examples
- [x] Add unit tests
- [x] Register rule in `all_rules.dart`
- [x] Add to tier in `tiers.dart`
- [ ] Update ROADMAP.md
- [x] Update CHANGELOG.md

**Rule:** `avoid_removed_max_user_tags_constant` (same implementation as #109).

---

**Status:** Implemented
**Generated:** From Dart SDK v3.0.0 release notes
