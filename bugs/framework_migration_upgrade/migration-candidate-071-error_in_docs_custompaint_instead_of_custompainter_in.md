# Migration Candidate #071

**Source:** Flutter SDK 3.7.0
**Category:** Replacement / Migration
**Relevance Score:** 6
**Detected APIs:** CustomPaint, CustomPainter, Error

---

## Release Note Entry

> Error in docs: `CustomPaint` instead of `CustomPainter` by @0xba1 in https://github.com/flutter/flutter/pull/107836
>
> Context: * Dropdown height large scale text fix by @foongsq in https://github.com/flutter/flutter/pull/107201

**PR:** https://github.com/flutter/flutter/pull/107836

## PR Details

**Title:** Error in docs: `CustomPaint` instead of `CustomPainter`
**Author:** @0xba1
**Status:** merged
**Labels:** framework, autosubmit

### Description

Hi, while going through the code documentation of `CustomPainter`, I found an error in which `CustomPaint` was used instead of `CustomPainter` https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/rendering/custom_paint.dart#L29

Error: line 29, lib/src/rendering/custom_paint.dart

```
/// To implement a custom painter, either subclass or implement this interface
/// to define your custom paint delegate. [CustomPaint] subclasses must
/// implement the [paint] and [shouldRepaint] methods, and may optionally also...
```
Should be:
```
/// To implement a custom painter, either subclass or implement this interface
/// to define your custom paint delegate. [CustomPainter] subclasses must
/// implement the [paint] and [shouldRepaint] methods, and may optionally also...
```

This error is also available on the website docs https://api.flutter.dev/flutter/rendering/CustomPainter-class.html.

This solves https://github.com/flutter/flutter/issues/107837

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I listed at least one issue that this PR fixes in the description above.
- [ ] I updated/added relevant documentation (doc comments with `///`).
- [ ] 

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `CustomPaint`
- `CustomPainter`
- `Error`

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
**Generated:** From Flutter SDK v3.7.0 release notes
