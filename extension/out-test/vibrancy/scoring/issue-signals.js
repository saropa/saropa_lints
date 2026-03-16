"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.detectIssueSignals = detectIssueSignals;
exports.flagHighSignalIssues = flagHighSignalIssues;
/** Keyword patterns matched case-insensitively against issue titles. */
const TITLE_SIGNALS = [
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
const LABEL_SIGNALS = [
    'breaking', 'breaking-change', 'deprecated', 'deprecation',
    'critical', 'blocker', 'regression',
];
/** Detect signal keywords in an issue title and labels. */
function detectIssueSignals(title, labels) {
    const signals = [];
    for (const { pattern, signal } of TITLE_SIGNALS) {
        if (pattern.test(title)) {
            signals.push(signal);
        }
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
function extractLabelNames(labels) {
    return labels.map(l => typeof l === 'string' ? l : l.name ?? '').filter(Boolean);
}
/** Filter raw open issues to only those with high-signal matches. */
function flagHighSignalIssues(rawIssues, repoHtmlUrl) {
    const flagged = [];
    for (const issue of rawIssues) {
        const labels = extractLabelNames(issue.labels);
        const signals = detectIssueSignals(issue.title, labels);
        if (signals.length === 0) {
            continue;
        }
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
//# sourceMappingURL=issue-signals.js.map