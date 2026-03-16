import { OverrideEntry } from '../types';

/**
 * Parse the dependency_overrides section from pubspec.yaml content.
 * Returns an array of override entries with package names, versions, and line numbers.
 */
export function parseOverrides(yamlContent: string): OverrideEntry[] {
    const lines = yamlContent.split('\n');
    const overrides: OverrideEntry[] = [];

    let inOverrides = false;
    let currentPackage: string | null = null;
    let currentLine = -1;
    let isPathDep = false;
    let isGitDep = false;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const trimmed = line.trimEnd();

        if (/^dependency_overrides\s*:/.test(trimmed)) {
            inOverrides = true;
            continue;
        }

        if (inOverrides && /^\S/.test(trimmed) && !trimmed.startsWith('#')) {
            inOverrides = false;
            flushCurrent();
            continue;
        }

        if (!inOverrides) { continue; }

        const packageMatch = trimmed.match(/^\s{2}(\w[\w_]*)\s*:\s*(.*)/);
        if (packageMatch) {
            flushCurrent();
            currentPackage = packageMatch[1];
            currentLine = i;
            isPathDep = false;
            isGitDep = false;

            const value = packageMatch[2].trim();
            const isInlineVersion = value
                && !value.startsWith('#')
                && isVersionConstraint(value);
            if (isInlineVersion) {
                overrides.push({
                    name: currentPackage,
                    version: value,
                    line: currentLine,
                    isPathDep: false,
                    isGitDep: false,
                });
                currentPackage = null;
            }
            continue;
        }

        if (currentPackage) {
            const pathMatch = trimmed.match(/^\s{4}path\s*:\s*(.+)/);
            if (pathMatch) {
                isPathDep = true;
                continue;
            }

            const gitMatch = trimmed.match(/^\s{4}git\s*:/);
            if (gitMatch) {
                isGitDep = true;
                continue;
            }

            const versionMatch = trimmed.match(/^\s{4}version\s*:\s*(.+)/);
            if (versionMatch) {
                overrides.push({
                    name: currentPackage,
                    version: versionMatch[1].trim(),
                    line: currentLine,
                    isPathDep,
                    isGitDep,
                });
                currentPackage = null;
            }
        }
    }

    flushCurrent();
    return overrides;

    function flushCurrent(): void {
        if (currentPackage && currentLine >= 0) {
            overrides.push({
                name: currentPackage,
                version: isPathDep ? 'path' : isGitDep ? 'git' : 'any',
                line: currentLine,
                isPathDep,
                isGitDep,
            });
            currentPackage = null;
        }
    }
}

/**
 * Check if a string looks like a version constraint (e.g., "^1.0.0", "1.0.0", ">=1.0.0").
 */
function isVersionConstraint(value: string): boolean {
    const cleaned = value.replace(/["']/g, '').trim();
    return /^[\^~<>=]*\d/.test(cleaned) || cleaned === 'any';
}

/**
 * Find the line range of the dependency_overrides section in pubspec.yaml.
 * Returns { startLine, endLine } or null if not found.
 */
export function findOverridesSection(
    yamlContent: string,
): { startLine: number; endLine: number } | null {
    const lines = yamlContent.split('\n');
    let startLine = -1;
    let endLine = -1;

    for (let i = 0; i < lines.length; i++) {
        const trimmed = lines[i].trimEnd();
        if (/^dependency_overrides\s*:/.test(trimmed)) {
            startLine = i;
            continue;
        }
        if (startLine >= 0 && /^\S/.test(trimmed) && !trimmed.startsWith('#')) {
            endLine = i - 1;
            break;
        }
    }

    if (startLine < 0) { return null; }
    if (endLine < 0) { endLine = lines.length - 1; }

    return { startLine, endLine };
}

/**
 * Find the line range for a specific override entry in pubspec.yaml.
 * Returns { startLine, endLine } for the full override block.
 */
export function findOverrideRange(
    yamlContent: string,
    packageName: string,
): { startLine: number; endLine: number } | null {
    const lines = yamlContent.split('\n');
    let inOverrides = false;
    let startLine = -1;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const trimmed = line.trimEnd();

        if (/^dependency_overrides\s*:/.test(trimmed)) {
            inOverrides = true;
            continue;
        }

        if (inOverrides && /^\S/.test(trimmed) && !trimmed.startsWith('#')) {
            break;
        }

        if (!inOverrides) { continue; }

        const packageMatch = trimmed.match(/^\s{2}(\w[\w_]*)\s*:/);
        if (packageMatch) {
            if (startLine >= 0) {
                return { startLine, endLine: i - 1 };
            }
            if (packageMatch[1] === packageName) {
                startLine = i;
            }
        }
    }

    if (startLine >= 0) {
        let endLine = startLine;
        for (let i = startLine + 1; i < lines.length; i++) {
            const trimmed = lines[i].trimEnd();
            if (/^\s{2}\w/.test(trimmed) || /^\S/.test(trimmed)) {
                break;
            }
            if (trimmed.startsWith('    ') || trimmed === '') {
                endLine = i;
            }
        }
        return { startLine, endLine };
    }

    return null;
}
