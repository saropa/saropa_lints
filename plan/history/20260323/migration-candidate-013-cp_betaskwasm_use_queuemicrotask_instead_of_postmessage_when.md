# Completed (2026-03-23)

**Lint:** `prefer_schedule_microtask_over_window_postmessage` (Comprehensive tier, INFO).

**Implementation:** `lib/src/rules/platforms/web_rules.dart` (`PreferScheduleMicrotaskOverWindowPostmessageRule`), arg-shape helper `lib/src/rules/platforms/window_postmessage_scheduling_args.dart`, fixture `example_platforms/lib/web/prefer_schedule_microtask_over_window_postmessage_fixture.dart`, unit tests `test/window_postmessage_scheduling_args_test.dart` + `test/web_rules_test.dart`.

**Quick fix:** Intentionally omitted (replacing `postMessage` can break `MessageEvent`-driven flows).

**Tracking:** `CHANGELOG.md` [Unreleased]; `lib/src/tiers.dart` comprehensive-only set.

---

# Migration Candidate #013

**Source:** Flutter SDK 3.32.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** queueMicrotask, postMessage, Use

---

## Release Note Entry

> [CP-beta][skwasm] Use `queueMicrotask` instead of `postMessage` when single-threaded by @flutteractionsbot in [167154](https://github.com/flutter/flutter/pull/167154)

**PR:** https://github.com/flutter/flutter/pull/167154

## PR Details

**Title:** [CP-beta][skwasm] Use `queueMicrotask` instead of `postMessage` when single-threaded
**Author:** @flutteractionsbot
**Status:** merged
**Labels:** engine, platform-web, cp: review, autosubmit

### Description

This pull request is created by [automatic cherry pick workflow](https://github.com/flutter/flutter/blob/main/docs/releases/Flutter-Cherrypick-Process.md#automatically-creates-a-cherry-pick-request)



### Issue Link:

https://github.com/flutter/flutter/issues/166905



### Changelog Description:

* [flutter/166905](https://github.com/flutter/flutter/issues/166905) Fixes a performance regression in skwasm when running in single-threaded mode.



### Impact Description:

This fixes a significant regression in the skwasm renderer when running single-thraaded (i.e. in a non-`crossOriginIsolated` browsing context)



### Workaround:

Is there a workaround for this issue?



The only workaround is to run skwasm in a multi-threaded context or to disable skwasm.



### Risk:

What is the risk level of this cherry-pick?


  - [ x ] Low

  - [ ] Medium

  - [ ] High



This essentially returns the single-threaded renderer to the previous message passing strategy.



### Test Coverage:

Are you confident that your fix is well-tested by automated tests?


  - [ x ] Yes

  - [ ] No



### Validation Steps:

What are the steps to validate that this fix works?



Built the Wonderous app and take a Chrome profile.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `queueMicrotask`
- `postMessage`
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

- [x] Verify the API change in Flutter/Dart SDK source
- [x] Determine minimum SDK version requirement (standard `dart:html`; no extra SDK floor)
- [x] Write detection logic (AST visitor)
- [ ] Write quick-fix replacement (deferred: behavior depends on listener wiring; no safe auto-fix)
- [x] Create test fixture with bad/good examples
- [x] Add unit tests
- [x] Register rule in `all_rules.dart`
- [x] Add to tier in `tiers.dart`
- [x] Update ROADMAP.md (project uses CHANGELOG for implemented rules)
- [x] Update CHANGELOG.md

---

**Status:** Implemented as `prefer_schedule_microtask_over_window_postmessage` (Comprehensive tier)
**Generated:** From Flutter SDK v3.32.0 release notes
