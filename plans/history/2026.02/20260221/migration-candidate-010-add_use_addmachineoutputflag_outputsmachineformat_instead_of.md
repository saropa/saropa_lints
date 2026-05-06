# Migration Candidate #010

**Source:** Flutter SDK 3.35.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** addMachineOutputFlag, outputsMachineFormat, Add

---

## Release Note Entry

> Add/use `addMachineOutputFlag`/`outputsMachineFormat` instead of strings by @matanlurey in [171459](https://github.com/flutter/flutter/pull/171459)
>
> Context: * Remove now duplicate un-forward ports for Android by @matanlurey in [171473](https://github.com/flutter/flutter/pull/171473)

**PR:** https://github.com/flutter/flutter/pull/171459

## PR Details

**Title:** Add/use `addMachineOutputFlag`/`outputsMachineFormat` instead of strings
**Author:** @matanlurey
**Status:** merged
**Labels:** tool

### Description

Prepares to make changes such as https://github.com/flutter/flutter/issues/10621 easier.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `addMachineOutputFlag`
- `outputsMachineFormat`
- `Add`

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
**Generated:** From Flutter SDK v3.35.0 release notes
