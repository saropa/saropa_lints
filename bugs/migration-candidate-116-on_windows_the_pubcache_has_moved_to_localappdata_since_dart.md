# Migration Candidate #116

**Source:** Dart SDK 3.0.0
**Category:** Replacement / Migration
**Relevance Score:** 6
**Detected APIs:** PUB_CACHE, %LOCALAPPDATA%

---

## Release Note Entry

> - On Windows the `PUB_CACHE` has moved to `%LOCALAPPDATA%`, since Dart 2.8 the
>
> Context: `PUB_CACHE` has been created in `%LOCALAPPDATA%` when one wasn't present.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `PUB_CACHE`
- `%LOCALAPPDATA%`

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
**Generated:** From Dart SDK v3.0.0 release notes
