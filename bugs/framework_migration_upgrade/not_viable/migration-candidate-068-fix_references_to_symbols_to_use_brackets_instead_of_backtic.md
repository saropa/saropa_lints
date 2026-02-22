# Migration Candidate #068

**Source:** Flutter SDK 3.7.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** Fix

---

## Release Note Entry

> Fix references to symbols to use brackets instead of backticks by @gspencergoog in https://github.com/flutter/flutter/pull/111331
>
> Context: * Add doc note about when to dispose TextPainter by @dnfield in https://github.com/flutter/flutter/pull/111403

**PR:** https://github.com/flutter/flutter/pull/111331

## PR Details

**Title:** Fix references to symbols to use brackets instead of backticks
**Author:** @gspencergoog
**Status:** merged
**Labels:** a: text input, framework, a: animation, f: material design, f: scrolling, f: cupertino, f: routes, f: focus, autosubmit

### Description

## Description

This fixes a bunch of places where we refer to the symbol being documented using ``` `symbol` ``` notation, when it would be really helpful in an IDE to have them be linked symbols, since we don't mind if a symbol links to itself, but using backticks makes those references invisible to the analyzer, so that refactorings, dart fixes, etc. don't see them.

## Related Issues
 - https://github.com/dart-lang/dartdoc/issues/3149

## Tests
 - Just doc changes, no code.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Fix`

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
