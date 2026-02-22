# Migration Candidate #042

**Source:** Flutter SDK 3.19.0
**Category:** Replacement / Migration
**Relevance Score:** 6
**Detected APIs:** OverlayPortal.overlayChild, OverlayPortal, Overlay, LongCatIsLooong

---

## Release Note Entry

> `OverlayPortal.overlayChild` contributes semantics to `OverlayPortal` instead of `Overlay` by @LongCatIsLooong in [134921](https://github.com/flutter/flutter/pull/134921)
>
> Context: * Update `ColorScheme.fromSwatch` docs for Material 3 by @TahaTesser in [136816](https://github.com/flutter/flutter/pull/136816)

**PR:** https://github.com/flutter/flutter/pull/134921

## PR Details

**Title:** `OverlayPortal.overlayChild` contributes semantics to `OverlayPortal` instead of `Overlay`
**Author:** @LongCatIsLooong
**Status:** merged
**Labels:** framework, f: material design, autosubmit

### Description

Fixes https://github.com/flutter/flutter/issues/134456

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
[Discord]: https:/

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `OverlayPortal.overlayChild`
- `OverlayPortal`
- `Overlay`
- `LongCatIsLooong`

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
**Generated:** From Flutter SDK v3.19.0 release notes
