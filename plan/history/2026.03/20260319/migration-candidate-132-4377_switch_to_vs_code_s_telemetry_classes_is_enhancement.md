# Migration Candidate #132

**Source:** Dart-Code v3-62
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** is enhancement, Switch, Code

---

## Release Note Entry

> > **#4377**: Switch to VS Code's telemetry classes `is enhancement`
>
> Context: > https://code.visualstudio.com/updates/v1_75#_telemetry

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `is enhancement`
- `Switch`
- `Code`

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
**Generated:** From Dart-Code vv3-62 release notes
