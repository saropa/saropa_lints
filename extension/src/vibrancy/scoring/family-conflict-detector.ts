import { VibrancyResult, FamilySplit, FamilyVersionGroup } from '../types';
import { matchFamily } from '../data/package-families';

interface FamilyMember {
    readonly name: string;
    readonly majorVersion: number;
}

/**
 * Detect version splits within known package families.
 * Pure function — no I/O, no VS Code API.
 */
export function detectFamilySplits(
    results: readonly VibrancyResult[],
): FamilySplit[] {
    const families = groupByFamily(results);
    const splits: FamilySplit[] = [];

    for (const [familyId, members] of families) {
        const groups = groupByMajor(members);
        if (groups.length < 2) { continue; }

        const match = matchFamily(members[0].name);
        if (!match) { continue; }

        splits.push({
            familyId,
            familyLabel: match.label,
            versionGroups: groups,
            suggestion: buildSuggestion(match.label, groups),
        });
    }

    return splits;
}

function groupByFamily(
    results: readonly VibrancyResult[],
): Map<string, FamilyMember[]> {
    const families = new Map<string, FamilyMember[]>();

    for (const result of results) {
        const match = matchFamily(result.package.name);
        if (!match) { continue; }

        const major = parseMajor(result.package.version);
        if (major === null) { continue; }

        const members = families.get(match.id) ?? [];
        members.push({ name: result.package.name, majorVersion: major });
        families.set(match.id, members);
    }

    return families;
}

function groupByMajor(
    members: readonly FamilyMember[],
): FamilyVersionGroup[] {
    const byMajor = new Map<number, string[]>();

    for (const m of members) {
        const list = byMajor.get(m.majorVersion) ?? [];
        list.push(m.name);
        byMajor.set(m.majorVersion, list);
    }

    return [...byMajor.entries()]
        .sort(([a], [b]) => a - b)
        .map(([majorVersion, packages]) => ({ majorVersion, packages }));
}

function buildSuggestion(
    label: string,
    groups: readonly FamilyVersionGroup[],
): string {
    const latest = groups[groups.length - 1];
    const outdated = groups
        .filter(g => g.majorVersion !== latest.majorVersion)
        .flatMap(g => g.packages);

    return `Upgrade ${outdated.join(', ')} to align the ${label} family`;
}

function parseMajor(version: string): number | null {
    const dot = version.indexOf('.');
    const str = dot === -1 ? version : version.substring(0, dot);
    const num = parseInt(str, 10);
    return Number.isNaN(num) ? null : num;
}
