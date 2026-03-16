import { FlaggedIssue } from '../types';

interface SignalPattern {
    readonly pattern: RegExp;
    readonly signal: string;
}

/** Keyword patterns matched case-insensitively against issue titles. */
const TITLE_SIGNALS: readonly SignalPattern[] = [
    { pattern: /\bdeprecated?\b/i, signal: 'deprecated' },
    { pattern: /\bobsolete\b/i, signal: 'obsolete' },
    { pattern: /\bend[- ]?of[- ]?life\b/i, signal: 'end-of-life' },
    { pattern: /\bbreaking\s+change\b/i, signal: 'breaking change' },
    { pattern: /\bbuild\s+fail/i, signal: 'build failure' },
    { pattern: /\bcompilation?\s+(?:error|fail)/i, signal: 'compile error' },
    { pattern: /\bincompat(?:ible|ibility)\b/i, signal: 'incompatible' },
    { pattern: /\bnull[- ]?safety\b/i, signal: 'null safety' },
    { pattern: /\bdart\s*[3-9]\b/i, signal: 'dart version' },
    { pattern: /\bflutter\s*[4-9]\b/i, signal: 'flutter version' },
    { pattern: /\bjava\s*(?:8|1[.]8|version)\b/i, signal: 'java version' },
    { pattern: /\bandroid\s*(?:api|sdk)\s*\d/i, signal: 'android sdk' },
    { pattern: /\bgradle\b/i, signal: 'gradle' },
    { pattern: /\bcrash(?:es|ing)?\b/i, signal: 'crash' },
    { pattern: /\bmemory\s+leak\b/i, signal: 'memory leak' },
    { pattern: /\bimpeller\b/i, signal: 'impeller' },
];

/** GitHub label names that indicate high-signal issues. */
const LABEL_SIGNALS: readonly string[] = [
    'breaking', 'breaking-change', 'deprecated', 'deprecation',
    'critical', 'blocker', 'regression',
];

/** Raw open issue shape from the GitHub API. */
export interface RawOpenIssue {
    readonly number: number;
    readonly title: string;
    readonly labels: readonly (string | { readonly name?: string })[];
    readonly comments: number;
}

/** Detect signal keywords in an issue title and labels. */
export function detectIssueSignals(
    title: string,
    labels: readonly string[],
): string[] {
    const signals: string[] = [];
    for (const { pattern, signal } of TITLE_SIGNALS) {
        if (pattern.test(title)) { signals.push(signal); }
    }
    for (const label of labels) {
        const lower = label.toLowerCase();
        if (LABEL_SIGNALS.includes(lower)) {
            signals.push(`label:${lower}`);
        }
    }
    return [...new Set(signals)];
}

/** Extract label names from GitHub's mixed label format. */
function extractLabelNames(
    labels: readonly (string | { readonly name?: string })[],
): string[] {
    return labels.map(
        l => typeof l === 'string' ? l : l.name ?? '',
    ).filter(Boolean);
}

/** Filter raw open issues to only those with high-signal matches. */
export function flagHighSignalIssues(
    rawIssues: readonly RawOpenIssue[],
    repoHtmlUrl: string,
): FlaggedIssue[] {
    const flagged: FlaggedIssue[] = [];
    for (const issue of rawIssues) {
        const labels = extractLabelNames(issue.labels);
        const signals = detectIssueSignals(issue.title, labels);
        if (signals.length === 0) { continue; }
        flagged.push({
            number: issue.number,
            title: issue.title,
            url: `${repoHtmlUrl}/issues/${issue.number}`,
            matchedSignals: signals,
            commentCount: issue.comments,
        });
    }
    return flagged;
}
