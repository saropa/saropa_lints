# Plan #084

**Source:** Dart SDK 3.4.0
**Category:** New Feature / API
**Relevance Score:** 5
**Detected APIs:** Stdout, lineTerminator, Breaking

---

## Release Note Entry

> - **Breaking change** [#53863][]: `Stdout` has a new field `lineTerminator`,
>
> Context: which allows developers to control the line ending used by `stdout` and

---

## Migration Analysis

### What Changed

A new API has been introduced that simplifies a common pattern. Users can benefit from adopting it.

### APIs Involved

- `Stdout`
- `lineTerminator`
- `Breaking`

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

**Rejection reason:** The "breaking change" is that `Stdout` gained a new
`lineTerminator` field — additive API. Existing code writing to `stdout`/`stderr`
continues to work unchanged. The breakage only affects subclasses of `Stdout`
(virtually none in user code) that must now implement the new field. There is
no mechanical migration or deprecated pattern for ordinary callers to detect.
**Generated:** From Dart SDK v3.4.0 release notes
