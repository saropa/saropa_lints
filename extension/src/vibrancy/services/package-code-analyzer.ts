import * as vscode from 'vscode';
import { CacheService } from './cache-service';
import { ScanLogger } from './scan-logger';

/** Replacement complexity level. */
export type ReplacementLevel = 'trivial' | 'small' | 'moderate' | 'large' | 'native';

/** Raw line-count metrics for a package's local source. */
export interface PackageCodeMetrics {
    /** Lines of Dart code in lib/ (excludes comments and blanks). */
    readonly libCodeLines: number;
    /** Lines of comments/documentation in lib/. */
    readonly libCommentLines: number;
    /** Number of .dart files in lib/. */
    readonly libFileCount: number;
    /** Lines of Dart code in example/ (if present). */
    readonly exampleCodeLines: number;
    /** Whether native platform directories exist (ios/, android/, etc.). */
    readonly hasNativeCode: boolean;
    /** Which native platform directories were found. */
    readonly nativePlatforms: readonly string[];
}

/** Classified replacement complexity for a package. */
export interface ReplacementComplexity {
    readonly level: ReplacementLevel;
    readonly metrics: PackageCodeMetrics;
    /** Human-readable summary, e.g. "25 lines of Dart in 2 files". */
    readonly summary: string;
}

/** Known native/platform directories that indicate non-Dart code. */
const NATIVE_DIRS = ['ios', 'android', 'macos', 'linux', 'windows', 'web'] as const;

/**
 * Parse `.dart_tool/package_config.json` to resolve package names
 * to their local filesystem paths.
 *
 * Returns a map from package name to the resolved root URI.
 * Packages whose rootUri cannot be resolved are silently skipped.
 */
export async function resolvePackagePaths(
    workspaceRoot: vscode.Uri,
): Promise<ReadonlyMap<string, vscode.Uri>> {
    const configUri = vscode.Uri.joinPath(
        workspaceRoot, '.dart_tool', 'package_config.json',
    );

    let raw: string;
    try {
        const bytes = await vscode.workspace.fs.readFile(configUri);
        raw = Buffer.from(bytes).toString('utf8');
    } catch {
        return new Map();
    }

    let json: any;
    try {
        json = JSON.parse(raw);
    } catch {
        return new Map();
    }

    const packages: any[] = json.packages ?? [];
    const result = new Map<string, vscode.Uri>();

    for (const pkg of packages) {
        if (!pkg.name || !pkg.rootUri) { continue; }
        const rootUri = resolveRootUri(pkg.rootUri, configUri);
        if (rootUri) {
            result.set(pkg.name, rootUri);
        }
    }

    return result;
}

/**
 * Resolve a rootUri from package_config.json.
 *
 * rootUri values can be:
 *  - Absolute file:// URI (e.g. pub cache path)
 *  - Relative path (resolved against the package_config.json location)
 */
function resolveRootUri(
    rootUri: string,
    configUri: vscode.Uri,
): vscode.Uri | null {
    try {
        if (rootUri.startsWith('file://')) {
            return vscode.Uri.parse(rootUri);
        }
        // Relative path — resolve against the directory containing package_config.json
        const configDir = vscode.Uri.joinPath(configUri, '..');
        return vscode.Uri.joinPath(configDir, rootUri);
    } catch {
        return null;
    }
}

/**
 * Analyze the source code of a single package from its local cache path.
 *
 * Reads all .dart files under lib/ and example/ (if present) and
 * classifies each line as code, comment, or blank.
 */
export async function analyzePackageCode(
    packageRoot: vscode.Uri,
): Promise<PackageCodeMetrics> {
    const [libStats, exampleStats, nativePlatforms] = await Promise.all([
        countDartLines(packageRoot, 'lib'),
        countDartLines(packageRoot, 'example'),
        detectNativePlatforms(packageRoot),
    ]);

    return {
        libCodeLines: libStats.codeLines,
        libCommentLines: libStats.commentLines,
        libFileCount: libStats.fileCount,
        exampleCodeLines: exampleStats.codeLines,
        hasNativeCode: nativePlatforms.length > 0,
        nativePlatforms,
    };
}

interface DirStats {
    readonly codeLines: number;
    readonly commentLines: number;
    readonly fileCount: number;
}

/**
 * Count code and comment lines in all .dart files under a subdirectory.
 *
 * Uses a simple heuristic classifier (no AST parsing):
 *  - Blank line: only whitespace
 *  - Comment line: first non-whitespace is //, ///, /*, or * (block continuation)
 *  - Code line: everything else
 */
async function countDartLines(
    packageRoot: vscode.Uri,
    subdir: string,
): Promise<DirStats> {
    const dirUri = vscode.Uri.joinPath(packageRoot, subdir);

    // Check if directory exists before globbing
    try {
        await vscode.workspace.fs.stat(dirUri);
    } catch {
        return { codeLines: 0, commentLines: 0, fileCount: 0 };
    }

    const pattern = new vscode.RelativePattern(dirUri, '**/*.dart');
    const files = await vscode.workspace.findFiles(pattern);

    if (files.length === 0) {
        return { codeLines: 0, commentLines: 0, fileCount: 0 };
    }

    const contents = await Promise.all(
        files.map(f => vscode.workspace.fs.readFile(f)),
    );

    let codeLines = 0;
    let commentLines = 0;

    for (const bytes of contents) {
        const text = Buffer.from(bytes).toString('utf8');
        const counts = classifyLines(text);
        codeLines += counts.code;
        commentLines += counts.comment;
    }

    return { codeLines, commentLines, fileCount: files.length };
}

/** Line classification result for a single file. */
interface LineCounts {
    readonly code: number;
    readonly comment: number;
}

/**
 * Classify each line of Dart source as code or comment.
 * Blank lines are not counted in either bucket.
 *
 * Handles single-line comments (// and ///) and block comments.
 * Lines with both code and a trailing comment count as code.
 *
 * Known limitations (acceptable for heuristic LOC counting):
 *  - `/*` inside string literals is misread as a block comment start
 *  - Code after a block comment close (`* / code`) on the same line is lost
 *  These edge cases are rare in practice and don't affect classification accuracy
 *  enough to justify the complexity of a full lexer.
 */
export function classifyLines(text: string): LineCounts {
    const lines = text.split('\n');
    let code = 0;
    let comment = 0;
    let inBlockComment = false;

    for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.length === 0) { continue; }

        if (inBlockComment) {
            comment++;
            if (trimmed.includes('*/')) {
                inBlockComment = false;
            }
            continue;
        }

        if (trimmed.startsWith('//')) {
            comment++;
            continue;
        }

        if (trimmed.startsWith('/*')) {
            comment++;
            if (!trimmed.includes('*/')) {
                inBlockComment = true;
            }
            continue;
        }

        // Line has actual code (may have trailing // comment — still counts as code)
        code++;

        // Check if a block comment starts mid-line and doesn't close on the same line
        const blockStart = trimmed.indexOf('/*');
        if (blockStart >= 0) {
            const afterStart = trimmed.indexOf('*/', blockStart + 2);
            if (afterStart < 0) {
                inBlockComment = true;
            }
        }
    }

    return { code, comment };
}

/** Check which native platform directories exist in the package root. */
async function detectNativePlatforms(
    packageRoot: vscode.Uri,
): Promise<readonly string[]> {
    const found: string[] = [];

    // Check each platform dir in parallel
    const checks = NATIVE_DIRS.map(async (dir) => {
        try {
            const stat = await vscode.workspace.fs.stat(
                vscode.Uri.joinPath(packageRoot, dir),
            );
            if (stat.type === vscode.FileType.Directory) {
                return dir;
            }
        } catch {
            // Directory doesn't exist — expected for most packages
        }
        return null;
    });

    const results = await Promise.all(checks);
    for (const dir of results) {
        if (dir) { found.push(dir); }
    }

    return found;
}

/**
 * Classify replacement complexity from code metrics.
 *
 * Native code dominates: even a small Dart wrapper around platform
 * channels is non-trivial to replace because of the native side.
 */
export function classifyReplacement(
    metrics: PackageCodeMetrics,
): ReplacementComplexity {
    const loc = metrics.libCodeLines;
    const files = metrics.libFileCount;

    if (metrics.hasNativeCode) {
        const platforms = metrics.nativePlatforms.join(', ');
        return {
            level: 'native',
            metrics,
            summary: `${loc} lines + native code (${platforms})`,
        };
    }

    // Thresholds calibrated to real Dart packages: most useful packages are
    // 500–5000 LOC. Even 500 LOC is a day's work to migrate, not a project.
    if (loc < 100) {
        return {
            level: 'trivial',
            metrics,
            summary: formatSummary(loc, files, 'could inline'),
        };
    }

    if (loc < 500) {
        return {
            level: 'small',
            metrics,
            summary: formatSummary(loc, files, 'small fork'),
        };
    }

    if (loc < 2000) {
        return {
            level: 'moderate',
            metrics,
            summary: formatSummary(loc, files, 'moderate effort'),
        };
    }

    return {
        level: 'large',
        metrics,
        summary: formatSummary(loc, files, 'significant codebase'),
    };
}

function formatSummary(
    loc: number, files: number, hint: string,
): string {
    const locStr = loc.toLocaleString('en-US');
    const fileStr = files === 1 ? '1 file' : `${files} files`;
    return `${locStr} lines in ${fileStr} — ${hint}`;
}

/**
 * Enrich vibrancy results with replacement complexity from local package sources.
 *
 * Reads .dart_tool/package_config.json once, then analyzes each package's
 * lib/ directory in the local pub cache in parallel. Results are cached
 * per package@version (immutable — a given version never changes).
 */
export async function enrichReplacementComplexity(
    results: readonly VibrancyResult[],
    workspaceRoot: vscode.Uri,
    cache?: CacheService,
    logger?: ScanLogger,
): Promise<VibrancyResult[]> {
    const packagePaths = await resolvePackagePaths(workspaceRoot);

    if (packagePaths.size === 0) {
        logger?.info('No package paths resolved from .dart_tool/package_config.json');
        return results as VibrancyResult[];
    }

    // Analyze all packages in parallel — local filesystem reads are fast
    const complexities = await Promise.all(
        results.map(r => resolveComplexity(r, packagePaths, cache, logger)),
    );

    return results.map((r, i) => ({ ...r, replacementComplexity: complexities[i] }));
}

/** Resolve replacement complexity for a single package, using cache when available. */
async function resolveComplexity(
    result: VibrancyResult,
    packagePaths: ReadonlyMap<string, vscode.Uri>,
    cache?: CacheService,
    logger?: ScanLogger,
): Promise<ReplacementComplexity | null> {
    const cacheKey = `code.complexity.${result.package.name}@${result.package.version}`;
    const cached = cache?.get<ReplacementComplexity>(cacheKey);
    if (cached) { return cached; }

    const localPath = packagePaths.get(result.package.name);
    if (!localPath) { return null; }

    try {
        const metrics = await analyzePackageCode(localPath);
        const complexity = classifyReplacement(metrics);
        await cache?.set(cacheKey, complexity);
        return complexity;
    } catch {
        logger?.error(`Failed to analyze code for ${result.package.name}`);
        return null;
    }
}

// Import VibrancyResult type — placed at end to avoid circular dependency issues
import type { VibrancyResult } from '../types';
