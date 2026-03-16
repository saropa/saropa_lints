"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.fetchPubDevChangelog = fetchPubDevChangelog;
exports.parseChangelogHtml = parseChangelogHtml;
const fetch_retry_1 = require("./fetch-retry");
/**
 * Fetch changelog HTML from pub.dev and convert to markdown.
 * Used as fallback when GitHub API changelog is unavailable.
 */
async function fetchPubDevChangelog(packageName, cache) {
    const cacheKey = `changelog.pubdev.${packageName}`;
    const cached = cache?.get(cacheKey);
    if (cached !== null && cached !== undefined) {
        return cached;
    }
    try {
        const url = `https://pub.dev/packages/${packageName}/changelog`;
        const resp = await (0, fetch_retry_1.fetchWithRetry)(url);
        if (!resp.ok) {
            return null;
        }
        const html = await resp.text();
        const md = parseChangelogHtml(html);
        if (!md) {
            return null;
        }
        await cache?.set(cacheKey, md);
        return md;
    }
    catch {
        return null;
    }
}
/** Convert pub.dev changelog HTML into markdown for parseAllEntries. */
function parseChangelogHtml(html) {
    const lines = [];
    // Split on h2 tags to isolate version sections
    const sections = html.split(/<h2[^>]*>/i);
    if (sections.length < 2) {
        return null;
    }
    for (let i = 1; i < sections.length; i++) {
        const section = sections[i];
        const closeIdx = section.indexOf('</h2>');
        if (closeIdx === -1) {
            continue;
        }
        const headingHtml = section.substring(0, closeIdx);
        const version = extractVersionFromHeading(headingHtml);
        if (!version) {
            continue;
        }
        lines.push(`## ${version}`);
        const body = section.substring(closeIdx + 5);
        lines.push(htmlBodyToMarkdown(body));
    }
    return lines.length > 0 ? lines.join('\n') : null;
}
function extractVersionFromHeading(html) {
    const text = html.replace(/<[^>]+>/g, '').trim();
    const match = text.match(/(\d+\.\d+\.\d+)/);
    return match ? match[1] : null;
}
function htmlBodyToMarkdown(html) {
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
//# sourceMappingURL=pubdev-changelog.js.map