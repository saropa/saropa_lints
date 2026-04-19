import * as vscode from 'vscode';

// Match both `import` and `export` directives — re-exported packages are used too.
// Capture group 1 = directive (import|export); group 2 = package name. Distinguishing
// the two matters for downstream classification: an `export` is a public-API surface,
// not a removable internal dependency.
const IMPORT_PATTERN = /(import|export)\s+['"]package:(\w+)\//g;

// Detect commented-out import/export directives (single-line // comments only)
const COMMENTED_IMPORT_PATTERN = /^\s*\/\/\s*(import|export)\s+['"]package:(\w+)\//;

/** A single import/export occurrence of a package. */
export interface PackageUsage {
    /** Relative path from workspace root (e.g. "lib/widgets/panel.dart"). */
    readonly filePath: string;
    /** 1-based line number of the import/export statement. */
    readonly line: number;
    /** Whether this is a commented-out reference. */
    readonly isCommented: boolean;
    /**
     * True when the directive is `export` rather than `import`. Re-exports
     * make the package part of this library's public API, so downstream
     * consumers depend on it transitively — treating such packages as
     * "single-use, easy to remove" is misleading. Optional for source
     * compatibility with older fixtures that predate the field; the scanner
     * always sets it explicitly.
     */
    readonly isExport?: boolean;
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

        // Check for commented-out imports first (more specific pattern).
        // Capture group 1 = directive ('import'|'export'), group 2 = package name.
        const commentMatch = COMMENTED_IMPORT_PATTERN.exec(line);
        if (commentMatch) {
            addUsage(out, commentMatch[2], {
                filePath, line: i + 1, isCommented: true,
                isExport: commentMatch[1] === 'export',
            });
            continue;
        }

        // Check for active imports. Same capture group meaning as above.
        re.lastIndex = 0;
        let match: RegExpExecArray | null;
        while ((match = re.exec(line)) !== null) {
            addUsage(out, match[2], {
                filePath, line: i + 1, isCommented: false,
                isExport: match[1] === 'export',
            });
        }
    }
}

function addUsage(
    map: Map<string, PackageUsage[]>,
    packageName: string,
    usage: PackageUsage,
): void {
    const list = map.get(packageName);
    if (list) {
        list.push(usage);
    } else {
        map.set(packageName, [usage]);
    }
}
