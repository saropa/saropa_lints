/**
 * Visible-but-non-scoring lifecycle notes.
 *
 * These surface signals that must NOT change the health category (see the
 * precedence comment in status-classifier.ts) but that the user should see in
 * hover / detail alerts:
 *  - a curated end_of_life entry contradicted by fresh live pub.dev data
 *  - maintenance_mode / caution known-issue statuses (never categories)
 *  - unlisted packages on pub.dev
 */

import { VibrancyResult } from '../types';
import { l10n } from '../../i18n/runtime';
import { effectiveIssueStatus } from './known-issues';

export type LifecycleNoteKind =
    'status-may-be-outdated' | 'maintenance-mode' | 'caution' | 'unlisted';

export interface LifecycleNote {
    readonly kind: LifecycleNoteKind;
    readonly text: string;
}

/** A publish within this many days counts as "actively released". */
export const RECENT_PUBLISH_DAYS = 365;

/** True when an ISO date is within `days` of `now`. Invalid/empty is false. */
function isRecent(iso: string | undefined, days: number, now: number): boolean {
    if (!iso) { return false; }
    const t = Date.parse(iso);
    if (Number.isNaN(t)) { return false; }
    return now - t <= days * 86_400_000;
}

/**
 * True when a curated UNSCOPED end_of_life entry is contradicted by live data:
 * pub.dev says not discontinued and the latest release is under 12 months old.
 * Scoped entries are excluded (they are about an old major, not the package).
 */
export function isEolStatusPossiblyStale(r: VibrancyResult, now = Date.now()): boolean {
    const ki = r.knownIssue;
    if (!ki || ki.status !== 'end_of_life' || effectiveIssueStatus(ki) !== 'end_of_life') { return false; }
    const pd = r.pubDev;
    if (!pd || pd.isDiscontinued) { return false; }
    return isRecent(pd.publishedDate, RECENT_PUBLISH_DAYS, now);
}

/** Collect lifecycle notes for a result (empty when none apply). */
export function getLifecycleNotes(r: VibrancyResult, now = Date.now()): LifecycleNote[] {
    const notes: LifecycleNote[] = [];
    if (isEolStatusPossiblyStale(r, now)) {
        notes.push({ kind: 'status-may-be-outdated', text: l10n('lifecycle.note.statusMayBeOutdated') });
    }
    const status = r.knownIssue?.status;
    if (status === 'maintenance_mode') {
        notes.push({ kind: 'maintenance-mode', text: l10n('lifecycle.note.maintenanceMode') });
    } else if (status === 'caution') {
        notes.push({ kind: 'caution', text: l10n('lifecycle.note.caution') });
    }
    if (r.pubDev?.isUnlisted) {
        notes.push({ kind: 'unlisted', text: l10n('lifecycle.note.unlisted') });
    }
    return notes;
}
