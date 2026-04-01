/**
 * Single source of truth for all vibrancy category display metadata.
 *
 * Every UI surface (tree items, CodeLens, reports, comparison views,
 * diagnostics) should read labels, emojis, grades, etc. from here
 * instead of maintaining its own switch/map.
 */

import { VibrancyCategory } from './types';

/** Letter grade for compact UI: A (best) through F (dangerous). D reserved for future use. */
export type VibrancyGrade = 'A' | 'B' | 'C' | 'D' | 'E' | 'F';

/** Display metadata for a single vibrancy category. */
export interface CategoryDisplayData {
    /** Full human-readable label, e.g. "End of Life". */
    readonly label: string;
    /** Short label for tight spaces, e.g. "EOL". Same as label when no abbreviation exists. */
    readonly shortLabel: string;
    /** Default colored-circle emoji. Users can override via indicator config. */
    readonly emoji: string;
    /** Single-letter grade for tree items. A=best, F=worst. */
    readonly grade: VibrancyGrade;
    /** VS Code ThemeIcon id (e.g. 'pass', 'warning', 'error'). */
    readonly iconId: string;
    /** DiagnosticSeverity numeric value: 1=Error, 2=Warning, 3=Information. */
    readonly severity: number;
    /** CSS class name used in webview HTML. */
    readonly cssClass: string;
}

/** All category display data, keyed by the canonical VibrancyCategory value. */
export const CATEGORY_DICTIONARY: Readonly<Record<VibrancyCategory, CategoryDisplayData>> = {
    'vibrant': {
        label: 'Vibrant',
        shortLabel: 'Vibrant',
        emoji: '🟢',
        grade: 'A',
        iconId: 'pass',
        severity: 3,
        cssClass: 'vibrant',
    },
    'stable': {
        label: 'Stable',
        shortLabel: 'Stable',
        emoji: '🟡',
        grade: 'B',
        iconId: 'info',
        severity: 3,
        cssClass: 'stable',
    },
    'outdated': {
        label: 'Outdated',
        shortLabel: 'Outdated',
        emoji: '🟠',
        grade: 'C',
        iconId: 'warning',
        severity: 2,
        cssClass: 'outdated',
    },
    'abandoned': {
        label: 'Abandoned',
        shortLabel: 'Abandoned',
        emoji: '🟠',
        grade: 'E',
        iconId: 'warning',
        severity: 2,
        cssClass: 'abandoned',
    },
    'end-of-life': {
        label: 'End of Life',
        shortLabel: 'EOL',
        emoji: '🔴',
        grade: 'F',
        iconId: 'error',
        severity: 1,
        cssClass: 'eol',
    },
};

/** Convenience: get a single field from the dictionary. */
export function categoryLabel(category: VibrancyCategory): string {
    return CATEGORY_DICTIONARY[category].label;
}

export function categoryIcon(category: VibrancyCategory): string {
    return CATEGORY_DICTIONARY[category].iconId;
}

export function categoryToSeverity(category: VibrancyCategory): number {
    return CATEGORY_DICTIONARY[category].severity;
}

export function categoryToGrade(category: VibrancyCategory): VibrancyGrade {
    return CATEGORY_DICTIONARY[category].grade;
}

export function categoryEmoji(category: VibrancyCategory): string {
    return CATEGORY_DICTIONARY[category].emoji;
}

export function categoryCssClass(category: VibrancyCategory): string {
    return CATEGORY_DICTIONARY[category].cssClass;
}
