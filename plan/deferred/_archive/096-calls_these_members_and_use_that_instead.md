# Plan #096

**Source:** Dart SDK 3.1.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** N/A

---

## Release Note Entry

> calls these members, and use that instead.
>
> Context: - **Breaking change to `@staticInterop` and `external` extension members**:

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

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

**Status:** Rejected — not implementable as a lint rule

**Rejection reason:** The auto-generated release note fragment ("calls these
members, and use that instead") is a truncated mid-sentence excerpt of the
Dart 3.1 `@staticInterop` / `external` extension member breaking change. The
"Detected APIs" field is literally `N/A`. There is no concrete identifier,
class, or method name to drive an AST detector — any rule would be guessing
at what to match. Actionable staticInterop migrations (if any) would need
their own dedicated plan with a specific API target, not this truncated
fragment.
**Generated:** From Dart SDK v3.1.0 release notes
