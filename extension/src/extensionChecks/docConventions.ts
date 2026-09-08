/**
 * Directory names shared between `bugArchivalCheck.ts` (flags a *closed*
 * report left in the open-issues directory) and `docPlacementCheck.ts`
 * (flags *open* work left in the archive directory) — the two are mirror
 * images of the same open/closed doc-placement convention, so a rename of
 * either directory only needs to happen in one place.
 */

/** Directory a closed report should be archived to (e.g. `plans/history/YYYY.MM/YYYYMMDD/`). */
export const ARCHIVE_DIR = 'plans/history';

/** Directory an open report/proposal belongs in while still unresolved. */
export const OPEN_ISSUES_DIR = 'bugs';
