import * as vscode from 'vscode';
import { FlutterRelease } from '../services/flutter-releases';
import {
    parseEnvironmentConstraints, findEnvironmentRange,
} from '../services/pubspec-parser';

interface SemverParts {
    readonly major: number;
    readonly minor: number;
    readonly patch: number;
}

/** Parse a semver string like "3.10.7". Ignores pre-release/build metadata. */
function parseSemver(version: string): SemverParts | null {
    const match = version.match(/^(\d+)\.(\d+)\.(\d+)/);
    if (!match) { return null; }
    return {
        major: parseInt(match[1], 10),
        minor: parseInt(match[2], 10),
        patch: parseInt(match[3], 10),
    };
}

function isGreaterThan(a: SemverParts, b: SemverParts): boolean {
    if (a.major !== b.major) { return a.major > b.major; }
    if (a.minor !== b.minor) { return a.minor > b.minor; }
    return a.patch > b.patch;
}

/** Parse a Dart/Flutter SDK constraint string into min and upper bound. */
function parseConstraint(
    constraint: string,
): { min?: string; upperBound?: string } {
    const result: { min?: string; upperBound?: string } = {};

    // Match >=X.Y.Z
    const minMatch = constraint.match(/>=\s*(\d+\.\d+\.\d+)/);
    if (minMatch) { result.min = minMatch[1]; }

    // Match <X.Y.Z (exclusive upper bound)
    const upperMatch = constraint.match(/<\s*(\d+\.\d+\.\d+)/);
    if (upperMatch) { result.upperBound = upperMatch[1]; }

    // Support caret syntax: ^X.Y.Z (treated as min only)
    if (!result.min) {
        const caretMatch = constraint.match(/\^\s*(\d+\.\d+\.\d+)/);
        if (caretMatch) { result.min = caretMatch[1]; }
    }

    return result;
}

/** Determine update severity based on how far behind the min version is. */
function classifyBehind(
    min: SemverParts,
    latest: SemverParts,
): 'minor' | 'patch' | 'up-to-date' {
    if (!isGreaterThan(latest, min)) { return 'up-to-date'; }
    if (latest.major > min.major || latest.minor > min.minor) {
        return 'minor';
    }
    return 'patch';
}

const SOURCE = 'Saropa Package Vibrancy';
const CODE = 'sdk-constraint';

/**
 * Generates inline diagnostics for SDK and Flutter version constraints
 * in the environment section of pubspec.yaml.
 */
export class SdkDiagnostics {
    constructor(
        private readonly _collection: vscode.DiagnosticCollection,
    ) {}

    /**
     * Update SDK diagnostics for a pubspec.yaml document.
     * Compares environment constraints against the latest stable release.
     */
    update(
        uri: vscode.Uri,
        content: string,
        releases: readonly FlutterRelease[],
    ): void {
        const diagnostics: vscode.Diagnostic[] = [];

        if (releases.length === 0) {
            // No release data available — nothing to compare against
            this._collection.set(uri, diagnostics);
            return;
        }

        const latest = releases[0];
        const constraints = parseEnvironmentConstraints(content);

        if (constraints.sdk) {
            const sdkDiags = buildConstraintDiagnostics(
                content, 'sdk', 'Dart SDK',
                constraints.sdk, latest.dartSdkVersion,
            );
            diagnostics.push(...sdkDiags);
        }

        if (constraints.flutter) {
            const flutterDiags = buildConstraintDiagnostics(
                content, 'flutter', 'Flutter',
                constraints.flutter, latest.version,
            );
            diagnostics.push(...flutterDiags);
        }

        this._collection.set(uri, diagnostics);
    }

    clear(): void {
        this._collection.clear();
    }
}

/** Build diagnostics for a single environment constraint (sdk or flutter). */
function buildConstraintDiagnostics(
    content: string,
    key: 'sdk' | 'flutter',
    label: string,
    constraint: string,
    latestVersion: string,
): vscode.Diagnostic[] {
    if (!latestVersion) { return []; }

    const range = findEnvironmentRange(content, key);
    if (!range) { return []; }

    const vscodeRange = new vscode.Range(
        range.line, range.startChar,
        range.line, range.endChar,
    );

    const parsed = parseConstraint(constraint);
    const latestSemver = parseSemver(latestVersion);
    if (!latestSemver) { return []; }

    const diagnostics: vscode.Diagnostic[] = [];

    // Check if upper bound excludes latest stable
    if (parsed.upperBound) {
        const upper = parseSemver(parsed.upperBound);
        if (upper && !isGreaterThan(upper, latestSemver)) {
            // Upper bound <= latest, so latest is excluded
            const msg = `${label} upper bound (<${parsed.upperBound}) excludes latest stable (${latestVersion})`;
            const diag = new vscode.Diagnostic(
                vscodeRange, msg, vscode.DiagnosticSeverity.Warning,
            );
            diag.source = SOURCE;
            diag.code = CODE;
            diagnostics.push(diag);
        }
    }

    // Check if min version is behind latest
    if (parsed.min) {
        const minSemver = parseSemver(parsed.min);
        if (minSemver) {
            const status = classifyBehind(minSemver, latestSemver);
            if (status === 'minor') {
                const msg = `${label} minimum (${parsed.min}) is behind latest stable (${latestVersion})`;
                const diag = new vscode.Diagnostic(
                    vscodeRange, msg, vscode.DiagnosticSeverity.Information,
                );
                diag.source = SOURCE;
                diag.code = CODE;
                diagnostics.push(diag);
            } else if (status === 'patch') {
                const msg = `${label} minimum (${parsed.min}) — latest stable is ${latestVersion}`;
                const diag = new vscode.Diagnostic(
                    vscodeRange, msg, vscode.DiagnosticSeverity.Hint,
                );
                diag.source = SOURCE;
                diag.code = CODE;
                diagnostics.push(diag);
            }
        }
    }

    return diagnostics;
}
