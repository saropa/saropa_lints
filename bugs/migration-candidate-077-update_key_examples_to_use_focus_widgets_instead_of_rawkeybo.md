# Migration Candidate #077

**Source:** Flutter SDK 3.3.0
**Category:** Replacement / Migration
**Relevance Score:** 6
**Detected APIs:** Focus, RawKeyboardListener, Update

---

## Release Note Entry

> Update key examples to use `Focus` widgets instead of `RawKeyboardListener` by @gspencergoog in https://github.com/flutter/flutter/pull/101537
>
> Context: * Enable unnecessary_import by @goderbauer in https://github.com/flutter/flutter/pull/101600

**PR:** https://github.com/flutter/flutter/pull/101537

## PR Details

**Title:** Update key examples to use `Focus` widgets instead of `RawKeyboardListener`
**Author:** @gspencergoog
**Status:** merged
**Labels:** c: contributor-productivity, framework, d: api docs, d: examples

### Description

## Description

This updates the examples for `PhysicalKeyboardKey` and `LogicalKeyboardKey` to use `Focus` widgets that handle the keys instead of using `RawKeyboardListener`, since that usually leads people down the wrong path. Updated the See Also and added tests as well.

## Related Issues
 - https://github.com/flutter/flutter/issues/74287

## Tests
 - Added tests for the examples.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Focus`
- `RawKeyboardListener`
- `Update`

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
**Generated:** From Flutter SDK v3.3.0 release notes
