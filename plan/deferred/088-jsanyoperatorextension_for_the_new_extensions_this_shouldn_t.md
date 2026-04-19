# Plan #088

**Source:** Dart SDK 3.3.0
**Category:** New Feature / API
**Relevance Score:** 5
**Detected APIs:** JSAnyOperatorExtension, This

---

## Release Note Entry

> `JSAnyOperatorExtension` for the new extensions. This shouldn't make a
>
> Context: difference unless the extension names were explicitly used.

---

## Migration Analysis

### What Changed

A new API has been introduced that simplifies a common pattern. Users can benefit from adopting it.

### APIs Involved

- `JSAnyOperatorExtension`
- `This`

---

## Proposed Lint Rule

**Rule Type:** `prefer_new_api`
**Estimated Difficulty:** medium

### Detection Strategy

Detect verbose/old pattern that could use the new API

**Relevant AST nodes:**
- `MethodInvocation`
- `ExpressionStatement`

### Fix Strategy

Suggest using the new, more concise API

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

**Status:** Rejected — not implementable as a lint rule

**Rejection reason:** The release note itself explicitly says this "shouldn't
make a difference unless the extension names were explicitly used." The change
reorganizes `dart:js_interop` extensions into `JSAnyOperatorExtension` — the
operators continue to resolve automatically for nearly all call sites. The
only affected code is uncommon direct references to the old extension class
names. Detecting that via lint would require hard-coded name lists for
effectively zero real-world impact; the analyzer's own `deprecated_member_use`
already covers any directly referenced old names.
**Generated:** From Dart SDK v3.3.0 release notes
