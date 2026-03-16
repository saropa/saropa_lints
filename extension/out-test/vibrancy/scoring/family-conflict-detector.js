"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.detectFamilySplits = detectFamilySplits;
const package_families_1 = require("../data/package-families");
/**
 * Detect version splits within known package families.
 * Pure function — no I/O, no VS Code API.
 */
function detectFamilySplits(results) {
    const families = groupByFamily(results);
    const splits = [];
    for (const [familyId, members] of families) {
        const groups = groupByMajor(members);
        if (groups.length < 2) {
            continue;
        }
        const match = (0, package_families_1.matchFamily)(members[0].name);
        if (!match) {
            continue;
        }
        splits.push({
            familyId,
            familyLabel: match.label,
            versionGroups: groups,
            suggestion: buildSuggestion(match.label, groups),
        });
    }
    return splits;
}
function groupByFamily(results) {
    const families = new Map();
    for (const result of results) {
        const match = (0, package_families_1.matchFamily)(result.package.name);
        if (!match) {
            continue;
        }
        const major = parseMajor(result.package.version);
        if (major === null) {
            continue;
        }
        const members = families.get(match.id) ?? [];
        members.push({ name: result.package.name, majorVersion: major });
        families.set(match.id, members);
    }
    return families;
}
function groupByMajor(members) {
    const byMajor = new Map();
    for (const m of members) {
        const list = byMajor.get(m.majorVersion) ?? [];
        list.push(m.name);
        byMajor.set(m.majorVersion, list);
    }
    return [...byMajor.entries()]
        .sort(([a], [b]) => a - b)
        .map(([majorVersion, packages]) => ({ majorVersion, packages }));
}
function buildSuggestion(label, groups) {
    const latest = groups[groups.length - 1];
    const outdated = groups
        .filter(g => g.majorVersion !== latest.majorVersion)
        .flatMap(g => g.packages);
    return `Upgrade ${outdated.join(', ')} to align the ${label} family`;
}
function parseMajor(version) {
    const dot = version.indexOf('.');
    const str = dot === -1 ? version : version.substring(0, dot);
    const num = parseInt(str, 10);
    return Number.isNaN(num) ? null : num;
}
//# sourceMappingURL=family-conflict-detector.js.map