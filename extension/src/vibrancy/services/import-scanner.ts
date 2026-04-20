import * as vscode from 'vscode';

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

/**
 * Scan Dart source files and return per-file import locations for each package.
 * Superset of scanDartImports — also collects file paths and line numbers.
 */
export async function scanDartImportsDetailed(
    workspaceRoot: vscode.Uri,
): Promise<PackageUsageMap> {
    // Scan all standard Dart source directories — web/ and tool/ are
    // first-class entry points (like bin/) and integration_test/ is the
    // standard Flutter integration-test directory.
    const pattern = new vscode.RelativePattern(
        workspaceRoot, '{lib,bin,test,web,tool,integration_test}/**/*.dart',
    );
    const files = await vscode.workspace.findFiles(pattern);
    const rootPrefix = workspaceRoot.fsPath.replace(/\\/g, '/');

    const usageMap = new Map<string, PackageUsage[]>();

    const contents = await Promise.all(
        files.map(f => vscode.workspace.fs.readFile(f)),
    );
    for (let i = 0; i < files.length; i++) {
        const filePath = toRelativePath(files[i].fsPath, rootPrefix);
        const text = Buffer.from(contents[i]).toString('utf8');
        collectDetailedImports(text, filePath, usageMap);
    }

    return usageMap;
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
