import { LockDiff } from '../services/lock-diff';

/** One-line summary for a notification message. */
export function summarizeDiff(diff: LockDiff): string {
    const parts: string[] = [];
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
    if (parts.length === 0) { return 'Lock file: no changes'; }
    return `Lock file: ${parts.join(', ')}`;
}

/** Multi-line narrative for an output channel. */
export function narrateDiff(diff: LockDiff): string {
    const lines: string[] = [summarizeDiff(diff), ''];

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
