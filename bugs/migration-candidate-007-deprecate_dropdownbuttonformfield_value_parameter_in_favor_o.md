# Migration Candidate #007

**Source:** Flutter SDK 3.35.0
**Category:** Deprecation
**Relevance Score:** 6
**Detected APIs:** Deprecate, DropdownButtonFormField

---

## Release Note Entry

> Deprecate DropdownButtonFormField "value" parameter in favor of "initialValue" by @bleroux in [170805](https://github.com/flutter/flutter/pull/170805)
>
> Context: * When maintainHintSize is false, hint is centered and aligned, it is different from the original one by @zeqinjie in [168654](https://github.com/flutter/flutter/pull/168654)

**PR:** https://github.com/flutter/flutter/pull/170805

## PR Details

**Title:** Deprecate DropdownButtonFormField "value" parameter in favor of "initialValue"
**Author:** @bleroux
**Status:** merged
**Labels:** framework, f: material design, d: api docs, d: examples, c: tech-debt

### Description

## Description

This PR renames the DropdownButtonFormField constuctor parameter 'value' to 'initialValue'.
See https://github.com/flutter/flutter/pull/170050#issuecomment-2965486000 and https://github.com/flutter/flutter/pull/170050#issuecomment-2971920009 for some context.

## Related Issue

Fixes [DropdownButtonFormField retains selected value even after setting value to null](https://github.com/flutter/flutter/issues/169983#top)

## Tests

Adds 2 tests (one to validate the deprecated parameter can still be used, one for the dart fix).
Updates many (renaming the confusing parameter).

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `Deprecate`
- `DropdownButtonFormField`

---

## Proposed Lint Rule

**Rule Type:** `deprecation_migration`
**Estimated Difficulty:** easy

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
**Generated:** From Flutter SDK v3.35.0 release notes
