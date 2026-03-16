import * as assert from 'assert';
import { buildReportHtml } from '../../../vibrancy/views/report-html';
import { VibrancyResult } from '../../../vibrancy/types';

function makeResult(
    name: string,
    score: number,
    category: VibrancyResult['category'] = 'vibrant',
): VibrancyResult {
    return {
        package: { name, version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: {
            name,
            latestVersion: '1.0.0',
            publishedDate: '2025-06-01T00:00:00Z',
            repositoryUrl: null,
            isDiscontinued: false,
            isUnlisted: false,
            pubPoints: 100,
            publisher: null,
            license: null,
            description: null,
            topics: [],
        },
        github: { stars: 42, openIssues: 5, closedIssuesLast90d: 3,
            mergedPrsLast90d: 2, avgCommentsPerIssue: 1.5,
            daysSinceLastUpdate: 3, daysSinceLastClose: 7, flaggedIssues: [], license: null },
        knownIssue: null,
        score,
        category,
        resolutionVelocity: 50,
        engagementLevel: 40,
        popularity: 30,
        publisherTrust: 0,
        updateInfo: null,
        archiveSizeBytes: null,
        bloatRating: null,
        license: null,
        drift: null,
        isUnused: false, platforms: null, verifiedPublisher: false, wasmReady: null, blocker: null, upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null, alternatives: [], latestPrerelease: null, prereleaseTag: null, vulnerabilities: [],
    };
}

describe('buildReportHtml', () => {
    it('should return valid HTML with doctype', () => {
        const html = buildReportHtml([]);
        assert.ok(html.startsWith('<!DOCTYPE html>'));
        assert.ok(html.includes('</html>'));
    });

    it('should show package count and average score', () => {
        const html = buildReportHtml([
            makeResult('http', 80),
            makeResult('bloc', 60),
        ]);
        assert.ok(html.includes('>2<'));
        assert.ok(html.includes('>7/10<'));
    });

    it('should include package rows in table', () => {
        const html = buildReportHtml([makeResult('http', 80)]);
        assert.ok(html.includes('data-name="http"'));
        assert.ok(html.includes('pub.dev/packages/http'));
    });

    it('should count categories correctly', () => {
        const html = buildReportHtml([
            makeResult('a', 80, 'vibrant'),
            makeResult('b', 50, 'quiet'),
            makeResult('c', 20, 'legacy-locked'),
            makeResult('d', 5, 'stale'),
            makeResult('e', 0, 'end-of-life'),
        ]);
        assert.ok(html.includes('class="summary-card vibrant"'));
        assert.ok(html.includes('class="summary-card stale"'));
        assert.ok(html.includes('class="summary-card eol"'));
    });

    it('should escape HTML in package names', () => {
        const result = makeResult('<script>alert(1)</script>', 50, 'quiet');
        const html = buildReportHtml([result]);
        assert.ok(!html.includes('<script>alert(1)</script>'));
        assert.ok(html.includes('&lt;script&gt;'));
    });

    it('should include CSP meta tag', () => {
        const html = buildReportHtml([]);
        assert.ok(html.includes('Content-Security-Policy'));
    });

    it('should handle empty results', () => {
        const html = buildReportHtml([]);
        assert.ok(html.includes('>0<'));
    });

    it('should include sort arrows in table headers', () => {
        const html = buildReportHtml([]);
        assert.ok(html.includes('class="sort-arrow"'));
    });

    it('should show unused badge for unused packages', () => {
        const result: VibrancyResult = { ...makeResult('http', 80), isUnused: true };
        const html = buildReportHtml([result]);
        assert.ok(html.includes('badge-unused'));
        assert.ok(html.includes('data-status="unused"'));
    });

    it('should show unused count in summary', () => {
        const results = [
            makeResult('http', 80),
            { ...makeResult('bloc', 60), isUnused: true },
        ];
        const html = buildReportHtml(results);
        assert.ok(html.includes('class="summary-card unused"'));
    });

    it('should show dash for non-unused packages in Status column', () => {
        const html = buildReportHtml([makeResult('http', 80)]);
        assert.ok(html.includes('data-status="ok"'));
    });
});
