# Migration Candidate #076

**Source:** Flutter SDK 3.3.0
**Category:** Replacement / Migration
**Relevance Score:** 8
**Detected APIs:** InputDecorator, Switch, Opacity, AnimatedOpacity

---

## Release Note Entry

> `InputDecorator`: Switch hint to Opacity instead of AnimatedOpacity by @markusaksli-nc in https://github.com/flutter/flutter/pull/107156
>
> Context: * Fix `ListTile` theme shape in a drawer by @TahaTesser in https://github.com/flutter/flutter/pull/106343

**PR:** https://github.com/flutter/flutter/pull/107156

## PR Details

**Title:** `InputDecorator`: Switch hint to Opacity instead of AnimatedOpacity
**Author:** @markusaksli-nc
**Status:** merged
**Labels:** a: text input, framework, f: material design

### Description

The `AnimatedOpacity` transition doesn't match native components on at least Android and web. [M3](https://m3.material.io/components/text-fields/specs) doesn't include [Placeholder text](https://material.io/archive/guidelines/components/text-fields.html#text-fields-layout) anymore and I can't find anything saying that it was animated. The original complaint also stated that the transition from hint to input text can be disorienting.

This PR switches the hint to `Opacity`, making the opacity transition instant.

Fixes https://github.com/flutter/flutter/issues/20283

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I listed at least one issue that this PR fixes in the description above.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I added new tests to check the change I am making, or this PR is [test-exempt].
- [x] All existing and new tests are passing.

<!-- Links -->
[Contributor Guide]: https://github.com/flutter/flutter/wiki/Tree-hygiene#overview
[Tree Hygiene]: https://github.com/flutter/flutter/wiki/Tree-hygiene
[test-exempt]: https://github.com/flutter/flutter/wiki/Tree-hygiene#tests
[Flutter Style Guide]: https://github.com/f

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `InputDecorator`
- `Switch`
- `Opacity`
- `AnimatedOpacity`

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
**Generated:** From Flutter SDK v3.3.0 release notes
