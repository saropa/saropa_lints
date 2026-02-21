# Migration Candidate #128

**Source:** Dart-Code v3-96
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** is enhancement, in flutter sidebar, Switch

---

## Release Note Entry

> > **#5225**: Switch to the DTD sidebar when using a new enough SDK `is enhancement` `in flutter sidebar`
>
> Context: > - DevTools work done in https://github.com/flutter/devtools/commit/faeb2a3e0d49a01301ed85dd9bba989a88b4b762

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `is enhancement`
- `in flutter sidebar`
- `Switch`

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
**Generated:** From Dart-Code vv3-96 release notes
