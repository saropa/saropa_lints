# Plan #082

**Source:** Dart SDK 3.4.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** FileSystemDeleteEvent.isDirectory, Deprecates

---

## Release Note Entry

> - Deprecates `FileSystemDeleteEvent.isDirectory`, which always returns
>
> Context: `false`.

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `FileSystemDeleteEvent.isDirectory`
- `Deprecates`

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
- [ ] Write quick-fix replacement (deferred: removal is context-specific)
- [x] Create test fixture with bad/good examples
- [x] Add unit tests
- [x] Register rule in `all_rules.dart`
- [x] Add to tier in `tiers.dart`
- [ ] Update ROADMAP.md
- [x] Update CHANGELOG.md

**Rule:** `avoid_deprecated_file_system_delete_event_is_directory` in `lib/src/rules/config/dart_sdk_34_deprecation_rules.dart`.

---

**Status:** Implemented
**Generated:** From Dart SDK v3.4.0 release notes
