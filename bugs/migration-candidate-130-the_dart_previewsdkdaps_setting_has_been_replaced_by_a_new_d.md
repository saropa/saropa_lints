# Migration Candidate #130

**Source:** Dart-Code v3-82
**Category:** New Parameter / Option
**Relevance Score:** 6
**Detected APIs:** dart.previewSdkDaps, dart.useLegacyDebugAdapters, true, false, Code, The

---

## Release Note Entry

> [#4966](https://github.com/Dart-Code/Dart-Code/issues/4966): The `dart.previewSdkDaps` setting has been replaced by a new `dart.useLegacyDebugAdapters`. The new setting has the opposite meaning (`true` means to use the legacy adapters, whereas for the old setting that was `false`).

**PR:** https://github.com/Dart-Code/Dart-Code/issues/4966

---

## Migration Analysis

### What Changed

A new parameter has been added that provides better behavior or additional control.

### APIs Involved

- `dart.previewSdkDaps`
- `dart.useLegacyDebugAdapters`
- `true`
- `false`
- `Code`
- `The`

---

## Proposed Lint Rule

**Rule Type:** `prefer_new_parameter`
**Estimated Difficulty:** medium

### Detection Strategy

Detect API calls missing the new parameter

**Relevant AST nodes:**
- `MethodInvocation`
- `InstanceCreationExpression`
- `ArgumentList`

### Fix Strategy

Suggest adding the new parameter for better behavior

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
**Generated:** From Dart-Code vv3-82 release notes
