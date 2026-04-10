# Migration Candidate #006

**Source:** Flutter SDK 3.38.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** last_engine_commit.ps1, $flutterRoot, $gitTopLevel, Use

---

## Release Note Entry

> `last_engine_commit.ps1`: Use `$flutterRoot` instead of `$gitTopLevel` by @matanlurey in [172786](https://github.com/flutter/flutter/pull/172786)
>
> Context: * fix: get content hash for master on local engine branches by @jtmcdole in [172792](https://github.com/flutter/flutter/pull/172792)

**PR:** https://github.com/flutter/flutter/pull/172786

## PR Details

**Title:** `last_engine_commit.ps1`: Use `$flutterRoot` instead of `$gitTopLevel`
**Author:** @matanlurey
**Status:** merged

### Description

Closes https://github.com/flutter/flutter/issues/172190.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `last_engine_commit.ps1`
- `$flutterRoot`
- `$gitTopLevel`
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
**Generated:** From Flutter SDK v3.38.0 release notes
