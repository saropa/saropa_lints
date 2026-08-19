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
import type { SymbolOccurrence } from './import-scanner';
import type { FlaggedIssue, VibrancyCategory } from '../types';
import type { DualDependencyRisk } from '../scoring/dual-dependency-detector';
import type { LocalReimplementation } from './local-reimplementation-detector';

/**
 * A deprecated-category changelog bullet whose named API was actually found
 * in project source. Only APIs with at least one usage reach this shape —
 * a deprecated symbol the project never calls is not a risk worth a prompt
 * line, so the caller filters those out before building the bundle.
 */
export interface DeprecatedUsage {
    readonly apiName: string;
    readonly bulletText: string;
    /** Version the deprecation was announced in. */
    readonly version: string;
    readonly usages: readonly SymbolOccurrence[];
}

/**
 * A minimal health snapshot pulled from the package's already-computed
 * `VibrancyResult`. Kept as a narrow local shape (not the full
 * `VibrancyResult`) so this module stays a pure string/data-in-string-out
 * unit the caller maps into rather than one coupled to the whole scan model.
 */
export interface PackageHealthSnapshot {
    readonly score: number;
    readonly category: VibrancyCategory;
    readonly license: string | null;
    /** pub.dev maintenance points (0-160), or null when never fetched. */
    readonly pubPoints: number | null;
    readonly vulnerabilityCount: number;
    readonly worstVulnerabilitySeverity: string | null;
    /** Curated known-issue status (e.g. "discontinued"), or null when none. */
    readonly knownIssueStatus: string | null;
    readonly knownIssueReplacement: string | null;
}

/** Inputs for one package's AI prompt bundle. */
export interface AiPromptInputs {
    readonly packageName: string;
    readonly currentVersion: string;
    readonly latestVersion: string;
    readonly opportunities: PackageOpportunities;
    /** Active (non-commented) source usages of the package. */
    readonly fileUsages: readonly PackageUsage[];
    /**
     * Deprecated APIs the project actually calls, cross-referenced against
     * project source. Absent/empty when no deprecated bullet's symbol was
     * found in use.
     */
    readonly deprecatedInUse?: readonly DeprecatedUsage[];
    /** Health/vibrancy snapshot for the package, when the scan computed one. */
    readonly health?: PackageHealthSnapshot | null;
    /** GitHub issues flagged as high-signal (breaking/deprecated/critical). */
    readonly flaggedIssues?: readonly FlaggedIssue[];
    /**
     * Set when this package is a direct dependency ALSO reachable
     * transitively through another direct dependency — a type-identity risk,
     * not a version conflict (pub always resolves to a single version).
     */
    readonly dualDependency?: DualDependencyRisk | null;
    /**
     * Project declarations (class/mixin/extension/function) whose name
     * matches something this package's own source exports — a possible
     * "delete local code, use the library" opportunity.
     */
    readonly localReimplementations?: readonly LocalReimplementation[];
}

// Bound the call-site list so a package imported in hundreds of files does not
// produce a multi-thousand-line prompt. Truncation is disclosed in-text (never
// silent) so the AI knows the list is partial.
const MAX_FILE_SITES = 25;

/**
 * Build the prompt, or return `null` when there is nothing worth surfacing —
 * no adoptable feature, no deprecated call in use, no flagged upstream issue,
 * and no known vulnerability. Callers use null to hide the "Copy for AI"
 * button rather than offer an empty bundle.
 */
export function buildAiPromptBundle(inputs: AiPromptInputs): string | null {
    const {
        opportunities, deprecatedInUse = [], health, flaggedIssues = [], dualDependency,
        localReimplementations = [],
    } = inputs;
    const hasContent = opportunities.opportunityCount > 0
        || deprecatedInUse.length > 0
        || flaggedIssues.length > 0
        || (health?.vulnerabilityCount ?? 0) > 0
        || !!dualDependency
        || localReimplementations.length > 0;
    if (!hasContent) { return null; }

    // Deprecated-in-use, local reimplementations, dual-dependency, and known
    // vulnerabilities are the sections most actionable or most likely to
    // break the project outright, so they lead — a reviewer scanning only
    // the top of the prompt still sees the highest-value facts.
    return [
        buildHeader(inputs),
        '',
        ...buildDeprecatedSection(deprecatedInUse),
        ...buildLocalReimplementationSection(inputs.packageName, localReimplementations),
        ...buildDualDependencySection(inputs.packageName, dualDependency),
        ...buildHealthSection(health),
        ...(opportunities.opportunityCount > 0
            ? buildOpportunitySection(opportunities) : []),
        '',
        ...buildFlaggedIssuesSection(flaggedIssues),
        ...buildUsageSection(inputs),
        '',
        ...buildTaskSection(inputs.packageName, deprecatedInUse.length > 0),
    ].join('\n');
}

// Bound deprecated call-site listings the same way file usages are bounded —
// a widely-used deprecated API should not itself blow out the prompt size.
const MAX_DEPRECATED_SITES = 10;

/**
 * "Deprecated APIs this project calls" — the highest-value, most
 * machine-checkable section: a deprecated symbol cross-referenced against an
 * ACTUAL call site, not just named in the changelog. Empty when nothing
 * deprecated is in use.
 */
function buildDeprecatedSection(deprecated: readonly DeprecatedUsage[]): string[] {
    if (deprecated.length === 0) { return []; }
    const lines = ['## Deprecated APIs this project calls'];
    for (const d of deprecated) {
        lines.push(`- \`${d.apiName}\` (deprecated in ${d.version}): ${d.bulletText}`);
        const sites = d.usages.slice(0, MAX_DEPRECATED_SITES);
        for (const u of sites) {
            lines.push(`  - ${u.filePath}:${u.line}`);
        }
        if (d.usages.length > sites.length) {
            lines.push(`  - … and ${d.usages.length - sites.length} more call sites`);
        }
    }
    lines.push(
        'Risk: these calls may break on the next major version. Verify a '
        + 'replacement exists before it is removed.',
    );
    lines.push('');
    return lines;
}

// Bound the reimplementation listing the same way other per-package lists
// are bounded — a common name (e.g. a generically-named local helper class)
// could otherwise match many project declarations.
const MAX_REIMPLEMENTATION_MATCHES = 10;

/**
 * "Possible local reimplementation" — project declarations whose name
 * matches something this package's own source exports. Name-only matching
 * (see `local-reimplementation-detector` for the ceiling this implies): a
 * same-named symbol with an unrelated signature still surfaces here, so the
 * task instruction asks the reader to confirm behavior, not assume it.
 */
function buildLocalReimplementationSection(
    packageName: string,
    matches: readonly LocalReimplementation[],
): string[] {
    if (matches.length === 0) { return []; }
    const lines = ['## Possible local reimplementation'];
    const shown = matches.slice(0, MAX_REIMPLEMENTATION_MATCHES);
    for (const m of shown) {
        lines.push(`- \`${m.name}\` (${m.kind}) at ${m.filePath}:${m.line}`);
    }
    if (matches.length > shown.length) {
        lines.push(`- … and ${matches.length - shown.length} more`);
    }
    lines.push(
        `Risk: the project may be reimplementing something \`${packageName}\` `
        + 'already provides, under a matching name. Confirm the package '
        + "export has the same behavior before deleting the project's own "
        + 'version — a name match is not a signature match.',
    );
    lines.push('');
    return lines;
}

/**
 * "Dual dependency risk" — this package is declared directly AND is also
 * required transitively by another direct dependency. Pub resolves to a
 * single installed version, so this is never a version conflict; the risk is
 * type identity — project code and the sibling package may each assume a
 * class from this package is "theirs", and a breaking change on either side
 * can surface without either constraint alone looking outdated.
 */
function buildDualDependencySection(
    packageName: string,
    risk: DualDependencyRisk | null | undefined,
): string[] {
    if (!risk) { return []; }
    const lines = ['## Dual dependency risk'];
    lines.push(`- Direct: ${packageName} ${risk.directConstraint} (declared in pubspec.yaml)`);
    for (const source of risk.sources) {
        const constraint = source.viaConstraint ? ` ${source.viaConstraint}` : '';
        lines.push(`- Transitive: also required by \`${source.viaPackage}\`${constraint}`);
    }
    lines.push(
        'Risk: this project imports the package directly AND depends on it '
        + 'through another direct dependency. A major version bump on either '
        + "side can diverge type identity for shared exported classes. Check "
        + "whether project code should import the shared type through the "
        + "other package's re-export instead of a separate direct import.",
    );
    lines.push('');
    return lines;
}

/**
 * "Package health" — pulled from the already-computed vibrancy scan, not
 * fetched here. Only rendered when the caller supplied a snapshot; omitted
 * entirely (not "unknown") when the scan never ran for this package.
 */
function buildHealthSection(health: PackageHealthSnapshot | null | undefined): string[] {
    if (!health) { return []; }
    const lines = ['## Package health'];
    lines.push(`- Vibrancy: ${health.category} (score ${health.score}/100)`);
    if (health.license) { lines.push(`- License: ${health.license}`); }
    if (health.pubPoints !== null) {
        lines.push(`- pub.dev maintenance points: ${health.pubPoints}/160`);
    }
    if (health.vulnerabilityCount > 0) {
        const plural = health.vulnerabilityCount === 1 ? 'y' : 'ies';
        const worst = health.worstVulnerabilitySeverity
            ? `, worst severity ${health.worstVulnerabilitySeverity}` : '';
        lines.push(`- SECURITY: ${health.vulnerabilityCount} known `
            + `vulnerabilit${plural}${worst}`);
    }
    if (health.knownIssueStatus) {
        const replacement = health.knownIssueReplacement
            ? ` — consider ${health.knownIssueReplacement}` : '';
        lines.push(`- Known issue: ${health.knownIssueStatus}${replacement}`);
    }
    lines.push('');
    return lines;
}

/**
 * "Upstream issues flagged as high-signal" — GitHub issues the scan already
 * matched against deprecation/breaking-change/crash signal patterns. Bounded
 * the same way file usages are, with disclosed truncation.
 */
const MAX_FLAGGED_ISSUES = 5;

function buildFlaggedIssuesSection(issues: readonly FlaggedIssue[]): string[] {
    if (issues.length === 0) { return []; }
    const lines = ['## Upstream issues flagged as high-signal'];
    const shown = issues.slice(0, MAX_FLAGGED_ISSUES);
    for (const issue of shown) {
        lines.push(`- #${issue.number} "${issue.title}" `
            + `(${issue.commentCount} comments) — signals: `
            + `${issue.matchedSignals.join(', ')} — ${issue.url}`);
    }
    if (issues.length > shown.length) {
        lines.push(`- … and ${issues.length - shown.length} more`);
    }
    lines.push('');
    return lines;
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

/**
 * The task instruction that encodes the review discipline.
 *
 * Deliberately asks TWO questions per feature instead of one:
 * "retrofit" (does it replace something the project does manually at an
 * existing call site — backward-looking) and "greenfield" (does it solve a
 * problem the project has but has never addressed anywhere — forward-looking).
 * The single "does it fit an existing call site" framing this replaced could
 * only ever surface retrofits, so a package's most useful new capability —
 * one that solves an unaddressed problem — was structurally invisible to it.
 */
function buildTaskSection(packageName: string, hasDeprecated: boolean): string[] {
    const lines = ['## Task'];
    if (hasDeprecated) {
        lines.push(
            'First: for each deprecated API above, confirm the replacement '
            + 'and estimate the migration cost at each call site.',
        );
    }
    lines.push(
        'For each new feature above, answer two separate questions: '
        + '(1) Retrofit — does it replace something this project currently '
        + 'does manually at an existing call site? '
        + '(2) Greenfield — does it solve a problem this project has but has '
        + `not addressed anywhere yet? Read the real \`${packageName}\` API `
        + 'before recommending — do not assume behavior from the changelog '
        + 'wording. Reject decorative-only changes that do not clarify a '
        + 'state transition. Output per feature: `file:line → concrete '
        + 'change` for a retrofit, `problem → concrete change` for a '
        + 'greenfield fit, or "no fit" with one reason.',
    );
    return lines;
}
