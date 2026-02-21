# Migration Candidate #019

**Source:** Flutter SDK 3.29.0
**Category:** Replacement / Migration
**Relevance Score:** 6
**Detected APIs:** NativeAssetsManifest.json, Create

---

## Release Note Entry

> [native assets] Create `NativeAssetsManifest.json` instead of kernel embedding by @dcharkes in 159322
>
> Context: * [tool] Removes deprecated --web-renderer parameter. by @ditman in 159314

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `NativeAssetsManifest.json`
- `Create`

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
**Generated:** From Flutter SDK v3.29.0 release notes
