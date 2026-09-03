# PROPOSAL: Flag DST-Unsafe `DateTime` Arithmetic

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_dst_unsafe_date_arithmetic` to flag `DateTime` arithmetic that adds/subtracts a fixed `Duration`
of a day or more to a local (non-UTC) `DateTime` — e.g. `date.add(Duration(days: 1))` — when the intent is
calendar-day arithmetic. `Duration` addition is wall-clock-duration math, not calendar math: on a
daylight-saving-time transition day, adding `Duration(days: 1)` to a local `DateTime` can land 23 or 25 hours
later rather than "the same time tomorrow," silently producing an off-by-one-hour (or occasionally
off-by-one-day-boundary) result.

**Closes gap:** `many_lints` `avoid_dst_unsafe_date_arithmetic` (github.com/... many_lints). Implementing
this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

This is a genuinely subtle, high-value correctness bug class: `DateTime(2026, 3, 8, 9).add(Duration(days:
1))` in a DST-observing timezone can produce 8:00 or 10:00 the next day instead of 9:00, because
`Duration`-based addition operates on elapsed wall-clock time, not calendar semantics. Developers reaching
for `.add(Duration(days: n))` to mean "n calendar days later" is extremely common and the bug is invisible in
testing unless the test specifically straddles a DST transition date — exactly the kind of latent,
low-frequency, high-confusion bug a static check is well suited to catch that manual review reliably misses.

---

## Detection / Behavior

### Should flag (bad code)

```dart
final tomorrow = appointment.add(const Duration(days: 1)); // LINT — avoid_dst_unsafe_date_arithmetic: Duration-days arithmetic on a local DateTime is DST-unsafe
```

### Should pass (good code)

```dart
// Calendar-correct: reconstruct the DateTime from calendar fields instead of duration math.
final tomorrow = DateTime(
  appointment.year,
  appointment.month,
  appointment.day + 1,
  appointment.hour,
  appointment.minute,
); // OK — calendar-day arithmetic, DST-safe

// Or: arithmetic performed in UTC, where there is no DST transition to cross.
final tomorrowUtc = appointment.toUtc().add(const Duration(days: 1)).toLocal(); // OK
```

---

## Proposed Tier

Tier: Recommended
Justification: Real, easy-to-hit correctness bug with a clear fix pattern and low false-positive risk (the
rule only needs to detect `Duration(days:...)`-or-larger addition/subtraction on a non-UTC `DateTime`);
matches the severity of saropa's other date/time correctness rules.

---

## Edge Cases

1. **Arithmetic on a `DateTime.utc(...)` value or after `.toUtc()`** — should pass; UTC has no DST
   transitions, so `Duration`-based day arithmetic is safe there.
2. **`Duration(hours: n)` / `Duration(minutes: n)` additions** — should pass; sub-day durations are
   legitimately wall-clock-duration math (e.g. "30 minutes from now" genuinely means 30 elapsed minutes, DST
   crossing included), not calendar-day arithmetic — only day-or-larger `Duration` components should trigger.
3. **A `Duration` value built from a variable rather than a literal** (`date.add(someDuration)`) where the
   variable's value can't be statically confirmed to be day-granularity — needs discussion; likely still flag
   if the variable's declared/inferred type or naming strongly suggests day-scale, otherwise this may need to
   stay literal-only to keep false positives low.
4. **Timezone-aware third-party types** (`package:timezone`'s `TZDateTime`) — should pass if the package
   already handles DST correctly internally; scope detection to Dart core `DateTime` only unless a specific
   third-party type is confirmed to have the same footgun.

---

## Alternatives Considered

- **Flag all `Duration`-based arithmetic regardless of magnitude** — rejected; sub-day durations are
  legitimately wall-clock math in almost all real usage (timers, timeouts, "N minutes from now"), so
  restricting to day-or-larger components keeps the signal-to-noise ratio high.

---

## Decision

---

## Implementation Notes

---

## Commits
