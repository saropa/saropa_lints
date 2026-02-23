# Migration Candidate #133

**Source:** Dart-Code v3-60
**Category:** New Parameter / Option
**Relevance Score:** 5
**Detected APIs:** "dart.addSdkToTerminalPath", PATH, dart, flutter, Code, This

---

## Release Note Entry

> [#737](https://github.com/Dart-Code/Dart-Code/issues/737): A new setting `"dart.addSdkToTerminalPath"` enables automatically adding your current SDK to the `PATH` environment variable for built-in terminals. This works with quick SDK switching and ensures running `dart` or `flutter` from the terminal matches the version being used for analysis and debugging. To avoid losing terminal state, VS Code may require you to click an icon in existing terminal windows to restart them for this change to apply (this is not required for new terminals). This setting is opt-in today, but may become the default in a future release.

**PR:** https://github.com/Dart-Code/Dart-Code/issues/737

---

## Migration Analysis

### What Changed

A new parameter has been added that provides better behavior or additional control.

### APIs Involved

- `"dart.addSdkToTerminalPath"`
- `PATH`
- `dart`
- `flutter`
- `Code`
- `This`

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
**Generated:** From Dart-Code vv3-60 release notes
