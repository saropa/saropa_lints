"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.hasDependencyChanges = hasDependencyChanges;
exports.getDependencyChangeSummary = getDependencyChangeSummary;
const DEPENDENCY_SECTIONS = ['dependencies', 'dev_dependencies', 'dependency_overrides'];
/**
 * Parse dependency sections from pubspec.yaml content.
 * Returns maps of package name -> version constraint for each section.
 */
function parseDependencies(content) {
    const dependencies = new Map();
    const devDependencies = new Map();
    const dependencyOverrides = new Map();
    const maps = { deps: dependencies, devDeps: devDependencies, overrides: dependencyOverrides };
    const lines = content.split('\n');
    let currentSection = null;
    let currentPackage = null;
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
        if (!currentSection) {
            continue;
        }
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
        }
        else if (currentPackage) {
            addToSection(currentSection, currentPackage, multilineValue, maps);
            currentPackage = null;
        }
    }
    if (currentPackage && currentSection) {
        addToSection(currentSection, currentPackage, multilineValue, maps);
    }
    return { dependencies, devDependencies, dependencyOverrides };
}
function addToSection(section, name, value, maps) {
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
function normalizeValue(value) {
    return value.trim().replace(/\s+/g, ' ');
}
function mapsEqual(a, b) {
    if (a.size !== b.size) {
        return false;
    }
    for (const [key, val] of Array.from(a.entries())) {
        if (b.get(key) !== val) {
            return false;
        }
    }
    return true;
}
/**
 * Check if dependency sections have changed between two pubspec.yaml contents.
 * Compares dependencies, dev_dependencies, and dependency_overrides sections.
 * Returns true if any dependency was added, removed, or had its version changed.
 */
function hasDependencyChanges(oldContent, newContent) {
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
    }
    catch {
        return true;
    }
}
/**
 * Get a summary of what changed between two pubspec.yaml contents.
 * Useful for logging/debugging.
 */
function getDependencyChangeSummary(oldContent, newContent) {
    const added = [];
    const removed = [];
    const changed = [];
    try {
        const oldParsed = parseDependencies(oldContent);
        const newParsed = parseDependencies(newContent);
        const allOld = mergeAllDeps(oldParsed);
        const allNew = mergeAllDeps(newParsed);
        for (const [name, value] of Array.from(allNew.entries())) {
            if (!allOld.has(name)) {
                added.push(name);
            }
            else if (allOld.get(name) !== value) {
                changed.push(name);
            }
        }
        for (const name of Array.from(allOld.keys())) {
            if (!allNew.has(name)) {
                removed.push(name);
            }
        }
    }
    catch {
        // Return empty arrays on parse error
    }
    return { added, removed, changed };
}
function mergeAllDeps(parsed) {
    const merged = new Map();
    for (const [k, v] of Array.from(parsed.dependencies.entries())) {
        merged.set(k, v);
    }
    for (const [k, v] of Array.from(parsed.devDependencies.entries())) {
        merged.set(k, v);
    }
    for (const [k, v] of Array.from(parsed.dependencyOverrides.entries())) {
        merged.set(k, v);
    }
    return merged;
}
//# sourceMappingURL=dependency-differ.js.map