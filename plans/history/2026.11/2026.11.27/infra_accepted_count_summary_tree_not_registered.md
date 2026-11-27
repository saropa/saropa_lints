# "N accepted" in the Summary tree cannot be seen

**Status: Closed** (owner order, 2026-11-27)

Not verified:

- Screen checks: never run (no Extension Development Host run, no screenshot).
- macOS `baseline: date:`: pending the first run of the `test-macos` CI job.
- Translations: no native-speaker review.

From `plans/history/2026.11/2026.11.26/accepted_findings_f5_translations_and_baseline_date.md`.

The Summary tree is not registered as a view, so the accepted count it would show is never visible.

Ruling: no new surface. The Rule Packs "Suppressions (export)" strip is the surface for the accepted count.

Done: the strip and the OWASP report list the `accepted` kind. `summaryTree.ts` is unchanged.

Remaining: human check, step 4 of `plans/history/2026.11/2026.11.27/accepted_findings_and_baseline_checks_owner_steps.md`.

## Finish Report (2026-11-27)

Code is done: the Rule Packs "Suppressions (export)" strip (`extension/src/views/configDashboardSuppressionsStrip.ts`) lists every kind in the export, `accepted` included, and the OWASP report lists an `accepted` row (`extension/src/owaspExport.ts`).

Correction: `extension/src/views/lintsConfigDashboardMirrors.ts`, cited earlier as the strip, has no production caller. The real strip needed no change to show `accepted` and shows it in 17.10.0 too. The unused module is left in place.

Automated (mocha, passing): the strip with accepted entries (order and total), no export, zero and missing aggregate, no by-kind breakdown, escaping, and a `violations.json` read from disk through the disabled-rule filter. The strip test was not registered in `tsconfig.test.json` and never ran; it is registered now. Translated empty-state lines are now HTML-escaped.

Fixed before closing: the word "Total" in the strip is localized (`suppressionsStrip.total`, hand-written in all locales).

Unverified on screen: no Extension Development Host run, no screenshot. Remaining: human F5 check of the strip in light and dark themes, step 4 of `plans/history/2026.11/2026.11.27/accepted_findings_and_baseline_checks_owner_steps.md`. Status stays Open, human check.
