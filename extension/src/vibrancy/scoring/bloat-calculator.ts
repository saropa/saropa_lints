/**
 * Bloat rating on a 0–10 scale based on archive size.
 *
 * Logarithmic scale calibrated to Flutter package sizes:
 *   0 = tiny   (< 50 KB)
 *   4 = medium (~1 MB)
 *  10 = huge   (> 50 MB)
 */
export function calcBloatRating(archiveSizeBytes: number): number {
    if (archiveSizeBytes <= 0) { return 0; }
    const logSize = Math.log10(archiveSizeBytes);
    // log10(50 KB) ≈ 4.7, log10(50 MB) ≈ 7.7 → span of 3.0
    const rating = (logSize - 4.7) / 0.3;
    return Math.round(Math.min(10, Math.max(0, rating)));
}

/** Format bytes as a human-readable MB string. */
export function formatSizeMB(bytes: number): string {
    const mb = bytes / (1024 * 1024);
    if (mb < 0.01) { return '<0.01 MB'; }
    if (mb < 1) { return `${mb.toFixed(2)} MB`; }
    return `${mb.toFixed(1)} MB`;
}
