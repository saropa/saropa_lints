# Migration Candidate #086

**Source:** Dart SDK 3.4.0
**Category:** New Parameter / Option
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

A new parameter has been added that provides better behavior or additional control.

### APIs Involved

- `Stdout`
- `lineTerminator`
- `Breaking`

---

## Proposed Lint Rule

**Rule Type:** `prefer_new_parameter`
**Estimated Difficulty:** medium

### Detection Strategy

Detect API calls missing the new parameter

**Relevant AST nodes:**
- `MethodInvocation`
- `InstanceCreationExpression`
- `ArgumentList`

### Fix Strategy

Suggest adding the new parameter for better behavior

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
**Generated:** From Dart SDK v3.4.0 release notes
