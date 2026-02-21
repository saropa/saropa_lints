# Migration Candidate #051

**Source:** Flutter SDK 3.16.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** start, extent, Use

---

## Release Note Entry

> Use `start` instead of `extent` for Windows IME cursor position by @yaakovschectman in [45667](https://github.com/flutter/engine/pull/45667)
>
> Context: * Handle external window's `WM_CLOSE` in lifecycle manager by @yaakovschectman in [45840](https://github.com/flutter/engine/pull/45840)

**PR:** https://github.com/flutter/engine/pull/45667

## PR Details

**Title:** Use `start` instead of `extent` for Windows IME cursor position
**Author:** @yaakovschectman
**Status:** merged
**Labels:** affects: text input, affects: desktop, platform-windows

### Description

When composing with the IME in a text edit, we should add the `start` of the composition range to the in-composition `cursor_pos` rather than its `extent`. When using `extent`, the cursor position would always be outside of the composition range, resulting in the linked bug. Add a test to check cursor position.

https://github.com/flutter/flutter/issues/123749

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide] and the [C++, Objective-C, Java style guides].
- [x] I listed at least one issue that this PR fixes in the description above.
- [x] I added new tests to check the change I am making or feature I am adding, or the PR is [test-exempt]. See [testing the engine] for instructions on writing and running engine tests.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [ ] I signed the [CLA].
- [x] All existing and new tests are passing.

If you need help, consider asking for advice on the #hackers-new channel on [Discord].

<!-- Links -->
[Contributor Guide]: https://github.com/flutter/flutter/wiki/Tree-hygiene#overview
[Tree Hygiene]: https://github.com/flutter/flutter/wiki/Tree-hygiene
[test-exempt]: https://github.com/flutter/flutter/wiki/Tree-hygiene#tests
[Flutter Style Guide]: https://github.com/flutter/flutter/wiki/Style-guide-

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `start`
- `extent`
- `Use`

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
**Generated:** From Flutter SDK v3.16.0 release notes
