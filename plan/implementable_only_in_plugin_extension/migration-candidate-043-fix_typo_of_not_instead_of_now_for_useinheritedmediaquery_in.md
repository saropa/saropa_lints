# Migration Candidate #043

**Source:** Flutter SDK 3.19.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** useInheritedMediaQuery

---

## Release Note Entry

> fix typo of 'not' instead of 'now' for `useInheritedMediaQuery` by @timmaffett in [139940](https://github.com/flutter/flutter/pull/139940)
>
> Context: * [Docs] Added missing `CupertinoApp.showSemanticsDebugger` by @piedcipher in [139913](https://github.com/flutter/flutter/pull/139913)

**PR:** https://github.com/flutter/flutter/pull/139940

## PR Details

**Title:** fix typo of 'not' instead of 'now' for `useInheritedMediaQuery` 
**Author:** @timmaffett
**Status:** merged
**Labels:** framework, autosubmit

### Description

The doc comment for `useInheritedMediaQuery` has a typo of 'not' instead of 'now' and it is confusing at the `@Deprecated()` message clearly states it is *now* ignored.
(and indeed checking the code you can verify that it *is* indeed ignored)

existing code before PR:
```dart
/// {@template flutter.widgets.widgetsApp.useInheritedMediaQuery}
/// Deprecated. This setting is not ignored.
///                             ^^^
/// The widget never introduces its own [MediaQuery]; the [View] widget takes
/// care of that.
/// {@endtemplate}
@Deprecated(
  'This setting is now ignored. '
  'WidgetsApp never introduces its own MediaQuery; the View widget takes care of that. '
  'This feature was deprecated after v3.7.0-29.0.pre.'
)
final bool useInheritedMediaQuery;
```


## Pre-launch Checklist

- [X ] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [X] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [X] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [X] I signed the [CLA].
- [X] I listed at least one issue that this PR fixes in the description above.
- [X] I updated/added relevant documentation (doc comments with `///`).
- [X] I added new tests to check the change I am making, or this PR is [test-exempt].
- [X] All existing and new tests are passing.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `useInheritedMediaQuery`

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
