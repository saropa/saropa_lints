# Migration Candidate #028

**Source:** Flutter SDK 3.24.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** dart compile wasm, Use

---

## Release Note Entry

> Use --(no-)strip-wams instead of --(no-)-name-section in `dart compile wasm` by @mkustermann in [150180](https://github.com/flutter/flutter/pull/150180)
>
> Context: * Reland "Identify and re-throw our dependency checking errors in flutter.groovy" by @gmackall in [150128](https://github.com/flutter/flutter/pull/150128)

**PR:** https://github.com/flutter/flutter/pull/150180

## PR Details

**Title:** Use --(no-)strip-wams instead of --(no-)-name-section in `dart compile wasm`
**Author:** @mkustermann
**Status:** merged
**Labels:** tool, will affect goldens

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `dart compile wasm`
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
**Generated:** From Flutter SDK v3.24.0 release notes
