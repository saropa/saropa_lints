# Migration Candidate #031

**Source:** Flutter SDK 3.24.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** Switch

---

## Release Note Entry

> Switch to more reliable flutter.dev link destinations in the tool by @parlough in [150587](https://github.com/flutter/flutter/pull/150587)
>
> Context: * [tool] when writing to openssl as a part of macOS/iOS code-signing, flush the stdin stream before closing it by @andrewkolos in [150120](https://github.com/flutter/flutter/pull/150120)

**PR:** https://github.com/flutter/flutter/pull/150587

## PR Details

**Title:** Switch to more reliable flutter.dev link destinations in the tool
**Author:** @parlough
**Status:** merged
**Labels:** platform-ios, tool, a: desktop, autosubmit

### Description

Contributes to https://github.com/flutter/website/issues/10363.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

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
**Generated:** From Flutter SDK v3.24.0 release notes
