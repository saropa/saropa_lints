# Migration Candidate #112

**Source:** Dart SDK 3.0.0
**Category:** Replacement / Migration
**Relevance Score:** 10
**Detected APIs:** Deprecated.message, Use

---

## Release Note Entry

> Use [`Deprecated.message`][] instead.
>
> Context: - Removed the deprecated [`CastError`][] error.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Deprecated.message`
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

- [x] Verify the API change in Flutter/Dart SDK source (release note pairs `Deprecated.expires` removal with `Deprecated.message`)
- [x] Determine minimum SDK version requirement
- [x] Write detection logic (AST visitor)
- [x] Write quick-fix replacement
- [x] Create test fixture with bad/good examples
- [x] Add unit tests
- [x] Register rule in `all_rules.dart`
- [x] Add to tier in `tiers.dart`
- [ ] Update ROADMAP.md
- [x] Update CHANGELOG.md

**Already implemented:** `avoid_deprecated_expires_getter` in `lib/src/rules/config/dart_sdk_3_removal_rules.dart` (replaces `.expires` with `.message` on `Deprecated`).

---

**Status:** Implemented (pre-existing rule)
**Generated:** From Dart SDK v3.0.0 release notes
