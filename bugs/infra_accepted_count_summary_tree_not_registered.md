# "N accepted" in the Summary tree cannot be seen

**Status: Open, human check**

From `plans/history/2026.11/2026.11.26/accepted_findings_f5_translations_and_baseline_date.md`.

The Summary tree is not registered as a view, so the accepted count it would show is never visible.

Ruling: no new surface. The Rule Packs "Suppressions (export)" strip is the surface for the accepted count.

Done: the strip and the OWASP report list the `accepted` kind. `summaryTree.ts` is unchanged.

Remaining: human check, step 29 of `bugs/human/ACCEPTED_FINDINGS_AND_BASELINE_CHECKS_OWNER_STEPS.md`.

## Finish Report (2026-11-27)

Code is done: the Rule Packs "Suppressions (export)" strip shows `accepted` in its per-kind breakdown (`extension/src/views/lintsConfigDashboardMirrors.ts`), and the OWASP report lists an `accepted` row (`extension/src/owaspExport.ts`). Mocha tests for both pass. Typechecks pass.

Unverified on screen: no Extension Development Host run, no screenshot. The strip is a deliberate visual change (new `accepted N` item). Remaining: human F5 check of the strip in light and dark themes, step 29 of `bugs/human/ACCEPTED_FINDINGS_AND_BASELINE_CHECKS_OWNER_STEPS.md`. Status stays Open, human check.
