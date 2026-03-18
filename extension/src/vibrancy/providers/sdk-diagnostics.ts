import * as vscode from 'vscode';
import { FlutterRelease } from '../services/flutter-releases';
import {
    parseEnvironmentConstraints, findEnvironmentRange,
} from '../services/pubspec-parser';
import { PACKAGE_VIBRANCY_DOC_URL } from '../sdk-vibrancy-table';

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

/** True if a >= b. */
function isAtLeast(a: SemverParts, b: SemverParts): boolean {
    return !isGreaterThan(b, a);
}

/** Don't show "behind latest" when SDK minimum is already at or above this. */
const ACCEPTABLE_SDK_FLOOR: SemverParts = { major: 3, minor: 9, patch: 0 };

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

const SOURCE = 'Package Vibrancy';
const CODE = 'sdk-constraint';

/** Build a diagnostic with Package Vibrancy source and sdk-constraint code (link to doc). */
function createDiagnostic(
    range: vscode.Range,
    message: string,
    severity: vscode.DiagnosticSeverity,
): vscode.Diagnostic {
    const d = new vscode.Diagnostic(range, message, severity);
    d.source = SOURCE;
    d.code = { value: CODE, target: vscode.Uri.parse(PACKAGE_VIBRANCY_DOC_URL) };
    return d;
}

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

    // Upper bound excludes latest stable
    if (parsed.upperBound) {
        const upper = parseSemver(parsed.upperBound);
        if (upper && !isGreaterThan(upper, latestSemver)) {
            const msg = `${label} upper bound (<${parsed.upperBound}) excludes latest stable (${latestVersion})`;
            diagnostics.push(createDiagnostic(
                vscodeRange, msg, vscode.DiagnosticSeverity.Warning,
            ));
        }
    }

    // Check if min version is behind latest (only for Dart SDK; don't nag when already >= 3.9.0)
    if (parsed.min) {
        const minSemver = parseSemver(parsed.min);
        if (minSemver) {
            const atOrAboveFloor = key === 'sdk' && isAtLeast(minSemver, ACCEPTABLE_SDK_FLOOR);
            if (!atOrAboveFloor) {
                const status = classifyBehind(minSemver, latestSemver);
                const recommendation = key === 'sdk'
                    ? ' Aim for >=3.10.0; use >=3.9.0 only if you need to support more legacy setups.'
                    : '';
                if (status === 'minor') {
                    const msg = `${label} minimum (${parsed.min}) is behind latest stable (${latestVersion}).${recommendation}`;
                    diagnostics.push(createDiagnostic(
                        vscodeRange, msg, vscode.DiagnosticSeverity.Information,
                    ));
                } else if (status === 'patch') {
                    const msg = `${label} minimum (${parsed.min}) — latest stable is ${latestVersion}.${recommendation}`;
                    diagnostics.push(createDiagnostic(
                        vscodeRange, msg, vscode.DiagnosticSeverity.Hint,
                    ));
                }
            }
        }
    }

    return diagnostics;
}
