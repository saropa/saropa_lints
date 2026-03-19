# Migration Candidate #126

**Source:** Dart-Code 100
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** dt, devtools_tool, is enhancement, in devtools, Switch

---

## Release Note Entry

> > **#5311**: Switch customDevTools to assume `dt` instead of `devtools_tool` `is enhancement` `in devtools`
>
> Context: > See https://github.com/flutter/devtools/pull/8410

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `dt`
- `devtools_tool`
- `is enhancement`
- `in devtools`
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
**Generated:** From Dart-Code v100 release notes
