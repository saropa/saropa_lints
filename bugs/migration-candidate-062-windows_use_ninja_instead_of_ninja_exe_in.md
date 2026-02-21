# Migration Candidate #062

**Source:** Flutter SDK 3.10.0
**Category:** Replacement / Migration
**Relevance Score:** 6
**Detected APIs:** Use

---

## Release Note Entry

> [Windows] Use 'ninja' instead of 'ninja.exe' by @loic-sharma in [39326](https://github.com/flutter/engine/pull/39326)
>
> Context: * [web] Hide autofill overlay by @htoor3 in [39294](https://github.com/flutter/engine/pull/39294)

**PR:** https://github.com/flutter/engine/pull/39326

## PR Details

**Title:** [Windows] Use 'ninja' instead of 'ninja.exe'
**Author:** @loic-sharma
**Status:** merged

### Description

The engine's Visual Studio integration is currently broken. See: https://groups.google.com/a/chromium.org/g/chromium-dev/c/027jM6DLkIk

> For Developers who build on Windows, instead of calling “ninja.exe”, please call “ninja” to resolve the [depot_tools/ninja.bat](https://crsrc.org/d/ninja.bat) wrapper.

Note that the Visual Studio integration won't be fixed until [depot_tools#4215121](https://chromium-review.googlesource.com/c/chromium/tools/depot_tools/+/4215121) lands.

Part of: https://github.com/flutter/flutter/issues/119760

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide] and the [C++, Objective-C, Java style guides].
- [x] I listed at least one issue that this PR fixes in the description above.
- [ ] I added new tests to check the change I am making or feature I am adding, or Hixie said the PR is test-exempt. See [testing the engine] for instructions on writing and running engine tests.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I signed the [CLA].
- [ ] All existing and new tests are passing.

If you need help, consider asking for advice on the #hackers-new channel on [Discord].

<!-- Links -->
[Contributor Guide]: https://github.com/flutter/flutter/wiki/Tree-hygiene#overview
[Tree Hygiene]: https://github.co

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
