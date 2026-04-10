# Discussion 062: False Positive Reduction — Completed

**Summary:** Full audit completed 2026-03-01. All rule files in `lib/src/rules/` were refactored to remove dangerous `.contains()` usage on typeName, bodySource, targetSource, methodName, etc. Replaced with word-boundary `RegExp`, `isFieldCleanedUp`/`isExactTarget` from `target_matcher_utils`, or exact-set checks. `test/anti_pattern_detection_test.dart` baseline (`_baselineCounts`) is empty; any new dangerous `.contains()` in rule code fails CI. Publish script reports status via `scripts/modules/_audit_checks.py` (get_contains_audit_status) and blocks publish if any file exceeds baseline.

**Archived:** 2026-03-01
