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
