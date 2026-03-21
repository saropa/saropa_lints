# Migration Candidate #113

**Source:** Dart SDK 3.0.0
**Category:** Replacement / Migration
**Relevance Score:** 10
**Detected APIs:** TypeError, Use

---

## Release Note Entry

> Use [`TypeError`][] instead.
>
> Context: - Removed the deprecated [`FallThroughError`][] error. The kind of

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `TypeError`
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

- [x] Verify the API change in Flutter/Dart SDK source (release note: use `TypeError` for **CastError** removal; `FallThroughError` is a separate removal — compile-time error in Dart 2.0+)
- [x] Determine minimum SDK version requirement
- [x] Write detection logic (AST visitor)
- [x] Write quick-fix replacement (`CastError` → `TypeError`)
- [x] Create test fixture with bad/good examples
- [x] Add unit tests
- [x] Register rule in `all_rules.dart`
- [x] Add to tier in `tiers.dart`
- [ ] Update ROADMAP.md
- [x] Update CHANGELOG.md

**CastError → TypeError:** `avoid_removed_cast_error` in `lib/src/rules/config/dart_sdk_3_removal_rules.dart`.

**FallThroughError:** `avoid_removed_fall_through_error` (no `TypeError` substitution; remove dead references).

---

**Status:** Implemented (pre-existing rules)
**Generated:** From Dart SDK v3.0.0 release notes
