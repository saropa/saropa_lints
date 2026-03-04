# Migration Candidate #075

**Source:** Flutter SDK 3.3.0
**Category:** New Feature / API
**Relevance Score:** 5
**Detected APIs:** NavigationBar, Mention

---

## Release Note Entry

> Mention that `NavigationBar` is a new widget by @guidezpl in https://github.com/flutter/flutter/pull/104264
>
> Context: * [Keyboard, Windows] Fix that IME events are still dispatched to FocusNode.onKey by @dkwingsmt in https://github.com/flutter/flutter/pull/104244

**PR:** https://github.com/flutter/flutter/pull/104264

## PR Details

**Title:** Mention that `NavigationBar` is a new widget
**Author:** @guidezpl
**Status:** merged
**Labels:** framework, f: material design

### Description

https://github.com/flutter/flutter/issues/88888

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I listed at least one issue that this PR fixes in the description above.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I added new tests to check the change I am making, or this PR is [test-exempt].
- [x] All existing and new tests are passing.

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
[Discord]: https://github

[... truncated]

---

## Migration Analysis

### What Changed

A new API has been introduced that simplifies a common pattern. Users can benefit from adopting it.

### APIs Involved

- `NavigationBar`
- `Mention`

---

## Proposed Lint Rule

**Rule Type:** `prefer_new_api`
**Estimated Difficulty:** medium

### Detection Strategy

Detect verbose/old pattern that could use the new API

**Relevant AST nodes:**
- `MethodInvocation`
- `ExpressionStatement`

### Fix Strategy

Suggest using the new, more concise API

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
**Generated:** From Flutter SDK v3.3.0 release notes
