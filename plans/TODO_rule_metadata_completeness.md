# TODO — Rule metadata completeness residuals

**Created:** 2026-06-12
**Split from:** `OUTSTANDING_ITEMS_AUDIT.md` §4 (audit archived to `history/2026.06/2026.06.12/`)
**Subsystem:** rule metadata schema + lifecycle
**Source plan:** `history/2026.04/2026.04.28/PLAN_RULE_METADATA_AND_QUALITY.md`

The metadata schema, CWE/OWASP mapping, per-rule CI threshold gate
([bin/quality_gate.dart](../bin/quality_gate.dart)), and baseline comparison
([bin/baseline.dart](../bin/baseline.dart), [bin/diagnostic_baseline.dart](../bin/diagnostic_baseline.dart))
all shipped. These are the gaps.

## Status legend
- **[OPEN — verified]** getter exists, populated nowhere — confirmed in the 2026-06-11 audit.
- **[OPEN — needs per-item confirm]** triage against code before treating as done.

---

## 4.1 `accuracyTarget` null for every rule **[OPEN — verified — consumer-gated]**

The getter exists; nothing populates it. Intentional until an audit/report consumes it.

Action: do **not** bulk-populate speculatively. Populate only when a consumer (a quality report or
gate that reads `accuracyTarget`) is built — populate as part of that consumer's work.

## 4.2 `certIds` sparse/empty **[OPEN — verified — by design]**

By design. Populate per-rule where a clear CERT/CWE mapping exists.

Action: opportunistic — when touching a security rule with an obvious CERT/CWE id, add it. No bulk
backfill pass warranted on its own.

## 4.3 Rule-lifecycle enforcement **[OPEN — needs per-item confirm]**

`RuleStatus` (ready / beta / deprecated) enum exists. Unconfirmed whether the enforcement is wired
end to end.

Action: confirm before building —
1. Is `beta` gating actually applied through rule init / profiles (beta rules excluded unless opted in)?
2. Are `deprecated` rules excluded from active profiles?
If either is not wired, that wiring is the work. If both are wired, mark this done.
