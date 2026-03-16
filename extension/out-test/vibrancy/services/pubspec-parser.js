"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.parsePubspecYaml = parsePubspecYaml;
exports.parsePubspecLock = parsePubspecLock;
exports.findPackageRange = findPackageRange;
exports.parseDependencyOverrides = parseDependencyOverrides;
/**
 * Parse pubspec.yaml content to extract dependency names.
 */
function parsePubspecYaml(content) {
    const directDeps = [];
    const devDeps = [];
    const constraints = {};
    const lines = content.split('\n');
    let section = 'none';
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
        if (section === 'none') {
            continue;
        }
        const match = trimmed.match(/^\s{2}(\w[\w_]*)\s*:\s*(.*)/);
        if (match) {
            const name = match[1];
            (section === 'deps' ? directDeps : devDeps).push(name);
            const value = match[2].trim();
            if (value) {
                constraints[name] = value;
            }
        }
    }
    return { directDeps, devDeps, constraints };
}
/** Determine which section a package belongs to. */
function getSection(name, directSet, devSet) {
    if (directSet.has(name)) {
        return 'dependencies';
    }
    if (devSet.has(name)) {
        return 'dev_dependencies';
    }
    return 'transitive';
}
/**
 * Parse pubspec.lock content to extract package dependencies.
 */
function parsePubspecLock(lockContent, directDeps, constraints = {}, devDeps = []) {
    const packages = [];
    const lines = lockContent.split('\n');
    const directSet = new Set(directDeps);
    const devSet = new Set(devDeps);
    let currentName = null;
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
        if (!currentName) {
            continue;
        }
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
function findPackageRange(content, packageName) {
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
/**
 * Parse dependency_overrides section from pubspec.yaml content.
 * Returns array of package names that are overridden.
 */
function parseDependencyOverrides(content) {
    const overrides = [];
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
        if (!inOverrides) {
            continue;
        }
        const match = trimmed.match(/^\s{2}(\w[\w_]*)\s*:/);
        if (match) {
            overrides.push(match[1]);
        }
    }
    return overrides;
}
//# sourceMappingURL=pubspec-parser.js.map