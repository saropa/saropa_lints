# Migration Candidate #056

**Source:** Flutter SDK 3.10.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** TestWindow, Deprecates

---

## Release Note Entry

> Deprecates `TestWindow` by @pdblasi-google in [122824](https://github.com/flutter/flutter/pull/122824)
>
> Context: * Bump lower Dart SDK constraints to 3.0 & add class modifiers by @goderbauer in [122546](https://github.com/flutter/flutter/pull/122546)

**PR:** https://github.com/flutter/flutter/pull/122824

## PR Details

**Title:** Deprecates `TestWindow`
**Author:** @pdblasi-google
**Status:** merged
**Labels:** a: tests, framework, autosubmit

### Description

Deprecates `TestWindow`

* Adds `Deprecated` annotations to `TestWindow` and its constructors.
* Adds `Deprecated` annotations to all properties and methods on `TestWindow` except `noSuchMethod`.
* Adds `Deprecated` annotation to `TestWidgetsFlutterBinding.window`.
* Adds `flutter_test` specific deprecation documentation to `TestWidgetsFlutterBinding.window`.

Resolves #121915.

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

- `TestWindow`
- `Deprecates`

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
