const DEPENDENCY_SECTIONS = ['dependencies', 'dev_dependencies', 'dependency_overrides'];

interface ParsedDependencies {
    readonly dependencies: Map<string, string>;
    readonly devDependencies: Map<string, string>;
    readonly dependencyOverrides: Map<string, string>;
}

interface SectionMaps {
    deps: Map<string, string>;
    devDeps: Map<string, string>;
    overrides: Map<string, string>;
}

/**
 * Parse dependency sections from pubspec.yaml content.
 * Returns maps of package name -> version constraint for each section.
 */
function parseDependencies(content: string): ParsedDependencies {
    const dependencies = new Map<string, string>();
    const devDependencies = new Map<string, string>();
    const dependencyOverrides = new Map<string, string>();
    const maps: SectionMaps = { deps: dependencies, devDeps: devDependencies, overrides: dependencyOverrides };

    const lines = content.split('\n');
    let currentSection: string | null = null;
    let currentPackage: string | null = null;
    let multilineValue = '';

    for (const line of lines) {
        const trimmed = line.trimEnd();

        const sectionMatch = trimmed.match(/^(dependencies|dev_dependencies|dependency_overrides)\s*:$/);
        if (sectionMatch) {
            currentSection = sectionMatch[1];
            currentPackage = null;
            continue;
        }

        if (/^\S/.test(trimmed) && !DEPENDENCY_SECTIONS.some(s => trimmed.startsWith(s))) {
            currentSection = null;
            currentPackage = null;
            continue;
        }

        if (!currentSection) { continue; }

        const packageMatch = trimmed.match(/^\s{2}(\w[\w_-]*)\s*:\s*(.*)/);
        if (packageMatch) {
            const name = packageMatch[1];
            const value = packageMatch[2].trim();
            currentPackage = name;
            multilineValue = value;

            if (value && !value.endsWith('|') && !value.endsWith('>')) {
                addToSection(currentSection, name, value, maps);
                currentPackage = null;
            }
            continue;
        }

        if (currentPackage && /^\s{4,}\S/.test(line)) {
            multilineValue += '\n' + line;
        } else if (currentPackage) {
            addToSection(currentSection, currentPackage, multilineValue, maps);
            currentPackage = null;
        }
    }

    if (currentPackage && currentSection) {
        addToSection(currentSection, currentPackage, multilineValue, maps);
    }

    return { dependencies, devDependencies, dependencyOverrides };
}

function addToSection(
    section: string,
    name: string,
    value: string,
    maps: SectionMaps,
): void {
    const normalizedValue = normalizeValue(value);
    switch (section) {
        case 'dependencies':
            maps.deps.set(name, normalizedValue);
            break;
        case 'dev_dependencies':
            maps.devDeps.set(name, normalizedValue);
            break;
        case 'dependency_overrides':
            maps.overrides.set(name, normalizedValue);
            break;
    }
}

function normalizeValue(value: string): string {
    return value.trim().replace(/\s+/g, ' ');
}

function mapsEqual(a: Map<string, string>, b: Map<string, string>): boolean {
    if (a.size !== b.size) { return false; }
    for (const [key, val] of Array.from(a.entries())) {
        if (b.get(key) !== val) { return false; }
    }
    return true;
}

/**
 * Check if dependency sections have changed between two pubspec.yaml contents.
 * Compares dependencies, dev_dependencies, and dependency_overrides sections.
 * Returns true if any dependency was added, removed, or had its version changed.
 */
export function hasDependencyChanges(oldContent: string, newContent: string): boolean {
    try {
        const oldParsed = parseDependencies(oldContent);
        const newParsed = parseDependencies(newContent);

        if (!mapsEqual(oldParsed.dependencies, newParsed.dependencies)) {
            return true;
        }
        if (!mapsEqual(oldParsed.devDependencies, newParsed.devDependencies)) {
            return true;
        }
        if (!mapsEqual(oldParsed.dependencyOverrides, newParsed.dependencyOverrides)) {
            return true;
        }

        return false;
    } catch {
        return true;
    }
}

/**
 * Get a summary of what changed between two pubspec.yaml contents.
 * Useful for logging/debugging.
 */
export function getDependencyChangeSummary(
    oldContent: string,
    newContent: string,
): { added: string[]; removed: string[]; changed: string[] } {
    const added: string[] = [];
    const removed: string[] = [];
    const changed: string[] = [];

    try {
        const oldParsed = parseDependencies(oldContent);
        const newParsed = parseDependencies(newContent);

        const allOld = mergeAllDeps(oldParsed);
        const allNew = mergeAllDeps(newParsed);

        for (const [name, value] of Array.from(allNew.entries())) {
            if (!allOld.has(name)) {
                added.push(name);
            } else if (allOld.get(name) !== value) {
                changed.push(name);
            }
        }

        for (const name of Array.from(allOld.keys())) {
            if (!allNew.has(name)) {
                removed.push(name);
            }
        }
    } catch {
        // Return empty arrays on parse error
    }

    return { added, removed, changed };
}

function mergeAllDeps(parsed: ParsedDependencies): Map<string, string> {
    const merged = new Map<string, string>();
    for (const [k, v] of Array.from(parsed.dependencies.entries())) { merged.set(k, v); }
    for (const [k, v] of Array.from(parsed.devDependencies.entries())) { merged.set(k, v); }
    for (const [k, v] of Array.from(parsed.dependencyOverrides.entries())) { merged.set(k, v); }
    return merged;
}
