# Migration Candidate #060

**Source:** Flutter SDK 3.10.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** Use

---

## Release Note Entry

> Use skia_enable_ganesh instead of legacy GN arg by @kjlubick in [40382](https://github.com/flutter/engine/pull/40382)
>
> Context: * disabled the impeller unit tests again by @gaaclarke in [40389](https://github.com/flutter/engine/pull/40389)

**PR:** https://github.com/flutter/engine/pull/40382

## PR Details

**Title:** Use skia_enable_ganesh instead of legacy GN arg
**Author:** @kjlubick
**Status:** merged

### Description

Follow-up to Skia's change http://review.skia.org/649523

## Pre-launch Checklist

- [ x ] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [ x ] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [ x ] I read and followed the [Flutter Style Guide] and the [C++, Objective-C, Java style guides].
- [ ] I listed at least one issue that this PR fixes in the description above.
- [ x ] I added new tests to check the change I am making or feature I am adding, or Hixie said the PR is test-exempt. See [testing the engine] for instructions on writing and running engine tests.
- [ ] I updated/added relevant documentation (doc comments with `///`).
- [ x ] I signed the [CLA].
- [ x ] All existing and new tests are passing.

If you need help, consider asking for advice on the #hackers-new channel on [Discord].

<!-- Links -->
[Contributor Guide]: https://github.com/flutter/flutter/wiki/Tree-hygiene#overview
[Tree Hygiene]: https://github.com/flutter/flutter/wiki/Tree-hygiene
[Flutter Style Guide]: https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo
[C++, Objective-C, Java style guides]: https://github.com/flutter/engine/blob/main/CONTRIBUTING.md#style
[testing the engine]: https://github.com/flutter/flutter/wiki/Testing-the-engine
[CLA]: https://cla.developers.google.com/
[flutter/tests]: https://github.com/flutter/tests
[breaking change policy]: https://github.com/flutter/flutter/w

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

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
**Generated:** From Flutter SDK v3.10.0 release notes
