# Migration Candidate #034

**Source:** Flutter SDK 3.22.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** KeepAliveHandle.release, Remove, LongCatIsLooong

---

## Release Note Entry

> Remove deprecated `KeepAliveHandle.release` by @LongCatIsLooong in [143961](https://github.com/flutter/flutter/pull/143961)
>
> Context: * Remove deprecated `InteractiveViewer.alignPanAxis` by @LongCatIsLooong in [142500](https://github.com/flutter/flutter/pull/142500)

**PR:** https://github.com/flutter/flutter/pull/143961

## PR Details

**Title:** Remove deprecated `KeepAliveHandle.release`
**Author:** @LongCatIsLooong
**Status:** merged
**Labels:** framework, autosubmit

### Description

https://github.com/flutter/flutter/issues/143956

I still did not include a dartfix since a dartfix that replaces `release` with `dispose` would change the semantics and may cause a runtime crash instead of a build error.

@Piinks  does setting `bulkApply` to false force the user to apply the fix to every occurrence one by one in their IDE? If so then it seems that would be the way to go for this deprecation?

## Pre-launch Checklist

- [ ] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [ ] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [ ] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [ ] I signed the [CLA].
- [ ] I listed at least one issue that this PR fixes in the description above.
- [ ] I updated/added relevant documentation (doc comments with `///`).
- [ ] I added new tests to check the change I am making, or this PR is [test-exempt].
- [ ] I followed the [breaking change policy] and added [Data Driven Fixes] where supported.
- [ ] All existing and new tests are passing.

If you need help, consider asking for advice on the #hackers-new channel on [Discord].

<!-- Links -->
[Contributor Guide]: https://github.com/flutter/flutter/wiki/Tree-hygiene#overview
[Tree Hygiene]: https://github.com/flutter/flutter/wiki/Tree-hygiene
[test-exempt]: https://github.com/flutter/flutter/wiki/Tree-hygiene#tests
[Flutter Style Gui

[... truncated]

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `KeepAliveHandle.release`
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
