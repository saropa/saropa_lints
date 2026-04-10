# Migration Candidate #033

**Source:** Flutter SDK 3.22.0
**Category:** Deprecation
**Relevance Score:** 7
**Detected APIs:** TextTheme, Remove, Renzo, Olivares

---

## Release Note Entry

> Remove deprecated `TextTheme` members by @Renzo-Olivares in [139255](https://github.com/flutter/flutter/pull/139255)
>
> Context: * Update `TabBar` and `TabBar.secondary` to use indicator height/color M3 tokens by @TahaTesser in [145753](https://github.com/flutter/flutter/pull/145753)

**PR:** https://github.com/flutter/flutter/pull/139255

## PR Details

**Title:** Remove deprecated `TextTheme` members
**Author:** @Renzo-Olivares
**Status:** merged
**Labels:** a: text input, framework, f: material design, d: api docs, d: examples, autosubmit

### Description

Part of: https://github.com/flutter/flutter/issues/143956

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I listed at least one issue that this PR fixes in the description above.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I added new tests to check the change I am making, or this PR is [test-exempt].
- [x] All existing and new tests are passing.

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `TextTheme`
- `Remove`
- `Renzo`
- `Olivares`

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
**Generated:** From Flutter SDK v3.22.0 release notes
