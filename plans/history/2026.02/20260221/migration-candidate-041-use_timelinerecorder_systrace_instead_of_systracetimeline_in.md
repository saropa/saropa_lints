# Migration Candidate #041

**Source:** Flutter SDK 3.19.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** Use

---

## Release Note Entry

> Use --timeline_recorder=systrace instead of --systrace_timeline by @derekxu16 in [46884](https://github.com/flutter/engine/pull/46884)
>
> Context: * [Impeller] Only allow Impeller in flutter_tester if vulkan is enabled. by @dnfield in [46895](https://github.com/flutter/engine/pull/46895)

**PR:** https://github.com/flutter/engine/pull/46884

## PR Details

**Title:** Use --timeline_recorder=systrace instead of --systrace_timeline
**Author:** @derekxu16
**Status:** merged
**Labels:** platform-fuchsia

### Description

`--systrace_timeline` is redundant and makes the `getFlagList` VM Service RPC not return `timeline_recorder=systrace` (https://github.com/flutter/devtools/issues/6524#issuecomment-1760090526), so we would like to deprecate and remove it.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

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
