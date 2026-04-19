# Plan #083

**Source:** Dart SDK 3.4.0
**Category:** New Feature / API
**Relevance Score:** 5
**Detected APIs:** ParallelWaitError, Added

---

## Release Note Entry

> - Added option for `ParallelWaitError` to get some meta-information that
>
> Context: it can expose in its `toString`, and the `Iterable<Future>.wait` and

---

## Migration Analysis

### What Changed

A new API has been introduced that simplifies a common pattern. Users can benefit from adopting it.

### APIs Involved

- `ParallelWaitError`
- `Added`

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

**Rejection reason:** This is an additive enhancement — `ParallelWaitError`
gained optional meta-information exposed via `toString`, plus optional
parameters on `Iterable<Future>.wait`. No existing call site needs to change;
the old call shape keeps working. There is no deprecated pattern to detect and
no "old vs new" migration. Proactively suggesting users pass the new optional
argument would be low-signal noise.
**Generated:** From Dart SDK v3.4.0 release notes
