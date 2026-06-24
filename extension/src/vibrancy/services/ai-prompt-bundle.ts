/**
 * Builds a ready-to-paste prompt that hands an AI everything it needs to decide
 * whether a package's new features fit THIS project — the semantic step the
 * heuristic miner (`changelog-opportunities`) deliberately cannot do.
 *
 * The prompt bundles three things the consuming AI would otherwise have to be
 * given separately: the classified changelog delta, the project's actual call
 * sites (file:line), and a task instruction that encodes the review discipline
 * (read the real API, reject decorative-only changes, answer per call site).
 *
 * Pure: string/data in, string out. No `vscode` import — fully unit-testable.
 */

import { PackageOpportunities } from './changelog-opportunities';
import { PackageUsage } from './import-scanner';

/** Inputs for one package's AI prompt bundle. */
export interface AiPromptInputs {
    readonly packageName: string;
    readonly currentVersion: string;
    readonly latestVersion: string;
    readonly opportunities: PackageOpportunities;
    /** Active (non-commented) source usages of the package. */
    readonly fileUsages: readonly PackageUsage[];
}

// Bound the call-site list so a package imported in hundreds of files does not
// produce a multi-thousand-line prompt. Truncation is disclosed in-text (never
// silent) so the AI knows the list is partial.
const MAX_FILE_SITES = 25;

/**
 * Build the prompt, or return `null` when there is nothing to adopt
 * (no opportunities) — callers use null to hide the "Copy for AI" button
 * rather than offer an empty bundle.
 */
export function buildAiPromptBundle(inputs: AiPromptInputs): string | null {
    const { opportunities } = inputs;
    if (opportunities.opportunityCount === 0) { return null; }

    return [
        buildHeader(inputs),
        '',
        ...buildOpportunitySection(opportunities),
        '',
        ...buildUsageSection(inputs),
        '',
        ...buildTaskSection(inputs.packageName),
    ].join('\n');
}

function buildHeader(inputs: AiPromptInputs): string {
    const { packageName, currentVersion, latestVersion } = inputs;
    // Up-to-date packages are the subtle case: there is no version to bump, but
    // features added across releases a caret constraint carried you through may
    // never have been adopted. Frame the task as "use what you already have",
    // not "upgrade".
    if (currentVersion === latestVersion) {
        return `You are already on the latest version of the Dart package `
            + `\`${packageName}\` (${currentVersion}), but may not be using `
            + `everything it offers.`;
    }
    return `You are upgrading the Dart package \`${packageName}\` `
        + `from ${currentVersion} → ${latestVersion}.`;
}

/** "What's new" — one line per opportunity, with extracted API names. */
function buildOpportunitySection(opp: PackageOpportunities): string[] {
    const lines = ['## New since your version (heuristic-classified)'];
    for (const bullet of opp.opportunities) {
        const api = bullet.apiNames.length > 0
            ? ` — API: ${bullet.apiNames.join(', ')}`
            : '';
        lines.push(`- [${bullet.category}] ${bullet.text}${api}`);
    }
    return lines;
}

/** "How this project uses it" — the call sites the AI maps features onto. */
function buildUsageSection(inputs: AiPromptInputs): string[] {
    const { fileUsages, opportunities } = inputs;

    if (fileUsages.length === 0) {
        return [
            '## How this project uses the package',
            'Not imported in any scanned source file (dev-only or transitive '
            + 'dependency). New features likely do not apply to project code.',
        ];
    }

    const shown = fileUsages.slice(0, MAX_FILE_SITES);
    const lines = [
        `## How this project uses the package (${fileUsages.length} files)`,
        ...shown.map(u => `- ${u.filePath}:${usageLine(u)}`),
    ];
    if (fileUsages.length > shown.length) {
        lines.push(`- … and ${fileUsages.length - shown.length} more files`);
    }
    if (opportunities.apiNames.length > 0) {
        lines.push(`Symbols named in the changelog: `
            + opportunities.apiNames.join(', '));
    }
    return lines;
}

/** Prefer the import directive line; fall back to export, then primary line. */
function usageLine(u: PackageUsage): number {
    return u.importLine ?? u.exportLine ?? u.line;
}

/** The task instruction that encodes the review discipline. */
function buildTaskSection(packageName: string): string[] {
    return [
        '## Task',
        `For each new feature above, decide whether it fits an existing call `
        + `site in this project. Read the real \`${packageName}\` API before `
        + `recommending — do not assume behavior from the changelog wording. `
        + `Reject decorative-only changes that do not clarify a state `
        + `transition. Output per feature: \`file:line → concrete change\`, or `
        + `"no fit" with one reason.`,
    ];
}
