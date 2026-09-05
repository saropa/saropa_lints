# BUG: `avoid_nullable_interpolation` — False positive when nullable value is guarded by enclosing null check

**Status: Fixed** (enclosing-guard class only — see split-out follow-up below)

Created: 2026-09-05
Rule: `avoid_nullable_interpolation`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (grep for exact line)
Severity: False positive
Rule version: v6

---

## Summary

2 of 3 findings are false positives. The rule does not account for:

1. **RegExpMatch group guaranteed by pattern** (`health_summary.dart:51`): `'${m[1]},'` where `m` is a `RegExpMatch` from a pattern with required group 1 (`(\d)(?=(\d{3})+$)`). The group is always present when the match succeeds, but `RegExpMatch.group()` returns `String?` generically.

2. **Enclosing null check on the same property** (`ai_fix_handoff.dart:101`): `${f.churn}` inside a block guarded by `if (f.churn != null)`. Dart does not flow-promote getters/properties, so the type stays `int?` even after the check.

Only `health_export_markdown.dart:104` was real (fixed separately with a null guard).

---

## Attribution Evidence

```bash
grep -rn "'avoid_nullable_interpolation'" lib/src/rules/
# (match in code_quality_avoid_rules.dart)
```

---

## Reproducer

```dart
// FP: Property access guarded by null check but not promoted
if (file.churn != null) {
  result.add('${file.churn} commits'); // LINT — but should NOT lint
}
```

---

## Suggested Fix

1. Check the enclosing `if`/`when` condition for a null check on the same expression.
2. For `RegExpMatch[n]`, consider suppressing when the group index is a literal ≤ the pattern's required group count (hard, may not be worth it).

---

## Affected Files (FP only)

- `health_summary.dart:51` — RegExpMatch group
- `ai_fix_handoff.dart:101` — property null-guarded in enclosing `if`

---

## Environment

- saropa_lints version: current (unreleased)

---

## Finish Report (2026-09-05)

`_isNotNullCheckFor()` in `lib/src/rules/data/type_rules.dart` only matched
a bare `expr != null` condition, so a guard buried inside a compound `&&`
(e.g. `if (isChurning(f) && f.churn != null)`) was invisible to it and the
interpolation inside the then-branch was flagged as if unguarded. This is
finding 2 in the Summary above (`ai_fix_handoff.dart:101`).

Fixed by extending `_isNotNullCheckFor()` to recurse into `BinaryExpression`
nodes whose operator is `&&`, checking both operands — every conjunct of an
`&&` must hold to reach the then-branch, so a guard anywhere in the chain is
as valid as a bare guard. Recursion is deliberately NOT extended to `||`:
an OR does not guarantee any specific operand held, so it cannot prove
non-null. Rule bumped to v7 (DartDoc, `LintCode` message, and version
comment all updated together per single-source-of-truth).

Finding 1 (RegExpMatch group guaranteed by pattern, `health_summary.dart:51`)
is NOT addressed by this fix — it is a structurally different problem
(reasoning about regex capture-group guarantees, not control-flow guards)
and was split out to a new bug file:
`bugs/avoid_nullable_interpolation_false_positive_regexpmatch_group_guaranteed_by_pattern.md`.

### Verification

Added a GOOD fixture case (`_ChurnFile` / `_goodCompoundAndGuard`) to
`example/lib/type/avoid_nullable_interpolation_fixture.dart` reproducing
the `ai_fix_handoff.dart:101` shape. Verified via the scan CLI with
`--resolve` (type resolution is required for this rule; the default fast
syntactic parse never fires it):

```
dart run saropa_lints scan example --tier comprehensive \
  --files lib/type/avoid_nullable_interpolation_fixture.dart \
  --include-globs "**/example/**" --resolve --format json
```

Result: `avoid_nullable_interpolation` fires exactly twice (the file's two
BAD cases, lines 113 and 194) and does not fire on the new compound-guard
GOOD case or any other existing GOOD case in the fixture — no regression,
false positive eliminated.

The existing Dart unit test (`test/rules/data/type_rules_test.dart`) is an
instantiation pin only and was not extended; it does not exercise rule
logic.
