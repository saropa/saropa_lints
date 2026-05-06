# Migration Candidate #054

**Source:** Flutter SDK 3.13.0
**Category:** Replacement / Migration
**Relevance Score:** 6
**Detected APIs:** Skeleton, ListenableBuilder, AnimatedBuilder

---

## Release Note Entry

> [flutter_tools] modify Skeleton template to use ListenableBuilder instead of AnimatedBuilder by @fabiancrx in [128810](https://github.com/flutter/flutter/pull/128810)
>
> Context: * [CP] Fix ConcurrentModificationError in DDS by @christopherfujino in [130740](https://github.com/flutter/flutter/pull/130740)

**PR:** https://github.com/flutter/flutter/pull/128810

## PR Details

**Title:** [flutter_tools] modify Skeleton template to use ListenableBuilder instead of AnimatedBuilder
**Author:** @fabiancrx
**Status:** merged
**Labels:** tool, autosubmit

### Description

Replaces AnimatedBuilder for ListenableBuilder in the skeleton template

Fixes https://github.com/flutter/flutter/issues/128801

No tests needed

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Skeleton`
- `ListenableBuilder`
- `AnimatedBuilder`

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
**Generated:** From Flutter SDK v3.13.0 release notes
