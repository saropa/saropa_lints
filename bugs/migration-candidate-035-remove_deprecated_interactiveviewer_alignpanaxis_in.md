# Migration Candidate #035

**Source:** Flutter SDK 3.22.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** InteractiveViewer.alignPanAxis, Remove, LongCatIsLooong

---

## Release Note Entry

> Remove deprecated `InteractiveViewer.alignPanAxis` by @LongCatIsLooong in [142500](https://github.com/flutter/flutter/pull/142500)
>
> Context: * disable debug banner in m3 page test apps. by @jonahwilliams in [143857](https://github.com/flutter/flutter/pull/143857)

**PR:** https://github.com/flutter/flutter/pull/142500

## PR Details

**Title:** Remove deprecated `InteractiveViewer.alignPanAxis`
**Author:** @LongCatIsLooong
**Status:** merged
**Labels:** framework, c: tech-debt, autosubmit

### Description

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
[Discord]: https://github.com/flutter/flutter/wiki/Chat

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `InteractiveViewer.alignPanAxis`
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
