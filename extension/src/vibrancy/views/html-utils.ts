/** Escape text for safe inclusion in HTML content and attributes. */
export function escapeHtml(text: string): string {
    return text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

/**
 * Resolve the canonical repository URL from a VibrancyResult's GitHub or pub.dev data.
 * Returns empty string when no repository URL is available.
 * Strips trailing slashes for consistent URL construction (e.g. appending `/issues`).
 */
export function resolveRepoUrl(
    githubRepoUrl: string | undefined | null,
    pubDevRepoUrl: string | undefined | null,
): string {
    return (githubRepoUrl ?? pubDevRepoUrl ?? '').replace(/\/+$/, '');
}
