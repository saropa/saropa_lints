export interface LockDiffEntry {
    readonly name: string;
    readonly version: string;
}

export interface LockDiffChange {
    readonly name: string;
    readonly from: string;
    readonly to: string;
}

export interface LockDiff {
    readonly added: readonly LockDiffEntry[];
    readonly removed: readonly LockDiffEntry[];
    readonly upgraded: readonly LockDiffChange[];
    readonly downgraded: readonly LockDiffChange[];
    readonly unchangedCount: number;
}

/** Compare old versions map against new versions map. */
export function diffVersionMaps(
    oldVersions: ReadonlyMap<string, string>,
    newVersions: ReadonlyMap<string, string>,
): LockDiff {
    const added: LockDiffEntry[] = [];
    const removed: LockDiffEntry[] = [];
    const upgraded: LockDiffChange[] = [];
    const downgraded: LockDiffChange[] = [];
    let unchangedCount = 0;

    for (const [name, ver] of newVersions) {
        const old = oldVersions.get(name);
        if (!old) {
            added.push({ name, version: ver });
        } else if (old !== ver) {
            const change: LockDiffChange = { name, from: old, to: ver };
            const target = compareVersionStrings(old, ver) < 0
                ? upgraded : downgraded;
            target.push(change);
        } else {
            unchangedCount++;
        }
    }

    for (const [name, ver] of oldVersions) {
        if (!newVersions.has(name)) {
            removed.push({ name, version: ver });
        }
    }

    return { added, removed, upgraded, downgraded, unchangedCount };
}

function compareVersionStrings(a: string, b: string): number {
    const pa = parseSegments(a);
    const pb = parseSegments(b);
    const len = Math.max(pa.length, pb.length);
    for (let i = 0; i < len; i++) {
        const diff = (pa[i] ?? 0) - (pb[i] ?? 0);
        if (diff !== 0) { return diff; }
    }
    return 0;
}

/** Parse version segments, stripping pre-release/build suffixes. */
function parseSegments(ver: string): number[] {
    const base = ver.replace(/[-+].*$/, '');
    return base.split('.').map(Number);
}
