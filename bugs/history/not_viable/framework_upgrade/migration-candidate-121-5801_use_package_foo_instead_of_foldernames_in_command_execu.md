# Migration Candidate #121

**Source:** Dart-Code 124
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** is enhancement, in commands, Use

---

## Release Note Entry

> > **#5801**: Use "package:foo" instead of foldernames in command execution `is enhancement` `in commands`
>
> Context: > Fixes https://github.com/Dart-Code/Dart-Code/issues/5789

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `is enhancement`
- `in commands`
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
**Generated:** From Dart-Code v124 release notes
