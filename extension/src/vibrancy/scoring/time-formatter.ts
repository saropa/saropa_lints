/**
 * Format a number of days as a human-readable relative time string.
 * Uses 30-day months (approximate). Negative or fractional values are
 * clamped to "today".
 */
export function formatRelativeTime(days: number): string {
    // Guard against negative values (clock skew) and fractional days
    const wholeDays = Math.max(0, Math.floor(days));
    if (wholeDays === 0) { return 'today'; }
    if (wholeDays === 1) { return 'yesterday'; }
    if (wholeDays < 30) { return `${wholeDays} days ago`; }
    const months = Math.floor(wholeDays / 30);
    if (months === 1) { return '1 month ago'; }
    if (wholeDays < 365) { return `${months} months ago`; }
    const years = Math.floor(wholeDays / 365);
    if (years === 1) { return '1 year ago'; }
    return `${years} years ago`;
}
