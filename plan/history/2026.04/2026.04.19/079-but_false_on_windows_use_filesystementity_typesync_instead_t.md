# Plan #079

**Source:** Dart SDK 3.11.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** false, FileSystemEntity.typeSync(), Use, FileSystemEntity.typeSync

---

## Release Note Entry

> but `false` on Windows. Use `FileSystemEntity.typeSync()` instead to get
>
> Context: portable behavior.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `false`
- `FileSystemEntity.typeSync()`
- `Use`
- `FileSystemEntity.typeSync`

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

- [x] Verify the API change in Flutter/Dart SDK source (documented dart:io behavior: isLinkSync returns false on Windows)
- [x] Determine minimum SDK version requirement (all modern Dart SDKs — isLinkSync behavior has been constant)
- [x] Write detection logic (AST visitor) — MethodInvocation on FileSystemEntity
- [x] Write quick-fix replacement (intentionally deferred — rewrite from `bool` to type-comparison expression can break surrounding negation/parens; correction message guides the developer manually)
- [x] Create test fixture with bad/good examples (`example/lib/flutter_sdk_migration_rules_fixture.dart`)
- [x] Add unit tests (`test/flutter_sdk_migration_rules_test.dart`)
- [x] Register rule in `saropa_lints.dart` factories
- [x] Add to tier in `tiers.dart` (Recommended)
- [x] Update ROADMAP.md (rule was never listed in ROADMAP — confirmed via grep; `Goal: …` count auto-syncs at publish time)
- [x] Update CHANGELOG.md

**Rule:** `prefer_type_sync_over_is_link_sync` in
`lib/src/rules/config/flutter_sdk_migration_rules.dart`.

---

**Status:** Implemented
**Generated:** From Dart SDK v3.11.0 release notes
