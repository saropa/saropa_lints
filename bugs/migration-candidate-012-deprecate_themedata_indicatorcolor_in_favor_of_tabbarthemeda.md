# Migration Candidate #012

**Source:** Flutter SDK 3.32.0
**Category:** Deprecation
**Relevance Score:** 11
**Detected APIs:** ThemeData.indicatorColor, TabBarThemeData.indicatorColor, Deprecate, TahaTesser

---

## Release Note Entry

> Deprecate `ThemeData.indicatorColor` in favor of `TabBarThemeData.indicatorColor` by @TahaTesser in [160024](https://github.com/flutter/flutter/pull/160024)
>
> Context: * Fix incorrect [enabled] documentation by @sethmfuller in [161650](https://github.com/flutter/flutter/pull/161650)

**PR:** https://github.com/flutter/flutter/pull/160024

## PR Details

**Title:** Deprecate `ThemeData.indicatorColor` in favor of `TabBarThemeData.indicatorColor`
**Author:** @TahaTesser
**Status:** merged
**Labels:** framework, f: material design, c: tech-debt

### Description

Related to [☂️ Material Theme System Updates](https://github.com/flutter/flutter/issues/91772)

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I listed at least one issue that this PR fixes in the description above.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I added new tests to check the change I am making, or this PR is [test-exempt].
- [x] I followed the [breaking change policy] and added [Data Driven Fixes] where supported.
- [x] All existing and new tests are passing.

If you need help, consider asking for advice on the #hackers-new channel on [Discord].

<!-- Links -->
[Contributor Guide]: https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md#overview
[Tree Hygiene]: https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md
[test-exempt]: https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md#tests
[Flutter Style Guide]: https://github.com/flutter/flutter/blob/main/docs/contributing/Style-guide-for-Flutter-repo.md
[Features we expect every widget to implement]: https://github.com/flutter/flutter/blob/main/docs/contributing/Style-guide-for-Flutter-repo.md#

[... truncated]

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `ThemeData.indicatorColor`
- `TabBarThemeData.indicatorColor`
- `Deprecate`
- `TahaTesser`

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
**Generated:** From Flutter SDK v3.32.0 release notes
