# Migration Candidate #026

**Source:** Flutter SDK 3.24.0
**Category:** Replacement / Migration
**Relevance Score:** 8
**Detected APIs:** Remote, Switch

---

## Release Note Entry

> Switch to relevant `Remote` constructors by @nate-thegrate in [146773](https://github.com/flutter/flutter/pull/146773)
>
> Context: * Create web tests suite & update utils by @sealesj in [146592](https://github.com/flutter/flutter/pull/146592)

**PR:** https://github.com/flutter/flutter/pull/146773

## PR Details

**Title:** Switch to relevant `Remote` constructors
**Author:** @nate-thegrate
**Status:** merged
**Labels:** autosubmit, refactor

### Description

[A previous PR](https://github.com/flutter/flutter/pull/144279) implemented `const` constructors in the `Remote` class, so I wanted to follow up and use those constructors in the appropriate places.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Remote`
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
