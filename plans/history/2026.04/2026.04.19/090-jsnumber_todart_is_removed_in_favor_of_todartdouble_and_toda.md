# Plan #090

**Source:** Dart SDK 3.2.0
**Category:** Breaking Change
**Relevance Score:** 8
**Detected APIs:** JSNumber.toDart, toDartDouble, toDartInt

---

## Release Note Entry

> `JSNumber.toDart` is removed in favor of `toDartDouble` and `toDartInt` to
>
> Context: make the type explicit. `Object.toJS` is also removed in favor of

---

## Migration Analysis

### What Changed

An API has been removed or its signature changed. Code using the old API will fail to compile.

### APIs Involved

- `JSNumber.toDart`
- `toDartDouble`
- `toDartInt`

---

## Proposed Lint Rule

**Rule Type:** `breaking_change_migration`
**Estimated Difficulty:** medium

### Detection Strategy

Detect usage of removed/changed API signatures

**Relevant AST nodes:**
- `MethodInvocation`
- `InstanceCreationExpression`

### Fix Strategy

Replace with the new API signature or pattern

---

## Implementation Checklist

- [x] Verify the API change in Flutter/Dart SDK source (JSNumber.toDart removed in Dart 3.2)
- [x] Determine minimum SDK version requirement (Dart 3.2+)
- [x] Write detection logic (AST visitor) — PropertyAccess + PrefixedIdentifier on JSNumber receivers
- [x] Write quick-fix replacement (intentionally deferred — choice between `toDartDouble` and `toDartInt` is a semantic decision the developer must make; correction message lists both options)
- [x] Create test fixture with bad/good examples (`example/lib/flutter_sdk_migration_rules_fixture.dart`)
- [x] Add unit tests (`test/flutter_sdk_migration_rules_test.dart`)
- [x] Register rule in `saropa_lints.dart` factories
- [x] Add to tier in `tiers.dart` (Recommended)
- [x] Update ROADMAP.md (rule was never listed in ROADMAP — confirmed via grep; `Goal: …` count auto-syncs at publish time)
- [x] Update CHANGELOG.md

**Rule:** `avoid_removed_js_number_to_dart` in
`lib/src/rules/config/flutter_sdk_migration_rules.dart`.

---

**Status:** Implemented
**Generated:** From Dart SDK v3.2.0 release notes
