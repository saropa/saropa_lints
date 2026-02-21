# Migration Candidate #119

**Source:** Dart-Code 128
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** flutterRoot, flutter, .package_config.json, is enhancement, Use

---

## Release Note Entry

> > **#5728**: Use `flutterRoot` instead of looking for the `flutter` package when reading the sdk path from `.package_config.json` `is enhancement`
>
> Context: > **Is your feature request related to a problem? Please describe.**

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `flutterRoot`
- `flutter`
- `.package_config.json`
- `is enhancement`
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
**Generated:** From Dart-Code v128 release notes
