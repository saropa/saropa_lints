# Migration Candidate #067

**Source:** Flutter SDK 3.7.0
**Category:** Replacement / Migration
**Relevance Score:** 9
**Detected APIs:** Use, ScrollbarTheme, Theme, Scrollbar, Oleh

---

## Release Note Entry

> Use ScrollbarTheme instead Theme for Scrollbar by @Oleh-Sv in https://github.com/flutter/flutter/pull/113237
>
> Context: * Add `AnimatedIcons` previews and examples by @TahaTesser in https://github.com/flutter/flutter/pull/113700

**PR:** https://github.com/flutter/flutter/pull/113237

## PR Details

**Title:** Use ScrollbarTheme instead Theme for Scrollbar
**Author:** @Oleh-Sv
**Status:** merged
**Labels:** framework, f: material design, f: scrolling, autosubmit

### Description

When we are using Theme directly scrollbar ignores ScrollbarTheme widgets in tree. We should use ScrollbarTheme.of(context) for get correct theme. Implementation of  ScrollbarTheme.of(context) already use Theme.of(context) if we don't have any ScrollbarTheme widgets in tree.

Issue
Fixes https://github.com/flutter/flutter/issues/113235

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I listed at least one issue that this PR fixes in the description above.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I added new tests to check the change I am making, or this PR is [test-exempt].
- [x] All existing and new tests are passing.

<!-- Links -->
[Contributor Guide]: https://github.com/flutter/flutter/wiki/Tree-hygiene#overview
[Tree Hygiene]: https://github.com/flutter/flutter/wiki/Tree-hygiene
[test-exempt]: https://github.com/flutter/flutter/wiki/Tree-hygiene#tests
[Flutter Style Guide]: https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo
[Features we expect every widget to implement]: https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo#features-we-expect-every-widget-to-implement
[CLA]: https://cla.dev

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Use`
- `ScrollbarTheme`
- `Theme`
- `Scrollbar`
- `Oleh`

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
**Generated:** From Flutter SDK v3.7.0 release notes
