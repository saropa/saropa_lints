# Migration Candidate #016

**Source:** Flutter SDK 3.32.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** Prefer, AhmedLSayed9

---

## Release Note Entry

> Prefer using non nullable opacityAnimation property by @AhmedLSayed9 in [164795](https://github.com/flutter/flutter/pull/164795)
>
> Context: * feat: Added forceErrorText in DropdownButtonFormField #165188 by @Memet18 in [165189](https://github.com/flutter/flutter/pull/165189)

**PR:** https://github.com/flutter/flutter/pull/164795

## PR Details

**Title:** Prefer using non nullable opacityAnimation property
**Author:** @AhmedLSayed9
**Status:** merged
**Labels:** framework, f: material design

### Description

`opacityAnimation` of `DropdownMenuItemButton` is always set with a non-nullable value. Therefore, I think it's a good idea to use `late CurvedAnimation` instead of `CurvedAnimation?` and avoid the unnecessary null assertion operator (!)

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I listed at least one issue that this PR fixes in the description above.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I added new tests to check the change I am making, or this PR is [test-exempt].
- [x] I followed the [breaking change policy] and added [Data Driven Fixes] where supported.
- [x] All existing and new tests are passing.

If you need help, consider asking for advice on the #hackers-new channel on [Discord].

<!-- Links -->
[Contributor Guide]: https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md#overview
[Tree Hygiene]: https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md
[test-exempt]: https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md#tests
[Flutter Style Guide]: https://github.com/flutter/flutter/blob/main/docs/contributing/Style-guide-for-Flutter-repo.md


[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Prefer`
- `AhmedLSayed9`

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
**Generated:** From Flutter SDK v3.32.0 release notes
