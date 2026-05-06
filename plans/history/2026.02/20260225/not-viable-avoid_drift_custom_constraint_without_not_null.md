# Not Viable: `avoid_drift_custom_constraint_without_not_null`

## Status: NOT VIABLE

## Proposed Rule
Warn when `customConstraint()` is used without including `NOT NULL` in the constraint string.

## Why Not Viable
**Too niche and targets advanced users who understand the trade-off.** `customConstraint()` intentionally overrides the default `NOT NULL` constraint. Developers using this API are power users who need to specify exact SQL constraints. Flagging it would:
- Annoy advanced users who deliberately want nullable columns via custom constraints.
- Not help beginners who rarely use `customConstraint()` at all.
- Have high false-positive rate since many custom constraints intentionally omit `NOT NULL`.

## Category
Too niche — advanced API used deliberately.
