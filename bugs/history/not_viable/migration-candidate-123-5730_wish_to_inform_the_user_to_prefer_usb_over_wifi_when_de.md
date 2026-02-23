# Migration Candidate #123

**Source:** Dart-Code 122
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** is enhancement, in flutter, in debugging, relies on sdk changes, Wish, WiFi

---

## Release Note Entry

> > **#5730**: Wish to inform the user to prefer USB over WiFi when developing against an iOS 26 device `is enhancement` `in flutter` `in debugging` `relies on sdk changes`
>
> Context: > Related to https://github.com/flutter/flutter/issues/176206

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `is enhancement`
- `in flutter`
- `in debugging`
- `relies on sdk changes`
- `Wish`
- `WiFi`

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
