# Plan: Reliable Tier Assignment System

## Problem

The current tier assignment has **two sources of truth** that can silently disagree:

1. **Rule classes** — `RuleTier get tier` on `SaropaLintRule` (default: `professional`)
2. **tiers.dart** — six `Set<String>` constants listing rule names by tier

When they disagree, the init command produces wrong output (e.g., stylistic rules enabled in `--tier professional`). There is no validation to catch this. The `prefer_instance_members_first` bug is a direct result.

### Current State

| Metric | Value |
|--------|-------|
| Total rules | ~1,564 |
| Rules with explicit `tier` override | 2 (0.13%) |
| Rules relying on tiers.dart | 1,562 (99.87%) |
| Validation for tier consistency | None |
| Two-phase logic in init.dart | Yes (lines 398-420) |

The "two-phase migration" in `init.dart` was designed for incremental migration from tiers.dart to rule classes. That migration never happened — only 2 of 1,564 rules were migrated in an unknown number of months.

---

## Design Options

### Option A: Rule classes become single source of truth

Every rule class declares its own tier via `@override RuleTier get tier => RuleTier.essential;`. Delete tiers.dart entirely. init.dart reads tier from rule instances.

**Pros:**
- Tier co-located with rule logic — impossible to forget a separate file
- Adding a rule is one file, not two

**Cons:**
- Must migrate 1,562 rules (add `tier` getter to each)
- No at-a-glance tier overview
- Hard to do bulk tier reassignment
- Reviewing tier balance across 80+ rule files is painful
- Enormous migration PR

### Option B: tiers.dart becomes sole authority (RECOMMENDED)

Remove the `tier` getter from `SaropaLintRule` entirely. init.dart reads only from tiers.dart. Add validation tests.

**Pros:**
- Already 99.87% reality — minimal migration (remove 2 overrides)
- One file shows all tier assignments at a glance
- Bulk tier changes are trivial (edit one file)
- Easy to review tier balance
- Small PR

**Cons:**
- Tier not co-located with rule (but this is already the norm and hasn't caused problems)
- Adding a new rule still requires updating tiers.dart (but this is already required and documented in CLAUDE.md)

### Option C: Keep both, add validation tests only

Add tests that verify rule class `tier` matches tiers.dart. Keep the two-phase logic.

**Pros:**
- Smallest change
- Catches mismatches immediately

**Cons:**
- Doesn't fix the design — still two sources of truth
- Every new rule must be consistent in two places
- Two-phase fallback logic remains confusing
- Tests catch bugs but don't prevent them

---

## Recommendation: Option B

tiers.dart is already the de facto source of truth for 99.87% of rules. Formalizing this is the lowest-risk, highest-reliability path.

---

## Implementation Plan

### Phase 1: Add validation tests (immediate)

**File:** `test/saropa_lints_test.dart`

Add three new tests alongside the existing coverage tests:

1. **No rule in multiple tier sets** — verify no rule name appears in more than one of the six tier sets.

2. **Every rule in exactly one tier set** — verify every rule from `allSaropaRules` appears in exactly one of the six sets (not zero, not two+).

3. **No duplicate entries within a set** — verify no set has the same rule name twice.

These tests catch the exact class of bug that caused the `prefer_instance_members_first` issue. Even if the rest of the plan is deferred, this phase alone prevents recurrence.

### Phase 2: Remove tier from rule classes

**File:** `lib/src/saropa_lint_rule.dart`

- Remove the `RuleTier get tier` getter from `SaropaLintRule`
- Or: keep it but make it read from tiers.dart at runtime (derived, not declared)

**File:** `lib/src/rules/structure_rules.dart`

- Remove the 2 explicit `tier` overrides from `PreferSmallFilesRule` and `PreferSmallTestFilesRule`
- Verify these rules are in the correct set in tiers.dart (they should be in `insanityOnlyRules`)

### Phase 3: Simplify init.dart

**File:** `bin/init.dart`

- Remove the two-phase `_getRuleTiers()` logic (lines 398-420)
- Read tier directly from tiers.dart sets — one phase, one source
- Remove `_getLegacyTier()` function (no longer "legacy")
- Rename the tiers.dart import alias from `legacy_tiers` to just `tiers`

### Phase 4: Add `opinionated` metadata to conflicting pair detection

**File:** `bin/init.dart` or new utility

For rules marked `LintImpact.opinionated`, add a validation step:
- If a rule has `LintImpact.opinionated`, warn if it's NOT in `stylisticRules`
- This catches future cases where an opinionated rule accidentally lands in a non-stylistic tier

**File:** `test/saropa_lints_test.dart`

Add test:
- Every rule with `LintImpact.opinionated` must be in `stylisticRules`

---

## Migration Checklist

- [ ] Phase 1: Add 3 validation tests to `test/saropa_lints_test.dart`
- [ ] Phase 1: Run tests, verify they pass with current state (post member-ordering fix)
- [ ] Phase 2: Remove `tier` getter from `SaropaLintRule` (or make it derived)
- [ ] Phase 2: Remove 2 explicit tier overrides from structure_rules.dart
- [ ] Phase 2: Verify insanityOnlyRules contains the 2 formerly-overridden rules
- [ ] Phase 3: Simplify `_getRuleTiers()` to single-source read
- [ ] Phase 3: Remove `_getLegacyTier()` function
- [ ] Phase 3: Rename `legacy_tiers` import alias
- [ ] Phase 4: Add opinionated-must-be-stylistic validation test
- [ ] Phase 4: Run full test suite, verify everything passes
- [ ] Update CODEBASE_INDEX.md if structural changes warrant it

---

## Risk Assessment

| Phase | Risk | Mitigation |
|-------|------|------------|
| Phase 1 (tests) | None — additive only | Tests validate existing state |
| Phase 2 (remove tier getter) | Low — 2 rules affected | Verify tiers.dart has correct entries |
| Phase 3 (simplify init) | Medium — changes tier resolution | Run init for all tiers, diff output before/after |
| Phase 4 (opinionated check) | None — additive only | Test validates metadata consistency |

### Verification Strategy

Before merging Phase 3, run this for every tier and diff:

```bash
dart run saropa_lints:init --tier essential > before_essential.yaml
dart run saropa_lints:init --tier recommended > before_recommended.yaml
dart run saropa_lints:init --tier professional > before_professional.yaml
dart run saropa_lints:init --tier comprehensive > before_comprehensive.yaml
dart run saropa_lints:init --tier insanity > before_insanity.yaml
dart run saropa_lints:init --tier professional --stylistic > before_stylistic.yaml
```

Then apply changes, re-run, and diff. Output must be identical.
