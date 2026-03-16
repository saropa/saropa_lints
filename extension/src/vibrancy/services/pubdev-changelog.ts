import { CacheService } from './cache-service';
import { fetchWithRetry } from './fetch-retry';

/**
 * Fetch changelog HTML from pub.dev and convert to markdown.
 * Used as fallback when GitHub API changelog is unavailable.
 */
export async function fetchPubDevChangelog(
    packageName: string,
    cache?: CacheService,
): Promise<string | null> {
    const cacheKey = `changelog.pubdev.${packageName}`;
    const cached = cache?.get<string>(cacheKey);
    if (cached !== null && cached !== undefined) { return cached; }

    try {
        const url = `https://pub.dev/packages/${packageName}/changelog`;
        const resp = await fetchWithRetry(url);
        if (!resp.ok) { return null; }

        const html = await resp.text();
        const md = parseChangelogHtml(html);
        if (!md) { return null; }

        await cache?.set(cacheKey, md);
        return md;
    } catch {
        return null;
    }
}

/** Convert pub.dev changelog HTML into markdown for parseAllEntries. */
export function parseChangelogHtml(html: string): string | null {
    const lines: string[] = [];

    // Split on h2 tags to isolate version sections
    const sections = html.split(/<h2[^>]*>/i);
    if (sections.length < 2) { return null; }

    for (let i = 1; i < sections.length; i++) {
        const section = sections[i];
        const closeIdx = section.indexOf('</h2>');
        if (closeIdx === -1) { continue; }

        const headingHtml = section.substring(0, closeIdx);
        const version = extractVersionFromHeading(headingHtml);
        if (!version) { continue; }

        lines.push(`## ${version}`);

        const body = section.substring(closeIdx + 5);
        lines.push(htmlBodyToMarkdown(body));
    }

    return lines.length > 0 ? lines.join('\n') : null;
}

function extractVersionFromHeading(html: string): string | null {
    const text = html.replace(/<[^>]+>/g, '').trim();
    const match = text.match(/(\d+\.\d+\.\d+)/);
    return match ? match[1] : null;
}

function htmlBodyToMarkdown(html: string): string {
    return html
        .replace(/<li[^>]*>/gi, '- ')
        .replace(/<\/li>/gi, '\n')
        .replace(/<br\s*\/?>/gi, '\n')
        .replace(/<[^>]+>/g, '')
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'");
}
