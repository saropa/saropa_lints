/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Vibrancy UI experiment: scoring, providers, and webview assets. */
import * as vscode from 'vscode';

// Walks .dart files for import/export lines; dedupes refs for the vibrancy grid.
// Match both `import` and `export` directives — re-exported packages are used too.
// Capture group 1 = directive (import|export); group 2 = package name. Distinguishing
// the two matters for downstream classification: an `export` is a public-API surface,
// not a removable internal dependency.
const IMPORT_PATTERN = /(import|export)\s+['"]package:(\w+)\//g;

// Detect commented-out import/export directives (single-line // comments only)
const COMMENTED_IMPORT_PATTERN = /^\s*\/\/\s*(import|export)\s+['"]package:(\w+)\//;

/**
 * A package's usage within a single source file.
 *
 * Previously the scanner emitted one entry per directive, so a file that
 * both imported and re-exported the same package produced two separate
 * usages — and the References column in the Vibrancy report double-counted
 * it (e.g. `share_utils.dart` with `import 'package:share_plus/...'` plus
 * `export 'package:share_plus/...' show XFile, ...` reported 2 references
 * for what is physically one file). The scanner now deduplicates by
 * `(filePath, isCommented)` and tracks the directive lines separately via
 * `importLine` / `exportLine`, so callers get an accurate per-file count
 * while keeping full directive detail for JSON export and tooltips.
 */
export interface PackageUsage {
    /** Relative path from workspace root (e.g. "lib/widgets/panel.dart"). */
    readonly filePath: string;
    /**
     * Primary display line. Prefers `exportLine` when the file re-exports
     * the package (public API surface is the more significant signal),
     * otherwise falls back to `importLine`. Retained so existing callers
     * that render a single `file:line` reference keep working without
     * change. 0 indicates no directive was recorded (shouldn't happen for
     * scanner output — only possible in minimal test fixtures).
     */
    readonly line: number;
    /** Whether this file's directives are commented-out (dead references). */
    readonly isCommented: boolean;
    /**
     * True when the file has an `export` directive for this package —
     * i.e. the package is part of this library's public API surface, so
     * treating it as "single-use, easy to remove" is misleading.
     * Derived from `exportLine !== null` when populated by the scanner;
     * stays optional for source compatibility with test fixtures that
     * predate the field.
     */
    readonly isExport?: boolean;
    /**
     * 1-based line number of the `import` directive in this file, or
     * `null` if the package is only re-exported and never imported.
     * Optional for source compatibility with existing test fixtures.
     */
    readonly importLine?: number | null;
    /**
     * 1-based line number of the `export` directive in this file, or
     * `null` if the package is imported but not re-exported. Optional for
     * source compatibility with existing test fixtures.
     */
    readonly exportLine?: number | null;
}

/** Per-package usage map: package name -> list of usages. */
export type PackageUsageMap = ReadonlyMap<string, readonly PackageUsage[]>;

/**
 * Scan Dart source files for package import and export statements.
 * Returns the set of package names that appear in any active (non-commented) import or export.
 *
 * Thin wrapper over scanDartImportsDetailed — returns only the set of names.
 */
export async function scanDartImports(
    workspaceRoot: vscode.Uri,
): Promise<Set<string>> {
    const detailed = await scanDartImportsDetailed(workspaceRoot);
    // Only include packages with at least one active (non-commented) import.
    // Commented-only packages must NOT be treated as "imported" for unused detection.
    return activePackageNames(detailed);
}

/** Return the set of package names that have at least one active (non-commented) usage. */
export function activePackageNames(usageMap: PackageUsageMap): Set<string> {
    const names = new Set<string>();
    for (const [name, usages] of usageMap) {
        if (usages.some(u => !u.isCommented)) {
            names.add(name);
        }
    }
    return names;
}

/** Return only the active (non-commented) usages for a VibrancyResult. */
export function activeFileUsages(usages: readonly PackageUsage[]): readonly PackageUsage[] {
    return usages.filter(u => !u.isCommented);
}

/**
 * True when at least one active (non-commented) usage of the package is an
 * `export` directive — meaning this package is part of the library's public
 * API surface and can't be safely removed without breaking downstream
 * consumers. Used to suppress misleading "single-use" / removable signals.
 */
export function hasActiveReExport(usages: readonly PackageUsage[]): boolean {
    return usages.some(u => !u.isCommented && u.isExport);
}

/** One project source file: workspace-relative path plus its full text. */
export interface DartSource {
    readonly path: string;
    readonly text: string;
}

/**
 * Read every project Dart source once. Shared by the import scan and the
 * symbol-usage scan so the file walk + read happens a SINGLE time per scan —
 * a package imported in hundreds of files would otherwise be walked twice.
 */
export async function readDartSources(
    workspaceRoot: vscode.Uri,
): Promise<readonly DartSource[]> {
    // Scan all standard Dart source directories — web/ and tool/ are
    // first-class entry points (like bin/) and integration_test/ is the
    // standard Flutter integration-test directory.
    const pattern = new vscode.RelativePattern(
        workspaceRoot, '{lib,bin,test,web,tool,integration_test}/**/*.dart',
    );
    const files = await vscode.workspace.findFiles(pattern);
    const rootPrefix = workspaceRoot.fsPath.replace(/\\/g, '/');

    const contents = await Promise.all(
        files.map(f => vscode.workspace.fs.readFile(f)),
    );
    return files.map((f, i) => ({
        path: toRelativePath(f.fsPath, rootPrefix),
        text: Buffer.from(contents[i]).toString('utf8'),
    }));
}

/**
 * Scan Dart source files and return per-file import locations for each package.
 * Superset of scanDartImports — also collects file paths and line numbers.
 */
export async function scanDartImportsDetailed(
    workspaceRoot: vscode.Uri,
): Promise<PackageUsageMap> {
    return collectImportsFromSources(await readDartSources(workspaceRoot));
}

/** Build the per-package usage map from already-read sources. */
export function collectImportsFromSources(
    sources: readonly DartSource[],
): PackageUsageMap {
    const usageMap = new Map<string, PackageUsage[]>();
    for (const source of sources) {
        collectDetailedImports(source.text, source.path, usageMap);
    }
    return usageMap;
}

/**
 * Find which of the candidate symbols appear in project source.
 *
 * The candidates are API names extracted from package changelogs (e.g.
 * `ReelText`, `ReelText.rich`, `runWhile`). A candidate present in source is
 * "already adopted"; one absent is a genuinely unused feature — the signal
 * that turns an up-to-date package into a needle.
 *
 * Matching uses word boundaries so `Foo` does not match `Foobar`, and tries
 * longer candidates first so a dotted member (`ReelText.rich`) is recorded
 * rather than its bare owner (`ReelText`) when both are candidates. Pure: takes
 * already-read sources so it shares the single walk in `readDartSources`.
 */
export function collectSymbolUsage(
    sources: readonly DartSource[],
    candidates: ReadonlySet<string>,
): Set<string> {
    const found = new Set<string>();
    if (candidates.size === 0) { return found; }

    // Longest-first so `ReelText.rich` wins over `ReelText` in the alternation;
    // escape regex metacharacters (the `.` in dotted members especially).
    const ordered = [...candidates].sort((a, b) => b.length - a.length);
    const escaped = ordered.map(c => c.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
    const re = new RegExp(`\\b(${escaped.join('|')})\\b`, 'g');

    for (const source of sources) {
        re.lastIndex = 0;
        let match: RegExpExecArray | null;
        while ((match = re.exec(source.text)) !== null) {
            found.add(match[1]);
        }
        // Every candidate already seen — no later file can add anything.
        if (found.size === candidates.size) { break; }
    }
    return found;
}

/**
 * Any line whose trimmed form is an `import`/`export` directive, commented or
 * not. IMPORT_PATTERN / COMMENTED_IMPORT_PATTERN only recognize `package:`
 * URIs because their job is naming the package; occurrence counting needs the
 * broader shape (relative and `dart:` directives too) because a `show ReelText`
 * clause on ANY directive names the symbol without using it.
 */
const DIRECTIVE_LINE_PATTERN = /^\s*(?:\/\/\s*)?(?:import|export)\s+['"]/;

/** Snippet cap — enough to read the call in context, short enough to store per occurrence. */
const SNIPPET_MAX_LENGTH = 200;

/** One textual appearance of a candidate symbol in project source. */
export interface SymbolOccurrence {
    /** Workspace-relative path of the file containing the match. */
    readonly filePath: string;
    /** 1-based line number, matching editor and `path:line` link conventions. */
    readonly line: number;
    /**
     * 1-based column of the match start in the RAW source line — the value an
     * editor jump needs. Deliberately not an offset into `snippet`, which is
     * trimmed and so loses the leading indentation this counts.
     */
    readonly column: number;
    /** The trimmed source line, capped at {@link SNIPPET_MAX_LENGTH} characters. */
    readonly snippet: string;
}

/**
 * Locate and count every appearance of the candidate symbols in project source.
 *
 * Sibling of {@link collectSymbolUsage}, not a replacement: that function answers
 * "is this adopted at all?" and stops as soon as every candidate has been seen,
 * which is why it stays untouched. This one deliberately has NO early break —
 * counts and call sites are the entire product, so a candidate first seen in file
 * one must still accumulate its occurrences in every later file.
 *
 * Import and export directive lines are skipped: `show ReelText` names the symbol
 * to the compiler but is not a use of it, and counting directives would report
 * adoption for a package that is merely imported.
 *
 * CEILING — this is textual matching, not resolved references. A local variable
 * named `Duration`, or a same-named symbol from an unrelated package, is counted.
 * Callers presenting these numbers must disclose that; treating them as resolved
 * reference counts would overstate adoption of common names (`Text`, `State`).
 *
 * Symbols with no match are absent from the map rather than mapped to an empty
 * array, so `map.get(name) === undefined` and "used zero times" are one case.
 */
export function collectSymbolOccurrences(
    sources: readonly DartSource[],
    candidates: ReadonlySet<string>,
): ReadonlyMap<string, readonly SymbolOccurrence[]> {
    const found = new Map<string, SymbolOccurrence[]>();
    if (candidates.size === 0) { return found; }

    for (const source of sources) {
        collectFileOccurrences(source, candidates, found);
    }
    return found;
}

/**
 * A dotted identifier chain: `ReelText`, `ReelText.rich`, `a.b.c`.
 *
 * Deliberately NOT a giant alternation of the candidate names. That shape costs
 * O(candidates) at every source position, and the candidate set is the union of
 * API names across every dependency's full changelog history, so it grows with
 * the project. Tokenizing once and looking each chain up in the candidate Set
 * is O(tokens) with hashed lookups, independent of candidate count.
 *
 * Honest accounting: this removes a growth term, it did not fix a measured
 * bottleneck. The alternation it replaced handled 5000 candidates across 2000
 * lines in single-digit milliseconds. Do not cite this as a performance win.
 */
const IDENTIFIER_CHAIN_PATTERN = /[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*/g;

/**
 * Longest candidate that starts at `from` within a dotted chain, or null.
 *
 * Longest-first is what lets `ReelText.rich` win over its bare owner
 * `ReelText`, matching the leftmost-longest behavior a length-ordered
 * alternation gave.
 */
function longestCandidateAt(
    chain: string, from: number, candidates: ReadonlySet<string>,
): string | null {
    let slice = chain.slice(from);
    while (slice.length > 0) {
        if (candidates.has(slice)) { return slice; }
        const dot = slice.lastIndexOf('.');
        if (dot < 0) { return null; }
        slice = slice.slice(0, dot);
    }
    return null;
}

/**
 * Every candidate hit inside one dotted chain, as offsets into it.
 *
 * Walks segment starts rather than only the chain start, so a candidate that is
 * a member name (`rich` in `foo.rich`) is still found — the word-boundary
 * regex this replaced treated `.` as a boundary and matched there too.
 */
function chainHits(
    chain: string, candidates: ReadonlySet<string>,
): ReadonlyArray<{ offset: number; name: string }> {
    const hits: Array<{ offset: number; name: string }> = [];
    let pos = 0;
    while (pos < chain.length) {
        const hit = longestCandidateAt(chain, pos, candidates);
        if (hit !== null) {
            hits.push({ offset: pos, name: hit });
            pos += hit.length + 1;
            continue;
        }
        const nextDot = chain.indexOf('.', pos);
        if (nextDot < 0) { break; }
        pos = nextDot + 1;
    }
    return hits;
}

/**
 * Scan one file line by line. Line-at-a-time rather than whole-text matching
 * because the line number and column ARE the deliverable; deriving them from a
 * whole-text offset would mean a second pass to count newlines.
 */
function collectFileOccurrences(
    source: DartSource,
    candidates: ReadonlySet<string>,
    out: Map<string, SymbolOccurrence[]>,
): void {
    const lines = source.text.split('\n');
    // A directive runs until its terminating `;`. dart format wraps long `show`
    // clauses onto continuation lines, so matching only the opening line would
    // count every symbol in a wrapped clause as a usage — the precise
    // false positive the directive skip exists to prevent.
    let inDirective = false;
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (inDirective || DIRECTIVE_LINE_PATTERN.test(line)) {
            inDirective = directiveContinues(line);
            continue;
        }
        const snippet = line.trim().substring(0, SNIPPET_MAX_LENGTH);
        IDENTIFIER_CHAIN_PATTERN.lastIndex = 0;
        let chain: RegExpExecArray | null;
        while ((chain = IDENTIFIER_CHAIN_PATTERN.exec(line)) !== null) {
            for (const hit of chainHits(chain[0], candidates)) {
                appendOccurrence(out, hit.name, {
                    filePath: source.path,
                    line: i + 1,
                    column: chain.index + hit.offset + 1,
                    snippet,
                });
            }
        }
    }
}

/**
 * True when a directive line does NOT terminate, so the following line is a
 * continuation and must be skipped too.
 *
 * The trailing line comment is stripped first: `import 'x'  // TODO drop;` ends
 * in a semicolon that belongs to prose, and treating it as the terminator would
 * expose the wrapped `show` clause underneath as usages.
 *
 * A blank line also closes the run. An unterminated directive means malformed
 * source, and without that stop a single missing semicolon would swallow every
 * remaining line in the file.
 */
function directiveContinues(line: string): boolean {
    const trimmed = line.trim();
    // A commented-out directive opens with `//`; that marker is part of the
    // directive here, not a trailing comment, so drop it before looking for one.
    const body = trimmed.startsWith('//') ? trimmed.slice(2) : trimmed;
    const commentAt = body.indexOf('//');
    const code = commentAt < 0 ? body : body.slice(0, commentAt);
    return !code.includes(';') && trimmed.length > 0;
}

/** Append to the symbol's list, creating it on first sight so zero-match symbols stay absent. */
function appendOccurrence(
    out: Map<string, SymbolOccurrence[]>,
    symbol: string,
    occurrence: SymbolOccurrence,
): void {
    const list = out.get(symbol);
    if (list) {
        list.push(occurrence);
        return;
    }
    out.set(symbol, [occurrence]);
}

/** Convert an absolute path to a workspace-relative path with forward slashes. */
function toRelativePath(absolute: string, rootPrefix: string): string {
    const normalized = absolute.replace(/\\/g, '/');
    if (normalized.startsWith(rootPrefix + '/')) {
        return normalized.substring(rootPrefix.length + 1);
    }
    // Fallback: return as-is (shouldn't happen within workspace)
    return normalized;
}

/**
 * Collect per-line import information from a single file's content.
 * Detects both active and commented-out import/export statements.
 *
 * Entries are merged per `(filePath, isCommented)` tuple so a file that
 * has both an `import` and an `export` of the same package produces ONE
 * usage (with `importLine` and `exportLine` populated) rather than two.
 * This matches the intuition behind the "References" column label in the
 * report ("Number of source files that import this package").
 */
function collectDetailedImports(
    content: string,
    filePath: string,
    out: Map<string, PackageUsage[]>,
): void {
    const lines = content.split('\n');
    // Reuse a single regex instance across lines; reset lastIndex before each line
    const re = new RegExp(IMPORT_PATTERN.source, 'g');
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const lineNumber = i + 1;

        // Check for commented-out imports first (more specific pattern).
        // Capture group 1 = directive ('import'|'export'), group 2 = package name.
        const commentMatch = COMMENTED_IMPORT_PATTERN.exec(line);
        if (commentMatch) {
            recordDirective(
                out, commentMatch[2], filePath, lineNumber,
                commentMatch[1] === 'export' ? 'export' : 'import',
                true,
            );
            continue;
        }

        // Check for active imports. Same capture group meaning as above.
        re.lastIndex = 0;
        let match: RegExpExecArray | null;
        while ((match = re.exec(line)) !== null) {
            recordDirective(
                out, match[2], filePath, lineNumber,
                match[1] === 'export' ? 'export' : 'import',
                false,
            );
        }
    }
}

/**
 * Merge a directive into the usage map, deduplicating per
 * `(filePath, isCommented)`. When a file already has an entry for the
 * same commented-status, the new directive's line number is stored in
 * the matching slot (`importLine` or `exportLine`) on a replacement
 * record — preserving the `readonly` contract on `PackageUsage`.
 *
 * The first occurrence of each directive kind wins so re-scanning the
 * same file is deterministic (e.g. if somehow two `import` statements
 * of the same package appear in one file, the earlier one is reported).
 */
function recordDirective(
    map: Map<string, PackageUsage[]>,
    packageName: string,
    filePath: string,
    lineNumber: number,
    directive: 'import' | 'export',
    isCommented: boolean,
): void {
    let list = map.get(packageName);
    if (!list) {
        list = [];
        map.set(packageName, list);
    }
    const existingIdx = list.findIndex(
        u => u.filePath === filePath && u.isCommented === isCommented,
    );
    if (existingIdx < 0) {
        list.push(buildUsage(
            filePath, isCommented,
            directive === 'import' ? lineNumber : null,
            directive === 'export' ? lineNumber : null,
        ));
        return;
    }
    // Merge into the existing entry. `?? null` normalizes the optional
    // scanner fields (they are always populated on scanner-produced
    // records, but the interface permits `undefined` for test fixtures).
    const existing = list[existingIdx];
    const existingImport = existing.importLine ?? null;
    const existingExport = existing.exportLine ?? null;
    list[existingIdx] = buildUsage(
        filePath, isCommented,
        directive === 'import' && existingImport === null
            ? lineNumber : existingImport,
        directive === 'export' && existingExport === null
            ? lineNumber : existingExport,
    );
}

/**
 * Construct a canonical PackageUsage. `line` is derived from the
 * available directive lines (prefer `exportLine` because a re-export
 * is the signal the downstream-consumer tooltip / badge highlights);
 * `isExport` mirrors `exportLine !== null` so legacy callers keep
 * working.
 */
function buildUsage(
    filePath: string,
    isCommented: boolean,
    importLine: number | null,
    exportLine: number | null,
): PackageUsage {
    return {
        filePath,
        isCommented,
        importLine,
        exportLine,
        line: exportLine ?? importLine ?? 0,
        isExport: exportLine !== null,
    };
}
