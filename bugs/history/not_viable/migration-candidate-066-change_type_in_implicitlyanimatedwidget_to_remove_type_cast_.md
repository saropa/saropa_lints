# Migration Candidate #066

**Source:** Flutter SDK 3.7.0
**Category:** Performance Improvement
**Relevance Score:** 6
**Detected APIs:** ImplicitlyAnimatedWidget, Change

---

## Release Note Entry

> Change type in `ImplicitlyAnimatedWidget` to remove type cast to improve performance and style by @fzyzcjy in https://github.com/flutter/flutter/pull/111849
>
> Context: * make ModalBottomSheetRoute public by @The-Redhat in https://github.com/flutter/flutter/pull/108112

**PR:** https://github.com/flutter/flutter/pull/111849

## PR Details

**Title:** Change type in `ImplicitlyAnimatedWidget` to remove type cast to improve performance and style
**Author:** @fzyzcjy
**Status:** merged
**Labels:** framework, a: animation, autosubmit

### Description

Hi, hope to have a quick view whether this PR is acceptable or not? If yes I will add an issue and maybe ask for test-exempt.

---

*Replace this paragraph with a description of what this PR is changing or adding, and why. Consider including before/after screenshots.*

*List which issues are fixed by this PR. You must list at least one issue.*

*If you had to change anything in the [flutter/tests] repo, include a link to the migration guide as per the [breaking change policy].*

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [ ] I listed at least one issue that this PR fixes in the description above.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [ ] I added new tests to check the change I am making, or this PR is [test-exempt].
- [x] All existing and new tests are passing.

If you need help, consider asking for advice on the #hackers-new channel on [Discord].

<!-- Links -->
[Contributor Guide]: https://github.com/flutter/flutter/wiki/Tree-hygiene#overview
[Tree Hygiene]: https://github.com/flutter/flutter/wiki/Tree-hygiene
[test-exempt]: https://github.com/flutter/flutter/wiki/Tree-hygiene#tests
[Flutter Style Guide]: https://github.

[... truncated]

---

## Migration Analysis

### What Changed

A performance optimization is available. The old pattern works but is slower.

### APIs Involved

- `ImplicitlyAnimatedWidget`
- `Change`

---

## Proposed Lint Rule

**Rule Type:** `prefer_performant_api`
**Estimated Difficulty:** medium

### Detection Strategy

Detect the slower old pattern

**Relevant AST nodes:**
- `MethodInvocation`

### Fix Strategy

Replace with the faster/more efficient alternative

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
**Generated:** From Flutter SDK v3.7.0 release notes
