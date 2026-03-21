/**
 * Pure string helper for Overview sidebar section rows (no VS Code dependency).
 * Keeps label formatting unit-testable in Node without loading `vscode`.
 */

/** Appends ` (count)` when count is a finite number; otherwise returns the base label. */
export function formatSidebarToggleLabel(baseLabel: string, count: number | undefined): string {
    if (count !== undefined && Number.isFinite(count)) {
        return `${baseLabel} (${count})`;
    }
    return baseLabel;
}
