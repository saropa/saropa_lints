/**
 * Bloat rating on a 0–10 scale.
 *
 * Operates on `codeSizeBytes` — what the package actually contributes to a
 * compiled Flutter app (`lib/**` + declared `flutter.assets:`). The earlier
 * model used gzipped tarball size, which over-reported by 100×+ for any
 * package that shipped sample media, demos, or fixture servers (see
 * plans/history/2026.05/2026.05.13/infra_vibrancy_bloat_uses_tarball_size_not_runtime.md).
 *
 * Logarithmic scale recalibrated for code-only sizing. Tarball thresholds
 * (50 KB / 1 MB / 50 MB) were too lenient at the low end and too strict at
 * the high end once `example/`, `test/`, `tool/`, `doc/` no longer count.
 * Starting anchors per the bug spec; will be tightened against a corpus
 * walk in a follow-up:
 *   0 = tiny      (< 10 KB)
 *   4 = medium    (~250 KB)
 *  10 = huge      (> 10 MB)
 */
export function calcBloatRating(codeSizeBytes: number): number {
    if (codeSizeBytes <= 0) { return 0; }
    const logSize = Math.log10(codeSizeBytes);
    /* log10(10 KB) = 4.0, log10(10 MB) = 7.0 → span of 3.0 → 0.3 per unit. */
    const rating = (logSize - 4.0) / 0.3;
    return Math.round(Math.min(10, Math.max(0, rating)));
}

/** Format bytes as a human-readable MB string. */
export function formatSizeMB(bytes: number): string {
    const mb = bytes / (1024 * 1024);
    if (mb < 0.01) { return '<0.01 MB'; }
    if (mb < 1) { return `${mb.toFixed(2)} MB`; }
    return `${mb.toFixed(1)} MB`;
}

/** Format bytes as a human-readable KB string with comma grouping. */
export function formatSizeKB(bytes: number): string {
    const kb = Math.round(bytes / 1024);
    return `${kb.toLocaleString('en-US')} KB`;
}
