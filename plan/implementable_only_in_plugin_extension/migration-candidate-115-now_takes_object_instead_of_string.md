# Migration Candidate #115

**Source:** Dart SDK 3.0.0
**Category:** Replacement / Migration
**Relevance Score:** 6
**Detected APIs:** Object, String

---

## Release Note Entry

> now takes `Object` instead of `String`.

---

## Migration Analysis

### What Changed

Dart SDK 3.0 `dart:js_util` **changelog** (not a generic `Object`/`String` API): the signature of **`callMethod`** was aligned with other helpers so a parameter **now accepts `Object` instead of `String`**. Existing call sites that pass a `String` remain valid (`String` is an `Object`); there is no mechanical migration or deprecation to lint.

### APIs Involved

- `dart:js_util` `callMethod` (parameter type widened)

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

- [x] Verify the API change in Flutter/Dart SDK source
- [x] Determine minimum SDK version requirement — N/A for a dedicated lint (no required code change)
- [ ] Write detection logic (AST visitor) — **skipped** (no actionable pattern)
- [ ] Write quick-fix replacement
- [ ] Create test fixture with bad/good examples
- [ ] Add unit tests
- [ ] Register rule in `all_rules.dart`
- [ ] Add to tier in `tiers.dart`
- [ ] Update ROADMAP.md
- [ ] Update CHANGELOG.md

---

**Status:** No rule (API widening only; string arguments remain valid)
**Generated:** From Dart SDK v3.0.0 release notes
