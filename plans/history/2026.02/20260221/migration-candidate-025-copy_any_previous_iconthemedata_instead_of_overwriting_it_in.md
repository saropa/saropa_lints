# Migration Candidate #025

**Source:** Flutter SDK 3.24.0
**Category:** Replacement / Migration
**Relevance Score:** 8
**Detected APIs:** IconThemeData, Copy, CupertinoButton

---

## Release Note Entry

> Copy any previous `IconThemeData` instead of overwriting it in CupertinoButton by @ricardoboss in [149777](https://github.com/flutter/flutter/pull/149777)
>
> Context: * Manual engine roll to ddd4814 by @gmackall in [150952](https://github.com/flutter/flutter/pull/150952)

**PR:** https://github.com/flutter/flutter/pull/149777

## PR Details

**Title:** Copy any previous `IconThemeData` instead of overwriting it in CupertinoButton
**Author:** @ricardoboss
**Status:** merged
**Labels:** framework, f: cupertino, will affect goldens, autosubmit

### Description

This changes how the `IconThemeData` is passed to the child of `CupertinoButton`.

Previously, it would derive the foreground color from the current theme and create a new `IconThemeData` object.
This causes any `IconThemeData` to be overwritten.

This change uses `IconTheme.of` to get the currently applied icon theme and only overwrites the properties provided by the `CupertinoButton` instead of the whole object.

Fixes #149172.

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
[Contributor Guide]: https://github.com/flutter/flutter/wiki/Tree-hygiene#overview
[Tree Hygiene]: https://github.com/flutter/flutter/wiki/Tree-hygiene
[test-exempt]: https://github.com/flutter/flutter/wiki/Tree-hygiene#t

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `IconThemeData`
- `Copy`
- `CupertinoButton`

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
**Generated:** From Flutter SDK v3.24.0 release notes
