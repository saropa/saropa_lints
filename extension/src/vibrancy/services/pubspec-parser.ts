import { PackageDependency, PackageRange, DependencySection } from '../types';

/**
 * Parse pubspec.yaml content to extract dependency names.
 */
export function parsePubspecYaml(content: string): {
    directDeps: string[];
    devDeps: string[];
    constraints: Record<string, string>;
} {
    const directDeps: string[] = [];
    const devDeps: string[] = [];
    const constraints: Record<string, string> = {};
    const lines = content.split('\n');

    let section: 'none' | 'deps' | 'dev' = 'none';

    for (const line of lines) {
        const trimmed = line.trimEnd();

        if (/^dependencies\s*:/.test(trimmed)) {
            section = 'deps';
            continue;
        }
        if (/^dev_dependencies\s*:/.test(trimmed)) {
            section = 'dev';
            continue;
        }
        if (/^\S/.test(trimmed) && section !== 'none') {
            section = 'none';
        }
        if (section === 'none') { continue; }

        const match = trimmed.match(/^\s{2}(\w[\w_]*)\s*:\s*(.*)/);
        if (match) {
            const name = match[1];
            (section === 'deps' ? directDeps : devDeps).push(name);
            const value = match[2].trim();
            if (value) { constraints[name] = value; }
        }
    }

    return { directDeps, devDeps, constraints };
}

/** Determine which section a package belongs to. */
function getSection(
    name: string,
    directSet: Set<string>,
    devSet: Set<string>,
): DependencySection {
    if (directSet.has(name)) { return 'dependencies'; }
    if (devSet.has(name)) { return 'dev_dependencies'; }
    return 'transitive';
}

/**
 * Parse pubspec.lock content to extract package dependencies.
 */
export function parsePubspecLock(
    lockContent: string,
    directDeps: string[],
    constraints: Record<string, string> = {},
    devDeps: string[] = [],
): PackageDependency[] {
    const packages: PackageDependency[] = [];
    const lines = lockContent.split('\n');
    const directSet = new Set(directDeps);
    const devSet = new Set(devDeps);

    let currentName: string | null = null;
    let currentVersion = '';
    let currentSource = '';

    for (const rawLine of lines) {
        const line = rawLine.trimEnd();
        const nameMatch = line.match(/^\s{2}(\w[\w_-]*):$/);
        if (nameMatch) {
            if (currentName) {
                packages.push({
                    name: currentName,
                    version: currentVersion,
                    constraint: constraints[currentName] ?? currentVersion,
                    source: currentSource,
                    isDirect: directSet.has(currentName) || devSet.has(currentName),
                    section: getSection(currentName, directSet, devSet),
                });
            }
            currentName = nameMatch[1];
            currentVersion = '';
            currentSource = '';
            continue;
        }

        if (!currentName) { continue; }

        const versionMatch = line.match(/^\s+version:\s+"([^"]+)"/);
        if (versionMatch) {
            currentVersion = versionMatch[1];
        }

        const sourceMatch = line.match(/^\s+source:\s+(\S+)/);
        if (sourceMatch) {
            currentSource = sourceMatch[1];
        }
    }

    if (currentName) {
        packages.push({
            name: currentName,
            version: currentVersion,
            constraint: constraints[currentName] ?? currentVersion,
            source: currentSource,
            isDirect: directSet.has(currentName) || devSet.has(currentName),
            section: getSection(currentName, directSet, devSet),
        });
    }

    return packages;
}

/**
 * Find the line and character range of a package name in pubspec.yaml.
 */
export function findPackageRange(
    content: string,
    packageName: string,
): PackageRange | null {
    const lines = content.split('\n');
    const pattern = new RegExp(`^(\\s{2})(${packageName})(\\s*:)`);

    for (let i = 0; i < lines.length; i++) {
        const match = lines[i].match(pattern);
        if (match) {
            const startChar = match[1].length;
            return {
                line: i,
                startChar,
                endChar: startChar + packageName.length,
            };
        }
    }

    return null;
}

/** Parsed environment constraint values from pubspec.yaml. */
export interface EnvironmentConstraints {
    readonly sdk?: string;
    readonly flutter?: string;
}

/**
 * Iterate over lines inside the `environment:` section of pubspec.yaml.
 * Calls `visitor` for each indented line with its index and trimmed text.
 * Stops when a new top-level key appears.
 */
function forEachEnvironmentLine(
    lines: readonly string[],
    visitor: (lineIndex: number, trimmed: string) => boolean | void,
): void {
    let inSection = false;
    for (let i = 0; i < lines.length; i++) {
        const trimmed = lines[i].trimEnd();
        if (/^environment\s*:/.test(trimmed)) {
            inSection = true;
            continue;
        }
        if (inSection && /^\S/.test(trimmed)) { break; }
        if (!inSection) { continue; }
        // Return true from visitor to stop iteration early
        if (visitor(i, trimmed) === true) { break; }
    }
}

/**
 * Parse the environment section from pubspec.yaml content.
 * Extracts sdk and flutter version constraint strings.
 */
export function parseEnvironmentConstraints(
    content: string,
): EnvironmentConstraints {
    const result: { sdk?: string; flutter?: string } = {};
    forEachEnvironmentLine(content.split('\n'), (_i, trimmed) => {
        const match = trimmed.match(/^\s+(sdk|flutter)\s*:\s*"?([^"]*)"?\s*$/);
        if (match) {
            result[match[1] as 'sdk' | 'flutter'] = match[2].trim();
        }
    });
    return result;
}

/**
 * Find the line and character range of an environment key (sdk or flutter)
 * within the environment section of pubspec.yaml.
 * Highlights the value portion (the constraint string).
 */
export function findEnvironmentRange(
    content: string,
    key: 'sdk' | 'flutter',
): PackageRange | null {
    const lines = content.split('\n');
    let found: PackageRange | null = null;

    // Match e.g. '  sdk: ">=3.10.7 <4.0.0"' or '  flutter: ">=3.41.2"'
    const pattern = new RegExp(
        `^(\\s+${key}\\s*:\\s*"?)([^"]*?)("?\\s*)$`,
    );
    forEachEnvironmentLine(lines, (lineIndex) => {
        const match = lines[lineIndex].match(pattern);
        if (!match) { return; }
        found = {
            line: lineIndex,
            startChar: match[1].length,
            endChar: match[1].length + match[2].length,
        };
        return true; // Stop iteration — found the key
    });
    return found;
}

/**
 * Parse dependency_overrides section from pubspec.yaml content.
 * Returns array of package names that are overridden.
 */
export function parseDependencyOverrides(content: string): string[] {
    const overrides: string[] = [];
    const lines = content.split('\n');

    let inOverrides = false;

    for (const line of lines) {
        const trimmed = line.trimEnd();

        if (/^dependency_overrides\s*:/.test(trimmed)) {
            inOverrides = true;
            continue;
        }
        if (inOverrides && /^\S/.test(trimmed)) {
            break;
        }
        if (!inOverrides) { continue; }

        const match = trimmed.match(/^\s{2}(\w[\w_]*)\s*:/);
        if (match) {
            overrides.push(match[1]);
        }
    }

    return overrides;
}
