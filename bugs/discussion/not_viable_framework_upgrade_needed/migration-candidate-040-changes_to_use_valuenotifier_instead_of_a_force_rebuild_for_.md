# Migration Candidate #040

**Source:** Flutter SDK 3.19.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** Changes, WidgetInspector, CoderDake

---

## Release Note Entry

> Changes to use valuenotifier instead of a force rebuild for WidgetInspector by @CoderDake in [131634](https://github.com/flutter/flutter/pull/131634)
>
> Context: * [Impeller] GPU frame timings summarization. by @jonahwilliams in [136408](https://github.com/flutter/flutter/pull/136408)

**PR:** https://github.com/flutter/flutter/pull/131634

## PR Details

**Title:** Changes to use valuenotifier instead of a force rebuild for WidgetInspector
**Author:** @CoderDake
**Status:** merged
**Labels:** framework, c: tech-debt

### Description

![](https://media.giphy.com/media/qriH9W51oLsL6/giphy.gif)
Fixes https://github.com/flutter/devtools/issues/6014

Change the forceRebuild behavior of the WidgetInspector to use ValueListenableBuilders instead. This should help resolve heavy rebuilds when the widgetInspectorOverride value changes.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Changes`
- `WidgetInspector`
- `CoderDake`

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
