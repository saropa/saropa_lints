# Migration Candidate #125

**Source:** Dart-Code 104
**Category:** Replacement / Migration
**Relevance Score:** 6
**Detected APIs:** dart.getFlutterSdkCommand, dart.getDartSdkCommand, mise, asdf, PATH, package.json, Code, This

---

## Release Note Entry

> [#5334](https://github.com/Dart-Code/Dart-Code/issues/5334)/[#5377](https://github.com/Dart-Code/Dart-Code/issues/5377)/[#5117](https://github.com/Dart-Code/Dart-Code/issues/5117): [@davidmartos96](https://github.com/davidmartos96) contributed new settings `dart.getFlutterSdkCommand` and `dart.getDartSdkCommand` that allow executing a command to locate the Dart/Flutter SDKs to use for a workspace. This improves compatibility with some SDK version managers (such as `mise` and `asdf`) because they can be queried for the current SDK instead of reading from `PATH` (or `package.json`).

**PR:** https://github.com/Dart-Code/Dart-Code/issues/5334

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `dart.getFlutterSdkCommand`
- `dart.getDartSdkCommand`
- `mise`
- `asdf`
- `PATH`
- `package.json`
- `Code`
- `This`

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
**Generated:** From Dart-Code v104 release notes
