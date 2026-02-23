# Migration Candidate #129

**Source:** Dart-Code v3-84
**Category:** Replacement / Migration
**Relevance Score:** 6
**Detected APIs:** Enum.values, Enum, List<Enum>, Code, The, List

---

## Release Note Entry

> [#4877](https://github.com/Dart-Code/Dart-Code/issues/4877): The hover for `Enum.values` no longer incorrectly reports the type as `Enum` instead of `List<Enum>`.

**PR:** https://github.com/Dart-Code/Dart-Code/issues/4877

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Enum.values`
- `Enum`
- `List<Enum>`
- `Code`
- `The`
- `List`

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
**Generated:** From Dart-Code vv3-84 release notes
