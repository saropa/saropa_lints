# PROPOSAL: `avoid_wildcard_cases_with_enums` — Size threshold for large enums

**Status: Fixed — hardcoded threshold of 20, proper EnumElement resolution**

Created: 2026-08-28
Type: Rule modification
Related rules: `avoid_wildcard_cases_with_enums`

---

## Summary

The rule enforces exhaustive case listing for all enum switches, but for enums
with 20+ members (some in the downstream project have 100-200+ values), a
`default:` catch-all is the correct design choice. Exhaustive listing of 90+
irrelevant cases is unmaintainable and obscures the intent — the switch cares
about a small subset and groups everything else. The rule should either skip
enums above a configurable size threshold or be moved to an optional tier for
large-enum contexts.

Downstream suppression count: **31** (100% design-limitation rate in sample of 6).

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_wildcard_cases_with_enums'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_control_flow_rules.dart:210:    'avoid_wildcard_cases_with_enums',
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_control_flow_rules.dart:210`

---

## Motivation

Every suppressed site in the downstream project follows the same pattern: a
switch on a large enum (`ActivityType` ~100 values, `CountryCode` ~250 values,
`LocaleEnum` ~2000+ values) where only 5-15 cases are meaningful and the rest
map to a single default behavior. Exhaustively listing all remaining cases:

1. **Obscures intent** — the reader must scan 90+ `case Foo: case Bar:` lines
   to find the meaningful ones.
2. **Creates maintenance burden** — every new enum member requires updating
   every switch that touches the enum, even when the switch has no opinion on
   the new value.
3. **Defeats the purpose of `default:`** — Dart's `default` exists precisely
   for this pattern.

The rule is valuable for small enums (3-15 members) where exhaustive handling
prevents missed cases. The proposal is to preserve that value while exempting
large enums where `default:` is the right tool.

---

## Detection / Behavior

### Should flag (small enum, catch-all hides a likely bug)

```dart
enum Status { pending, active, inactive, deleted }

String label(Status s) {
  switch (s) {
    case Status.pending:
      return 'Pending';
    case Status.active:
      return 'Active';
    default: // LINT — only 2 of 4 cases handled, likely a bug
      return 'Unknown';
  }
}
```

### Should pass (large enum, intentional grouping)

```dart
enum ActivityType { /* ~100 members */ }

String channelLabel(ActivityType type) {
  switch (type) {
    case ActivityType.PhoneCall:
      return 'Phone';
    case ActivityType.ViberText:
      return 'Viber';
    // ... 8 more phone-bound channels
    default: // OK — 90+ non-phone types intentionally grouped
      return 'Other';
  }
}
```

---

## Proposed Tier

Current tier: keep as-is for enums with ≤20 members.
For enums with >20 members: move to **Pedantic** (or suppress entirely).

Justification: exhaustive case enforcement on large enums creates more noise
than value. The crossover point is roughly where the unhandled cases outnumber
the handled ones by 3:1 or more.

---

## Edge Cases

1. **Enum with 20 members, 18 handled** — should still flag (only 2 missing, likely a bug). Threshold should be based on enum SIZE, not coverage ratio.
2. **Enum with 25 members, all handled except default** — borderline; threshold of 20-30 would suppress this. Acceptable trade-off.
3. **Sealed class hierarchies** — not enums, out of scope for this rule.
4. **Enums that grow over time** — a small enum today may become large; the threshold handles this automatically.

---

## Approved Approach

**Configurable threshold with sensible default.** The rule suppresses the
diagnostic when the enum has more members than the threshold. Default: **20**.

Configuration via `analysis_options.yaml`:
```yaml
saropa_lints:
  avoid_wildcard_cases_with_enums:
    max_enum_size: 20  # default; enums larger than this allow default:
```

## Alternatives Considered

1. **Coverage ratio instead of size threshold** — e.g., suppress when <50% of cases are handled. Rejected: harder to reason about, and a 100-member enum with 40 cases handled is still unreadable.
2. **Annotation-based opt-out** — e.g., `@exhaustive` on the enum. Rejected: requires modifying the enum definition, which may be in a dependency.
3. **Hardcoded threshold** — simpler but inflexible. User requested configurable.

---

## Environment

- saropa_lints version: 15.2.4
- Dart SDK version: 3.13.1
- Triggering project: `contacts` (d:\src\contacts)
- Downstream suppression count: 31 sites
