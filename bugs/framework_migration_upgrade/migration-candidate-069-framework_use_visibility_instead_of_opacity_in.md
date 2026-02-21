# Migration Candidate #069

**Source:** Flutter SDK 3.7.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** Visibility, Opacity

---

## Release Note Entry

> [framework] use Visibility instead of Opacity by @jonahwilliams in https://github.com/flutter/flutter/pull/112191
>
> Context: * Add regression test for TextPainter.getWordBoundary by @LongCatIsLooong in https://github.com/flutter/flutter/pull/112229

**PR:** https://github.com/flutter/flutter/pull/112191

## PR Details

**Title:** [framework] use Visibility instead of Opacity
**Author:** @jonahwilliams
**Status:** merged
**Labels:** a: text input, framework, f: material design, f: cupertino, autosubmit

### Description

When fully opaque, the Opacity widget still inserts an opacity layer in the tree. While this isn't super expensive by itself, it does force parent render objects to perform compositing and may make UIs marginally slower.

Use the visibility widget instead

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Visibility`
- `Opacity`

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
