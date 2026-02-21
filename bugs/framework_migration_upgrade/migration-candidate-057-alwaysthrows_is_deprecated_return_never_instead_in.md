# Migration Candidate #057

**Source:** Flutter SDK 3.10.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** Never, Return

---

## Release Note Entry

> @alwaysThrows is deprecated. Return `Never` instead. by @eyebrowsoffire in [39269](https://github.com/flutter/engine/pull/39269)
>
> Context: * [macOS] Move A11yBridge to FVC by @dkwingsmt in [38855](https://github.com/flutter/engine/pull/38855)

**PR:** https://github.com/flutter/engine/pull/39269

## PR Details

**Title:** @alwaysThrows is deprecated. Return `Never` instead.
**Author:** @eyebrowsoffire
**Status:** merged
**Labels:** platform-web, needs tests, warning: land on red to fix tree breakage, autosubmit

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `Never`
- `Return`

---

## Proposed Lint Rule

**Rule Type:** `deprecation_migration`
**Estimated Difficulty:** medium

### Detection Strategy

Detect usage of the deprecated API via AST method/property invocation nodes

**Relevant AST nodes:**
- `MethodInvocation`
- `PropertyAccess`
- `PrefixedIdentifier`
- `SimpleIdentifier`

### Fix Strategy

Replace with the recommended alternative API

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
**Generated:** From Flutter SDK v3.10.0 release notes
