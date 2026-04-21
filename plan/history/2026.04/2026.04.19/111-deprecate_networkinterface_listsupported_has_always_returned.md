# Plan #111

**Source:** Dart SDK 3.0.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** NetworkInterface.listSupported, Deprecate, Has

---

## Release Note Entry

> - Deprecate `NetworkInterface.listSupported`. Has always returned true since
>
> Context: Dart 2.3.

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `NetworkInterface.listSupported`
- `Deprecate`
- `Has`

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
- [x] Write quick-fix replacement (intentionally deferred — callers vary between sync `if` checks and `await` expressions, so a single textual replacement (`true` vs `Future.value(true)`) cannot be chosen safely; correction message lists both)
- [x] Create test fixture with bad/good examples
- [x] Add unit tests
- [x] Register rule in `all_rules.dart`
- [x] Add to tier in `tiers.dart`
- [x] Update ROADMAP.md (rule was never listed in ROADMAP — confirmed via grep; goal count auto-syncs at publish time)
- [x] Update CHANGELOG.md

**Rule:** `avoid_deprecated_network_interface_list_supported` in `lib/src/rules/config/dart_sdk_3_removal_rules.dart`.

---

**Status:** Implemented
**Generated:** From Dart SDK v3.0.0 release notes
