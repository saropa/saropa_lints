# Migration Candidate #052

**Source:** Flutter SDK 3.13.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** Advise, OverflowBar, ButtonBar

---

## Release Note Entry

> Advise developers to use OverflowBar instead of ButtonBar by @leighajarett in [128437](https://github.com/flutter/flutter/pull/128437)
>
> Context: * Sliver Main Axis Group by @thkim1011 in [126596](https://github.com/flutter/flutter/pull/126596)

**PR:** https://github.com/flutter/flutter/pull/128437

## PR Details

**Title:** Advise developers to use OverflowBar instead of ButtonBar
**Author:** @leighajarett
**Status:** merged
**Labels:** framework, f: material design, autosubmit

### Description

Fixes https://github.com/flutter/flutter/issues/128430

## Pre-launch Checklist

- [X] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [X] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [X] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [X] I signed the [CLA].
- [X] I listed at least one issue that this PR fixes in the description above.
- [X] I updated/added relevant documentation (doc comments with `///`).
- [X] I added new tests to check the change I am making, or this PR is [test-exempt].
- [X] All existing and new tests are passing.

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
[Discord]: https:/

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Advise`
- `OverflowBar`
- `ButtonBar`

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
**Generated:** From Flutter SDK v3.13.0 release notes
