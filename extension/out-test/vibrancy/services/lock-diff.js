"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.diffVersionMaps = diffVersionMaps;
/** Compare old versions map against new versions map. */
function diffVersionMaps(oldVersions, newVersions) {
    const added = [];
    const removed = [];
    const upgraded = [];
    const downgraded = [];
    let unchangedCount = 0;
    for (const [name, ver] of newVersions) {
        const old = oldVersions.get(name);
        if (!old) {
            added.push({ name, version: ver });
        }
        else if (old !== ver) {
            const change = { name, from: old, to: ver };
            const target = compareVersionStrings(old, ver) < 0
                ? upgraded : downgraded;
            target.push(change);
        }
        else {
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
function compareVersionStrings(a, b) {
    const pa = parseSegments(a);
    const pb = parseSegments(b);
    const len = Math.max(pa.length, pb.length);
    for (let i = 0; i < len; i++) {
        const diff = (pa[i] ?? 0) - (pb[i] ?? 0);
        if (diff !== 0) {
            return diff;
        }
    }
    return 0;
}
/** Parse version segments, stripping pre-release/build suffixes. */
function parseSegments(ver) {
    const base = ver.replace(/[-+].*$/, '');
    return base.split('.').map(Number);
}
//# sourceMappingURL=lock-diff.js.map