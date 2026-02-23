# Migration Candidate #021

**Source:** Flutter SDK 3.27.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** Use, Vector4, Color

---

## Release Note Entry

> [Flutter GPU] Use vm.Vector4 for clear color instead of ui.Color. by @bdero in [55416](https://github.com/flutter/engine/pull/55416)
>
> Context: * [scenario_app] delete get bitmap activity. by @jonahwilliams in [55436](https://github.com/flutter/engine/pull/55436)

**PR:** https://github.com/flutter/engine/pull/55416

## PR Details

**Title:** [Flutter GPU] Use vm.Vector4 for clear color instead of ui.Color.
**Author:** @bdero
**Status:** merged
**Labels:** will affect goldens, autosubmit, flutter-gpu

### Description

Resolves https://github.com/flutter/flutter/issues/155627.

Allow setting the clear directly as floats without conversion work. vector_math already has convenient `Colors.[color]` factories and such. Also, `ui.Color` has a color space now, which does not apply here.

Adds a simple golden to verify that clear colors work:
![flutter_gpu_test_clear_color](https://github.com/user-attachments/assets/ba7a4e74-aaf2-48d8-ac13-115a86daeb19)

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Use`
- `Vector4`
- `Color`

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
**Generated:** From Flutter SDK v3.27.0 release notes
