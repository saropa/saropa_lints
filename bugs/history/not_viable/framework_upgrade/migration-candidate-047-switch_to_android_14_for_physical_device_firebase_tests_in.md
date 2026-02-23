# Migration Candidate #047

**Source:** Flutter SDK 3.19.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** Switch

---

## Release Note Entry

> Switch to Android 14 for physical device firebase tests by @gmackall in [47016](https://github.com/flutter/engine/pull/47016)
>
> Context: * Move window state update to window realize callback by @gspencergoog in [47713](https://github.com/flutter/engine/pull/47713)

**PR:** https://github.com/flutter/engine/pull/47016

## PR Details

**Title:** Switch to Android 14 for physical device firebase tests
**Author:** @gmackall
**Status:** merged
**Labels:** autosubmit

### Description

Switch to the latest android version for tests.

Device is high capacity, and [currently in use in flutter/flutter](https://github.com/flutter/flutter/blob/dbb79e63ebdfdc0f11c9d1ab4125a80384a59d56/.ci.yaml#L451). See [here](https://firebase.google.com/docs/test-lab/android/available-testing-devices) to get the list of devices.

Related to https://github.com/flutter/flutter/pull/136736

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide] and the [C++, Objective-C, Java style guides].
- [ ] I listed at least one issue that this PR fixes in the description above.
- [x] I added new tests to check the change I am making or feature I am adding, or the PR is [test-exempt]. See [testing the engine] for instructions on writing and running engine tests.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I signed the [CLA].
- [ ] All existing and new tests are passing.

If you need help, consider asking for advice on the #hackers-new channel on [Discord].

<!-- Links -->
[Contributor Guide]: https://github.com/flutter/flutter/wiki/Tree-hygiene#overview
[Tree Hygiene]: https://github.com/flutter/flutter/wiki/Tree-hygiene
[test-exempt]: https://github.com/flutter/flutter/wiki/Tree-hygiene#tests
[Flutter Style Guide]: https://github.com/flutte

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Switch`

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
