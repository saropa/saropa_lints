# Not Viable: `prefer_drift_modular_generation`

## Status: NOT VIABLE

## Proposed Rule
Suggest using modular code generation (`*.drift.dart`) instead of shared `*.g.dart` files.

## Why Not Viable
**Project preference, not a bug.** Both generation modes are valid:
- `*.g.dart` (shared) is simpler for small projects with few tables.
- `*.drift.dart` (modular) prevents name collisions in large projects.

The choice depends on project size and team preference. Flagging one over the other would produce false positives and annoy users with smaller projects where modular generation adds unnecessary complexity.

## Category
Design choice — no single correct pattern.
