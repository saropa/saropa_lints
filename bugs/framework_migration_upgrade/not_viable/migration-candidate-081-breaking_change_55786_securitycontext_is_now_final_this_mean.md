# Migration Candidate #081

**Source:** Dart SDK 3.5.0
**Category:** Breaking Change
**Relevance Score:** 6
**Detected APIs:** SecurityContext, final, Breaking, Change, This

---

## Release Note Entry

> - **Breaking Change** [#55786][]: `SecurityContext` is now `final`. This means
>
> Context: that `SecurityContext` can no longer be subclassed. `SecurityContext`

---

## Migration Analysis

### What Changed

An API has been removed or its signature changed. Code using the old API will fail to compile.

### APIs Involved

- `SecurityContext`
- `final`
- `Breaking`
- `Change`
- `This`

---

## Proposed Lint Rule

**Rule Type:** `breaking_change_migration`
**Estimated Difficulty:** medium

### Detection Strategy

Detect usage of removed/changed API signatures

**Relevant AST nodes:**
- `MethodInvocation`
- `InstanceCreationExpression`

### Fix Strategy

Replace with the new API signature or pattern

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
**Generated:** From Dart SDK v3.5.0 release notes
