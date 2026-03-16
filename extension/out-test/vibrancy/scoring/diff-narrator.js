"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.summarizeDiff = summarizeDiff;
exports.narrateDiff = narrateDiff;
/** One-line summary for a notification message. */
function summarizeDiff(diff) {
    const parts = [];
    if (diff.upgraded.length) {
        parts.push(`${diff.upgraded.length} upgraded`);
    }
    if (diff.downgraded.length) {
        parts.push(`${diff.downgraded.length} downgraded`);
    }
    if (diff.added.length) {
        parts.push(`${diff.added.length} added`);
    }
    if (diff.removed.length) {
        parts.push(`${diff.removed.length} removed`);
    }
    if (parts.length === 0) {
        return 'Lock file: no changes';
    }
    return `Lock file: ${parts.join(', ')}`;
}
/** Multi-line narrative for an output channel. */
function narrateDiff(diff) {
    const lines = [summarizeDiff(diff), ''];
    for (const u of diff.upgraded) {
        lines.push(`  ⬆ ${u.name} ${u.from} → ${u.to}`);
    }
    for (const d of diff.downgraded) {
        lines.push(`  ⬇ ${d.name} ${d.from} → ${d.to}`);
    }
    for (const a of diff.added) {
        lines.push(`  ➕ ${a.name} ${a.version}`);
    }
    for (const r of diff.removed) {
        lines.push(`  ➖ ${r.name} ${r.version}`);
    }
    return lines.join('\n');
}
//# sourceMappingURL=diff-narrator.js.map