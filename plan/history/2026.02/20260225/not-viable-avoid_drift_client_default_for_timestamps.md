# Not Viable: `avoid_drift_client_default_for_timestamps`

## Status: NOT VIABLE

## Proposed Rule
Warn when `clientDefault(() => DateTime.now())` is used instead of `withDefault(currentDateAndTime)` for timestamp columns.

## Why Not Viable
**This is a valid design choice, not a bug.** `clientDefault` computes the value in Dart at insert time, while `withDefault` computes it in SQL. Both are correct depending on context:
- `clientDefault` is needed when the timestamp should reflect the Dart runtime clock (e.g., for local timezone awareness).
- `withDefault` is appropriate for server-canonical timestamps.

Flagging one over the other would produce false positives for legitimate use cases.

## Category
Design choice — no single correct pattern.
