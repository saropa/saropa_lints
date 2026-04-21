# Plan #055

**Source:** Flutter SDK 3.10.0
**Category:** Deprecation
**Relevance Score:** 7
**Detected APIs:** AppBar.color, AppBar.backwardsCompatibility, Remove, LongCatIsLooong

---

## Release Note Entry

> Remove deprecated `AppBar.color` & `AppBar.backwardsCompatibility` by @LongCatIsLooong in [120618](https://github.com/flutter/flutter/pull/120618)
>
> Context: * Revert "Fix error when resetting configurations in tear down phase" by @loic-sharma in [120739](https://github.com/flutter/flutter/pull/120739)

**PR:** https://github.com/flutter/flutter/pull/120618

## PR Details

**Title:** Remove deprecated `AppBar.color` & `AppBar.backwardsCompatibility`
**Author:** @LongCatIsLooong
**Status:** merged
**Labels:** framework, f: material design, autosubmit

### Description

Deprecated in #86198



## Pre-launch Checklist



- [ ] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.

- [ ] I read the [Tree Hygiene] wiki page, which explains my responsibilities.

- [ ] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].

- [ ] I signed the [CLA].

- [ ] I listed at least one issue that this PR fixes in the description above.

- [ ] I updated/added relevant documentation (doc comments with `///`).

- [ ] I added new tests to check the change I am making, or this PR is [test-exempt].

- [ ] All existing and new tests are passing.



If you need help, consider asking for advice on the #hackers-new channel on [Discord].



<!-- Links -->

[Contributor Guide]: https://github.com/flutter/flutter/wiki/Tree-hygiene#overview

[Tree Hygiene]: https://github.com/flutter/flutter/wiki/Tree-hygiene

[test-exempt]: https://github.com/flutter/flutter/wiki/Tree-hygiene#tests

[Flutter Style Guide]: https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo

[Features we expect every widget to implement]: https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo#features-we-expect-every-widget-to-implement

[CLA]: https://cla.developers.google.com/

[flutter/tests]: https://github.com/flutter/tests

[breaking change policy]: https://github.com/flutter/flutter/wiki/Tree-hygiene#handling-breaking-changes

[Discord]: https://github.com/flutter/flutter/wiki/C

[... truncated]

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `AppBar.color`
- `AppBar.backwardsCompatibility`
- `Remove`
- `LongCatIsLooong`

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

- [x] Verify the API change in Flutter/Dart SDK source
- [x] Determine minimum SDK version requirement
- [x] Write detection logic (AST visitor)
- [x] Write quick-fix replacement
- [x] Create test fixture with bad/good examples (`example/lib/flutter_sdk_migration_rules_fixture.dart`)
- [x] Add unit tests (`test/flutter_sdk_migration_rules_test.dart`)
- [x] Register rule in `all_rules.dart`
- [x] Add to tier in `tiers.dart`
- [x] Update ROADMAP.md (rule was never listed in ROADMAP — confirmed via grep; `Goal: …` count auto-syncs at publish time)
- [x] Update CHANGELOG.md

---

**Status:** Implemented as `avoid_removed_appbar_backwards_compatibility`

**Note:** `AppBar.color` was also removed in the same PR, but `color` is too
generic a parameter name to lint for without false positives on unrelated
widgets. The rule focuses on `backwardsCompatibility` which is unique to AppBar.
**Generated:** From Flutter SDK v3.10.0 release notes
