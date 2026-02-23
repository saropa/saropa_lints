# Migration Candidate #063

**Source:** Flutter SDK 3.10.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** Switch, Noto, Emoji, Color

---

## Release Note Entry

> Switch from Noto Emoji to Noto Color Emoji and update font data by @hterkelsen in [40666](https://github.com/flutter/engine/pull/40666)
>
> Context: * [macOS]Support SemanticsService.announce by @hangyujin in [40585](https://github.com/flutter/engine/pull/40585)

**PR:** https://github.com/flutter/engine/pull/40666

## PR Details

**Title:** Switch from Noto Emoji to Noto Color Emoji and update font data
**Author:** @harryterkelsen
**Status:** merged
**Labels:** platform-web

### Description

Use Noto Color Emoji instead of Noto Emoji for the default Emoji fallback font. These emoji look much nicer than the black and white variants.

Fixes https://github.com/flutter/flutter/issues/119536

Before:
![Screenshot 2023-03-27 at 9 52 52 AM](https://user-images.githubusercontent.com/1961493/228015897-b5f0656e-d585-48f8-8f64-3fe78137349a.png)

After:
![Screenshot 2023-03-27 at 10 11 25 AM](https://user-images.githubusercontent.com/1961493/228015945-f483c350-f915-46e1-8bc0-600f31738aca.png)



## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide] and the [C++, Objective-C, Java style guides].
- [x] I listed at least one issue that this PR fixes in the description above.
- [x] I added new tests to check the change I am making or feature I am adding, or Hixie said the PR is test-exempt. See [testing the engine] for instructions on writing and running engine tests.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I signed the [CLA].
- [x] All existing and new tests are passing.

If you need help, consider asking for advice on the #hackers-new channel on [Discord].

<!-- Links -->
[Contributor Guide]: https://github.com/flutter/flutter/wiki/Tree-hygiene#overview
[Tree Hygiene]: https://github.com/flutter/flutter/wiki/Tree-hygi

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Switch`
- `Noto`
- `Emoji`
- `Color`

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
**Generated:** From Flutter SDK v3.10.0 release notes
