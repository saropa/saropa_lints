# Not Viable: `avoid_drift_downgrade`

## Status: NOT VIABLE

## Proposed Rule
Warn when database code could allow a schema version downgrade.

## Why Not Viable
**Drift already throws on downgrades.** Since step-by-step migrations were introduced, Drift automatically detects when the stored schema version is higher than the declared `schemaVersion` and throws an error. Previous versions caused silent `user_version` corruption, but this has been fixed in the library itself. A lint rule would duplicate runtime protection that already exists.

## Category
Redundant — library-enforced constraint.
