# Migration Candidate #039

**Source:** Flutter SDK 3.19.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** RawKeyEvent, RawKeyboard, Deprecate

---

## Release Note Entry

> Deprecate `RawKeyEvent`, `RawKeyboard`, et al. by @gspencergoog in [136677](https://github.com/flutter/flutter/pull/136677)
>
> Context: * Fix dayPeriodColor handling of non-MaterialStateColors by @gspencergoog in [139845](https://github.com/flutter/flutter/pull/139845)

**PR:** https://github.com/flutter/flutter/pull/136677

## PR Details

**Title:** Deprecate `RawKeyEvent`, `RawKeyboard`, et al.
**Author:** @gspencergoog
**Status:** merged
**Labels:** a: tests, a: text input, framework, f: material design, f: scrolling, f: cupertino, d: api docs, d: examples, f: focus, autosubmit

### Description

## Description

This starts the deprecation of the `RawKeyEvent`/`RawKeyboard` event system that has been replaced by the `KeyEvent`/`HardwareKeyboard` event system.

Migration guide is available here: https://docs.flutter.dev/release/breaking-changes/key-event-migration

## Related Issues
 - https://github.com/flutter/flutter/issues/136419

## Related PRs
 - https://github.com/flutter/website/pull/9889

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `RawKeyEvent`
- `RawKeyboard`
- `Deprecate`

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
**Generated:** From Flutter SDK v3.19.0 release notes
