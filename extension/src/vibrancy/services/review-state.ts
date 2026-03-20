import * as vscode from 'vscode';
import { ReviewEntry, ReviewStatus } from '../types';

const STATE_KEY = 'spv.reviewState';

/** Keyed by "{packageName}:{currentVersion}" so reviews auto-invalidate on upgrade. */
interface StoredState {
    readonly entries: Record<string, readonly ReviewEntry[]>;
}

/**
 * Persistent triage state for version-gap PRs/issues.
 * Stored per workspace so each project tracks its own reviews.
 */
export class ReviewStateService {
    constructor(private readonly _state: vscode.Memento) {}

    /** Get all review entries for a package at a specific version. */
    getReviews(packageName: string, currentVersion: string): readonly ReviewEntry[] {
        const stored = this._getStored();
        return stored.entries[makeKey(packageName, currentVersion)] ?? [];
    }

    /** Set the review status for a single version-gap item. */
    async setReview(
        packageName: string,
        currentVersion: string,
        itemNumber: number,
        status: ReviewStatus,
        notes?: string,
    ): Promise<void> {
        const stored = this._getStored();
        const key = makeKey(packageName, currentVersion);
        const existing = [...(stored.entries[key] ?? [])];

        const idx = existing.findIndex(e => e.itemNumber === itemNumber);
        const entry: ReviewEntry = {
            packageName,
            itemNumber,
            status,
            notes: notes ?? (idx >= 0 ? existing[idx].notes : ''),
            updatedAt: new Date().toISOString(),
        };

        if (idx >= 0) {
            existing[idx] = entry;
        } else {
            existing.push(entry);
        }

        await this._setStored({
            entries: { ...stored.entries, [key]: existing },
        });
    }

    /** Get summary counts for a package at a specific version. */
    getSummary(
        packageName: string,
        currentVersion: string,
        totalItems: number,
    ): ReviewSummary {
        const reviews = this.getReviews(packageName, currentVersion);
        const reviewed = reviews.filter(r => r.status === 'reviewed').length;
        const applicable = reviews.filter(r => r.status === 'applicable').length;
        const notApplicable = reviews.filter(r => r.status === 'not-applicable').length;
        const triaged = reviewed + applicable + notApplicable;

        return {
            total: totalItems,
            triaged,
            reviewed,
            applicable,
            notApplicable,
            unreviewed: totalItems - triaged,
        };
    }

    /** Clear all reviews for a package (e.g., when version changes). */
    async clearPackage(
        packageName: string,
        currentVersion: string,
    ): Promise<void> {
        const stored = this._getStored();
        const key = makeKey(packageName, currentVersion);
        if (!(key in stored.entries)) { return; }

        const copy = { ...stored.entries };
        delete copy[key];
        await this._setStored({ entries: copy });
    }

    /** Remove review entries for packages whose version has changed. */
    async pruneStale(
        currentVersions: ReadonlyMap<string, string>,
    ): Promise<number> {
        const stored = this._getStored();
        let pruned = 0;
        const kept: Record<string, readonly ReviewEntry[]> = {};

        for (const [key, entries] of Object.entries(stored.entries)) {
            const { packageName, version } = parseKey(key);
            const current = currentVersions.get(packageName);
            // Keep only if the version still matches what the user has
            if (current === version) {
                kept[key] = entries;
            } else {
                pruned += entries.length;
            }
        }

        if (pruned > 0) {
            await this._setStored({ entries: kept });
        }
        return pruned;
    }

    private _getStored(): StoredState {
        return this._state.get<StoredState>(STATE_KEY) ?? { entries: {} };
    }

    private async _setStored(state: StoredState): Promise<void> {
        await this._state.update(STATE_KEY, state);
    }
}

export interface ReviewSummary {
    readonly total: number;
    readonly triaged: number;
    readonly reviewed: number;
    readonly applicable: number;
    readonly notApplicable: number;
    readonly unreviewed: number;
}

function makeKey(packageName: string, version: string): string {
    return `${packageName}:${version}`;
}

function parseKey(key: string): { packageName: string; version: string } {
    const idx = key.lastIndexOf(':');
    return {
        packageName: key.slice(0, idx),
        version: key.slice(idx + 1),
    };
}
