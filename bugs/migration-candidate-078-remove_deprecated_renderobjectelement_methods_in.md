# Migration Candidate #078

**Source:** Flutter SDK 3.0.0
**Category:** Deprecation
**Relevance Score:** 7
**Detected APIs:** Remove, RenderObjectElement, Piinks

---

## Release Note Entry

> Remove deprecated RenderObjectElement methods by @Piinks in https://github.com/flutter/flutter/pull/98616
>
> Context: * CupertinoTabBar: Add clickable cursor on web by @TahaTesser in https://github.com/flutter/flutter/pull/96996

**PR:** https://github.com/flutter/flutter/pull/98616

## PR Details

**Title:** Remove deprecated RenderObjectElement methods
**Author:** @Piinks
**Status:** merged
**Labels:** c: contributor-productivity, framework, c: API break, a: quality, c: tech-debt

### Description

This removes the following methods from `RenderObjectElement` 
- `insertChildRenderObject`
- `moveChildRenderObject`
- `removeChildRenderObject`

These deprecated methods have reached end of life after the release of Flutter 2.10

- The respective replacements are
  - `insertRenderObjectChild`
  - `moveRenderObjectChild`
  - `removeRenderObjectChild`
- ✅  This migration is supported by the dart fix tool. 
- 🕐  This API was deprecated in https://github.com/flutter/flutter/pull/64254, first tagged v1.21

Part of https://github.com/flutter/flutter/issues/98537
For the full list of deprecations being removed in this batch, see [flutter.dev/go/deprecations-removed-after-2-10](https://docs.google.com/spreadsheets/d/12krawYCu6X_g_5wLGpmiAIi-VcTRV6xG7RGbRovuatQ/edit?usp=sharing)

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I listed at least one issue that this PR fixes in the description above.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I added new tests to check the change I am making, or this PR is [test-exempt].
- [x] All existing and new tests are passing.

If you need help, consider asking for advice on the #hackers-new ch

[... truncated]

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `Remove`
- `RenderObjectElement`
- `Piinks`

---

## Proposed Lint Rule

**Rule Type:** `deprecation_migration`
**Estimated Difficulty:** medium

### Detection Strategy

Detect usage of the deprecated API via AST method/property invocation nodes

**Relevant AST nodes:**
- `MethodInvocation`
- `PropertyAccess`
- `PrefixedIdentifier`
- `SimpleIdentifier`

### Fix Strategy

Replace with the recommended alternative API

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
**Generated:** From Flutter SDK v3.0.0 release notes
