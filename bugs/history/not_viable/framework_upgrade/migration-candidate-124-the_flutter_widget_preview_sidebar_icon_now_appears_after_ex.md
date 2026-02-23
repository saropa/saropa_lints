# Migration Candidate #124

**Source:** Dart-Code 122
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** Code, The, Widget, Preview

---

## Release Note Entry

> [#5744](https://github.com/Dart-Code/Dart-Code/issues/5744): The Flutter Widget Preview sidebar icon now appears after extension activation instead of only after the widget preview server initializes.

**PR:** https://github.com/Dart-Code/Dart-Code/issues/5744

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Code`
- `The`
- `Widget`
- `Preview`

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
**Generated:** From Dart-Code v122 release notes
