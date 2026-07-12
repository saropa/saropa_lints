/**
 * Changelog opportunity miner.
 *
 * Turns the per-version changelog bullets already fetched by
 * `changelog-service` into ranked *adoption opportunities* — "here is a new
 * feature you could start using" — using only text heuristics, no AI.
 *
 * The classification has a deliberate ceiling: it can say WHAT is new and
 * whether the project already references the named API, but it cannot judge
 * whether a feature semantically fits a specific call site. The UI must frame
 * results as "review these" rather than "apply this for you".
 *
 * Pure module: takes `ChangelogEntry[]` plus caller-supplied project facts
 * (import file count, symbols seen in source) and returns plain data. No
 * `vscode` import so it is fully unit-testable.
 */

import { ChangelogEntry } from '../types';

/**
 * Category a single changelog bullet falls into. Only `added` (and, more
 * weakly, `changed`) represent something the consumer can choose to adopt;
 * the rest are recorded for completeness but are not opportunities.
 */
export type OpportunityCategory =
    | 'added'
    | 'changed'
    | 'fixed'
    | 'deprecated'
    | 'removed'
    | 'security'
    | 'other';

/** One classified changelog bullet. */
export interface ChangelogBullet {
    /** Cleaned bullet text (markdown list marker and code fences stripped). */
    readonly text: string;
    /** Version the bullet was published under. */
    readonly version: string;
    /** Heuristic category. */
    readonly category: OpportunityCategory;
    /**
     * Candidate API symbol names named in the bullet (backtick spans,
     * multi-hump PascalCase types, dotted member access, `call()` forms).
     * Empty when the bullet names no identifiable API.
     */
    readonly apiNames: readonly string[];
}

/** Result of mining one package's changelog delta. */
export interface PackageOpportunities {
    /** Bullets worth adopting (category `added` or `changed`), newest first. */
    readonly opportunities: readonly ChangelogBullet[];
    /** Every classified bullet, for a full "what changed" view. */
    readonly all: readonly ChangelogBullet[];
    /** Count of `opportunities`. */
    readonly opportunityCount: number;
    /** Deduped union of API names across the opportunity bullets. */
    readonly apiNames: readonly string[];
}

/** Section-header keyword → category. Order matters: first hit wins. */
const SECTION_KEYWORDS: ReadonlyArray<readonly [RegExp, OpportunityCategory]> = [
    [/\bsecurit/i, 'security'],
    [/\bdeprecat/i, 'deprecated'],
    [/\bremov|\bdrop/i, 'removed'],
    [/\bfix|\bbug/i, 'fixed'],
    [/\bchang|\bimprov|\bupdat/i, 'changed'],
    [/\badd|\bnew|\bfeatur/i, 'added'],
];

/**
 * Leading-text keyword inference for changelogs that have NO Keep-a-Changelog
 * section headers (e.g. plain bullet lists like reel_text's). Checked in order
 * against the bullet text; first hit wins. The `added` patterns sit last so a
 * "Fixed ..." bullet is not mis-tagged by an incidental "add" later in the
 * sentence.
 */
const BULLET_KEYWORDS: ReadonlyArray<readonly [RegExp, OpportunityCategory]> = [
    [/^(security\b|cve-)/i, 'security'],
    [/^(deprecat)/i, 'deprecated'],
    [/^(remov|drop|delet)/i, 'removed'],
    [/^(fix|bug|resolv|correct)/i, 'fixed'],
    // Conventional-commit feature prefix, e.g. "feat:" or "feat(scope):".
    [/^feat(\([^)]*\))?\s*:/i, 'added'],
    [/^(add|added|new\b|introduc|support\b|now supports?\b|you can now\b)/i, 'added'],
    [/^(chang|updat|improv|rework|enhance|switch|rename|move|split)/i, 'changed'],
];

/**
 * Mine a package's changelog entries (already filtered to the
 * current→latest delta by `changelog-service`) into adoption opportunities.
 */
export function mineOpportunities(
    entries: readonly ChangelogEntry[],
): PackageOpportunities {
    const all: ChangelogBullet[] = [];

    for (const entry of entries) {
        all.push(...classifyEntryBullets(entry));
    }

    // `added` and `changed` are the only adoption-worthy categories. `changed`
    // is weaker (may be a behavioral tweak rather than a new capability) but
    // still something a consumer might act on, so it is included and the UI can
    // distinguish via `category`.
    const opportunities = all.filter(
        b => b.category === 'added' || b.category === 'changed',
    );

    const apiNames = dedupe(opportunities.flatMap(b => b.apiNames));

    return {
        opportunities,
        all,
        opportunityCount: opportunities.length,
        apiNames,
    };
}

/** Classify every bullet within a single version entry's markdown body. */
function classifyEntryBullets(entry: ChangelogEntry): ChangelogBullet[] {
    const lines = entry.body.split('\n');
    const bullets: ChangelogBullet[] = [];

    // Tracks the category implied by the most recent section header
    // (`### Added` etc.). `null` means no header seen yet — fall back to
    // per-bullet keyword inference.
    let sectionCategory: OpportunityCategory | null = null;

    for (const rawLine of lines) {
        const line = rawLine.trim();
        if (line.length === 0) { continue; }

        const headerCategory = sectionHeaderCategory(line);
        if (headerCategory !== null) {
            sectionCategory = headerCategory;
            continue;
        }

        const bulletText = stripListMarker(line);
        if (bulletText === null) { continue; }

        const category = sectionCategory
            ?? inferCategoryFromText(bulletText);

        bullets.push({
            text: bulletText,
            version: entry.version,
            category,
            apiNames: extractApiNames(bulletText),
        });
    }

    return bullets;
}

/**
 * Return the category for a markdown heading line (`#`/`##`/`###` …), or
 * `null` if the line is not a heading. Keep-a-Changelog uses `### Added`,
 * `### Fixed`, etc.; we match the heading text against `SECTION_KEYWORDS`.
 */
function sectionHeaderCategory(line: string): OpportunityCategory | null {
    const match = line.match(/^#{1,6}\s+(.+)$/);
    if (!match) { return null; }
    const heading = match[1];
    for (const [pattern, category] of SECTION_KEYWORDS) {
        if (pattern.test(heading)) { return category; }
    }
    // A heading we don't recognize resets section context to "unknown" so
    // following bullets fall back to per-bullet keyword inference rather than
    // inheriting a stale category.
    return 'other';
}

/**
 * Strip a leading markdown list marker (`-`, `*`, `+`) from a line and return
 * the bullet text. Returns `null` when the line is not a list item (prose,
 * blockquote, code fence) so non-bullet noise is ignored.
 */
function stripListMarker(line: string): string | null {
    const match = line.match(/^[-*+]\s+(.+)$/);
    if (!match) { return null; }
    // Drop a leading bold "**Added:** " style label some changelogs use inline.
    return match[1].replace(/^\*\*[^*]+\*\*:?\s*/, '').trim();
}

/** Infer a category from bullet text when no section header governs it. */
function inferCategoryFromText(text: string): OpportunityCategory {
    for (const [pattern, category] of BULLET_KEYWORDS) {
        if (pattern.test(text)) { return category; }
    }
    return 'other';
}

/**
 * File extensions changelog prose commonly references (`README.md`,
 * `CHANGELOG.md`, `pubspec.yaml`, `LICENSE.txt`) that are documents, not
 * code. The dotted-member-access and backtick extraction signals below match
 * any `word.word` span by shape alone, so "see README.md for details" is
 * indistinguishable from `ReelText.rich` without checking the extension —
 * this is what let README.md surface as an adoptable "opportunity".
 */
const NON_CODE_EXTENSIONS = new Set([
    'md', 'markdown', 'txt', 'json', 'yaml', 'yml', 'html', 'htm', 'css',
    'xml', 'csv', 'pdf', 'log', 'toml', 'ini', 'lock', 'rst', 'adoc',
    'doc', 'docx', 'zip', 'png', 'jpg', 'jpeg', 'svg', 'gif',
]);

/** True when `name` is shaped like a filename (`README.md`) rather than a
 * dotted API reference (`ReelText.rich`) — only the extension tells them
 * apart, since both are `Word.word` by shape. */
function looksLikeFilename(name: string): boolean {
    const dot = name.lastIndexOf('.');
    if (dot === -1) { return false; }
    return NON_CODE_EXTENSIONS.has(name.slice(dot + 1).toLowerCase());
}

/**
 * Extract candidate API symbol names from a bullet.
 *
 * Three complementary signals, in priority order:
 *  1. Backtick code spans — the author explicitly marked these as code.
 *  2. Multi-hump PascalCase (`ReelText`, `WidgetSpan`) — a type name. Requires
 *     two capital humps so ordinary capitalized words ("Added", "Fixed") are
 *     not captured.
 *  3. Dotted member access off a PascalCase owner (`ReelText.rich`) and
 *     trailing-paren call forms (`runWhile()`).
 *
 * A final pass drops anything shaped like a filename (`looksLikeFilename`) —
 * documents named in changelog prose are never adoptable API surface, even
 * when they happen to match one of the three signals above.
 *
 * Results are deduped preserving first-seen order.
 */
export function extractApiNames(text: string): string[] {
    const names: string[] = [];

    // 1. Backtick spans. Keep only identifier-shaped contents; strip a
    //    trailing "()" so `runWhile()` and `runWhile` dedupe together.
    const backtick = /`([^`]+)`/g;
    let m: RegExpExecArray | null;
    while ((m = backtick.exec(text)) !== null) {
        const inner = m[1].trim().replace(/\(\)$/, '');
        if (/^[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*$/.test(inner)) {
            names.push(inner);
        }
    }

    // 3 (before bare 2 so dotted owners win): dotted member access.
    const dotted = /\b[A-Z][A-Za-z0-9]*\.[A-Za-z_]\w*/g;
    while ((m = dotted.exec(text)) !== null) {
        names.push(m[0]);
    }

    // 2. Multi-hump PascalCase types.
    const pascal = /\b[A-Z][a-z0-9]+(?:[A-Z][a-z0-9]+)+\b/g;
    while ((m = pascal.exec(text)) !== null) {
        names.push(m[0]);
    }

    return dedupe(names).filter(n => !looksLikeFilename(n));
}

/**
 * Ranking inputs the caller gathers from the project: how many source files
 * import the package, and which candidate symbols already appear in project
 * source.
 */
export interface ProjectUsageFacts {
    /** Number of project source files that import/export the package. */
    readonly importFileCount: number;
    /**
     * Symbols already referenced anywhere in project source. An opportunity
     * whose API names are all in this set is "already adopted" and ranks
     * lower; one with a symbol absent from it is a genuinely new capability.
     */
    readonly usedSymbols: ReadonlySet<string>;
}

/** Ranked view of one package's opportunities against project usage. */
export interface OpportunityRanking {
    /** Opportunities naming at least one symbol the project does not yet use. */
    readonly adoptableCount: number;
    /** API names from opportunities that are absent from project source. */
    readonly unusedApiNames: readonly string[];
    /**
     * Relevance score (0–100). Higher = more worth surfacing: scales with how
     * many genuinely-new capabilities exist and how heavily the project already
     * leans on the package. A package the project barely imports is demoted
     * even when its changelog is rich.
     */
    readonly score: number;
}

/**
 * Rank a package's opportunities against project usage facts.
 *
 * Score model (documented so the weights are tunable, not magic):
 *  - `adoptableCount` (new features you don't already use) is the base driver,
 *    10 points each, because unused-but-available is the whole point.
 *  - An informational floor of 2 points per remaining opportunity keeps
 *    "already adopted / no-symbol" changes visible but low.
 *  - A usage multiplier reflects investment: a package imported in many files
 *    is one whose new features are likelier to matter. 0 imports halves the
 *    score (dev-only/transitive); heavy use boosts up to 1.5×.
 */
export function rankOpportunities(
    opp: PackageOpportunities,
    facts: ProjectUsageFacts,
): OpportunityRanking {
    const unused = new Set<string>();
    let adoptableCount = 0;

    for (const bullet of opp.opportunities) {
        const newSymbols = bullet.apiNames.filter(
            n => !facts.usedSymbols.has(n),
        );
        if (bullet.apiNames.length > 0 && newSymbols.length > 0) {
            adoptableCount++;
            for (const s of newSymbols) { unused.add(s); }
        }
    }

    const informational = opp.opportunityCount - adoptableCount;
    const base = adoptableCount * 10 + informational * 2;
    const multiplier = usageMultiplier(facts.importFileCount);
    const score = Math.min(100, Math.round(base * multiplier));

    return {
        adoptableCount,
        unusedApiNames: [...unused],
        score,
    };
}

/** Usage multiplier: demote unused packages, boost heavily-used ones. */
function usageMultiplier(importFileCount: number): number {
    if (importFileCount === 0) { return 0.5; }
    if (importFileCount <= 3) { return 1; }
    return 1.5;
}

/** Stable dedupe preserving first-seen order. */
function dedupe(values: readonly string[]): string[] {
    const seen = new Set<string>();
    const out: string[] = [];
    for (const v of values) {
        if (!seen.has(v)) {
            seen.add(v);
            out.push(v);
        }
    }
    return out;
}
