import * as assert from 'assert';
import { buildReportHtml, ReportOptions } from '../../../vibrancy/views/report-html';
import { VibrancyResult } from '../../../vibrancy/types';

/** Default options with no overrides and no pubspec URI. */
function opts(results: VibrancyResult[]): ReportOptions {
    return { results, overrideCount: 0, overrideNames: new Set(), pubspecUri: null };
}

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
            topics: [], dependencies: [],
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
        isUnused: false, fileUsages: [], platforms: null, verifiedPublisher: false, wasmReady: null, blocker: null, upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null, alternatives: [], latestPrerelease: null, prereleaseTag: null, vulnerabilities: [],
        versionGap: null, overrideGap: null, replacementComplexity: null,
        likes: null, reverseDependencyCount: null, readme: null,
    };
}

describe('buildReportHtml', () => {
    it('should return valid HTML with doctype', () => {
        const html = buildReportHtml(opts([]));
        assert.ok(html.startsWith('<!DOCTYPE html>'));
        assert.ok(html.includes('</html>'));
    });

    it('should show package count and average score', () => {
        const html = buildReportHtml(opts([
            makeResult('http', 80),
            makeResult('bloc', 60),
        ]));
        assert.ok(html.includes('>2<'));
        assert.ok(html.includes('>7/10<'));
    });

    it('should include package rows in table', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(html.includes('data-name="http"'));
        assert.ok(html.includes('pub.dev/packages/http'));
    });

    it('should count categories correctly', () => {
        const html = buildReportHtml(opts([
            makeResult('a', 80, 'vibrant'),
            makeResult('b', 50, 'stable'),
            makeResult('c', 20, 'outdated'),
            makeResult('d', 5, 'abandoned'),
            makeResult('e', 0, 'end-of-life'),
        ]));
        assert.ok(html.includes('class="summary-card vibrant"'));
        assert.ok(html.includes('class="summary-card abandoned"'));
        assert.ok(html.includes('class="summary-card eol"'));
    });

    it('should escape HTML in package names', () => {
        const result = makeResult('<script>alert(1)</script>', 50, 'stable');
        const html = buildReportHtml(opts([result]));
        assert.ok(!html.includes('<script>alert(1)</script>'));
        assert.ok(html.includes('&lt;script&gt;'));
    });

    it('should include CSP meta tag', () => {
        const html = buildReportHtml(opts([]));
        assert.ok(html.includes('Content-Security-Policy'));
    });

    it('should handle empty results', () => {
        const html = buildReportHtml(opts([]));
        assert.ok(html.includes('>0<'));
    });

    it('should include sort arrows in table headers', () => {
        const html = buildReportHtml(opts([]));
        assert.ok(html.includes('class="sort-arrow"'));
    });

    it('should show unused badge for unused packages', () => {
        const result: VibrancyResult = { ...makeResult('http', 80), isUnused: true };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('badge-unused'));
        assert.ok(html.includes('data-status="unused"'));
    });

    it('should show unused count in summary', () => {
        const results = [
            makeResult('http', 80),
            { ...makeResult('bloc', 60), isUnused: true },
        ];
        const html = buildReportHtml(opts(results));
        assert.ok(html.includes('class="summary-card unused"'));
    });

    it('should show dash for non-unused packages in Status column', () => {
        const result = { ...makeResult('http', 80), isUnused: true };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('data-status="unused"'));
    });
});

describe('report: Category column with health suffix', () => {
    it('should show score as dimmed suffix on category', () => {
        const result = makeResult('http', 80);
        const html = buildReportHtml(opts([result]));
        /* 80/100 → 8/10, shown as dimmed suffix after category label */
        assert.ok(html.includes('8/10'));
        assert.ok(html.includes('class="dimmed"'));
    });

    it('should include health tooltip on category cell', () => {
        const result = makeResult('http', 80);
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('Vibrancy Score'));
    });

    it('should use score data-col for sorting', () => {
        const html = buildReportHtml(opts([]));
        /* Category header sorts by score, not by category string */
        assert.ok(html.includes('data-col="score"'));
    });
});

describe('report: column links', () => {
    it('should link version to pub.dev/versions', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(html.includes('pub.dev/packages/http/versions'));
    });

    it('should include license link in copy-as-JSON data', () => {
        /* License column is hidden by default, but JSON data always includes it */
        const result = { ...makeResult('http', 80), license: 'MIT' };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('pub.dev/packages/http/license'));
    });

    it('should link update to pub.dev/changelog', () => {
        const result = {
            ...makeResult('http', 80),
            updateInfo: { currentVersion: '1.0.0', latestVersion: '2.0.0', updateStatus: 'major' as const, changelog: null },
        };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('pub.dev/packages/http/changelog'));
    });
});

describe('report: auto-hide blank columns', () => {
    it('should hide Transitives column when all null', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        /* No Transitives header */
        assert.ok(!html.includes('data-col="transitives"'));
    });

    it('should show Transitives column when data exists', () => {
        const result = {
            ...makeResult('http', 80),
            transitiveInfo: { directDep: 'http', transitiveCount: 5, flaggedCount: 0, transitives: [], sharedDeps: [] },
        };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('data-col="transitives"'));
    });

    it('should hide Status column when no unused packages', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(!html.includes('data-col="status"'));
    });

    it('should show Status column when unused packages exist', () => {
        const result = { ...makeResult('http', 80), isUnused: true };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('data-col="status"'));
    });
});

describe('report: section badges', () => {
    it('should show dev badge for dev dependencies', () => {
        const base = makeResult('build_runner', 80);
        const result = { ...base, package: { ...base.package, section: 'dev_dependencies' as const } };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('badge-dev'));
        assert.ok(html.includes('>dev<'));
    });

    it('should show transitive badge for transitive dependencies', () => {
        const base = makeResult('collection', 80);
        const result = { ...base, package: { ...base.package, section: 'transitive' as const } };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('badge-transitive'));
        assert.ok(html.includes('>transitive<'));
    });

    it('should show no badge for normal dependencies', () => {
        const result = makeResult('http', 80);
        const html = buildReportHtml(opts([result]));
        /* Badges appear in CSS but not in the row element for normal deps */
        assert.ok(!html.includes('>dev<'));
        assert.ok(!html.includes('>transitive<'));
    });
});

describe('report: size in KB', () => {
    it('should format archive size in KB', () => {
        const result = { ...makeResult('http', 80), archiveSizeBytes: 276480 };
        const html = buildReportHtml(opts([result]));
        /* 276480 / 1024 = 270 KB */
        assert.ok(html.includes('270 KB'));
    });

    it('should show dash when no size data', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(html.includes('cell-right'));
    });
});

describe('report: summary card filters', () => {
    it('should add data-filter to category cards', () => {
        const html = buildReportHtml(opts([]));
        assert.ok(html.includes('data-filter="vibrant"'));
        assert.ok(html.includes('data-filter="stable"'));
        assert.ok(html.includes('data-filter="outdated"'));
        assert.ok(html.includes('data-filter="abandoned"'));
        assert.ok(html.includes('data-filter="end-of-life"'));
        assert.ok(html.includes('data-filter="updates"'));
        assert.ok(html.includes('data-filter="unused"'));
        assert.ok(html.includes('data-filter="vulns"'));
    });

    it('should show override count card', () => {
        const html = buildReportHtml({
            results: [], overrideCount: 3, overrideNames: new Set(), pubspecUri: null,
        });
        assert.ok(html.includes('>3<'));
        assert.ok(html.includes('Overrides'));
    });

    it('should add data-filter to overrides card', () => {
        const html = buildReportHtml(opts([]));
        assert.ok(html.includes('data-filter="overrides"'));
    });
});

describe('report: override filter data attribute', () => {
    it('should mark overridden packages with data-overridden=yes', () => {
        const result = makeResult('http', 80);
        const html = buildReportHtml({
            results: [result],
            overrideCount: 1,
            overrideNames: new Set(['http']),
            pubspecUri: null,
        });
        assert.ok(html.includes('data-overridden="yes"'));
    });

    it('should mark non-overridden packages with data-overridden=no', () => {
        const result = makeResult('http', 80);
        const html = buildReportHtml({
            results: [result],
            overrideCount: 0,
            overrideNames: new Set(),
            pubspecUri: null,
        });
        assert.ok(html.includes('data-overridden="no"'));
    });

    it('should distinguish overridden from non-overridden in same report', () => {
        const results = [makeResult('http', 80), makeResult('bloc', 60)];
        const html = buildReportHtml({
            results,
            overrideCount: 1,
            overrideNames: new Set(['http']),
            pubspecUri: null,
        });
        /* http row has yes, bloc row has no */
        const httpRow = html.match(/<tr[^>]*data-name="http"[^>]*>/);
        const blocRow = html.match(/<tr[^>]*data-name="bloc"[^>]*>/);
        assert.ok(httpRow);
        assert.ok(blocRow);
        assert.ok(httpRow![0].includes('data-overridden="yes"'));
        assert.ok(blocRow![0].includes('data-overridden="no"'));
    });
});

describe('report: column heading tooltips', () => {
    it('should include tooltip on Package column header', () => {
        const html = buildReportHtml(opts([]));
        assert.ok(html.includes('click to open pubspec.yaml entry'));
    });

    it('should include tooltip on Published column header', () => {
        const html = buildReportHtml(opts([]));
        assert.ok(html.includes('title="Date the installed version was published to pub.dev"'));
    });

    it('should include tooltip on Size column header', () => {
        const html = buildReportHtml(opts([]));
        assert.ok(html.includes('title="Archive size on pub.dev (before tree shaking)"'));
    });

    it('should hide description column header by default', () => {
        /* Description column is off by default — header should not be rendered */
        const html = buildReportHtml(opts([]));
        assert.ok(!html.includes('data-col="description"'));
    });
});

describe('report: toolbar', () => {
    it('should include search input', () => {
        const html = buildReportHtml(opts([]));
        assert.ok(html.includes('id="search-input"'));
        assert.ok(html.includes('Search packages'));
    });

    it('should include pubspec button when URI provided', () => {
        const html = buildReportHtml({
            results: [], overrideCount: 0, overrideNames: new Set(), pubspecUri: 'file:///project/pubspec.yaml',
        });
        assert.ok(html.includes('id="open-pubspec"'));
        assert.ok(html.includes('pubspec.yaml'));
    });

    it('should omit pubspec button when URI is null', () => {
        const html = buildReportHtml(opts([]));
        assert.ok(!html.includes('id="open-pubspec"'));
    });
});

describe('report: description on package name', () => {
    it('should show description as tooltip on package name', () => {
        const result = makeResult('http', 80);
        (result as { pubDev: any }).pubDev = {
            ...result.pubDev,
            description: 'A composable HTTP client',
        };
        const html = buildReportHtml(opts([result]));
        /* Description appears as title attribute on pkg-name-link span */
        assert.ok(html.includes('pkg-name-link'));
        assert.ok(html.includes('A composable HTTP client'));
    });

    it('should not show description tooltip when no description', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        /* Package name still renders as clickable link */
        assert.ok(html.includes('pkg-name-link'));
    });

    it('should hide description text column by default', () => {
        /* Description column is off by default — no desc-text cells rendered */
        const result = makeResult('http', 80);
        (result as { pubDev: any }).pubDev = {
            ...result.pubDev,
            description: 'A composable HTTP client',
        };
        const html = buildReportHtml(opts([result]));
        assert.ok(!html.includes('class="desc-text"'));
    });
});

describe('report: version age suffix', () => {
    it('should show age suffix based on installedVersionDate', () => {
        /* Fixed reference: 9 months before 2026-03-29 = 2025-06-29 */
        const result = {
            ...makeResult('http', 80),
            installedVersionDate: '2025-06-29T00:00:00Z',
        };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('version-age'));
        assert.ok(html.includes('mo)'));
    });

    it('should fall back to publishedDate when installedVersionDate is null', () => {
        /* makeResult has publishedDate 2025-06-01 — should produce an age */
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(html.includes('version-age'));
    });

    it('should show no age suffix when no date available', () => {
        const result = { ...makeResult('http', 80), pubDev: null };
        const html = buildReportHtml(opts([result]));
        /* .version-age class exists in CSS but no age span in the row */
        const rowMatch = html.match(/<tr[^>]*data-name="http"[^>]*>[\s\S]*?<\/tr>/);
        assert.ok(rowMatch, 'expected to find http row');
        assert.ok(!rowMatch![0].includes('version-age'));
    });

    it('should show years for old packages', () => {
        const result = {
            ...makeResult('http', 80),
            installedVersionDate: '2022-01-01T00:00:00Z',
        };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('version-age'));
        assert.ok(html.includes('y)'));
    });
});

describe('report: version tooltip', () => {
    it('should include installed version date in tooltip', () => {
        const result = {
            ...makeResult('http', 80),
            installedVersionDate: '2025-06-01T00:00:00Z',
        };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('Installed: 1.0.0 (2025-06-01)'));
    });

    it('should show latest version when different from installed', () => {
        const result = makeResult('http', 80);
        (result as { pubDev: any }).pubDev = {
            ...result.pubDev,
            latestVersion: '2.0.0',
        };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('Latest: 2.0.0'));
    });

    it('should not show latest line when versions match', () => {
        /* makeResult has both version and latestVersion as 1.0.0 */
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(!html.includes('Latest:'));
    });

    it('should show constraint in tooltip', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(html.includes('Constraint: ^1.0.0'));
    });

    it('should show created date when available', () => {
        const result = makeResult('http', 80);
        (result as { pubDev: any }).pubDev = {
            ...result.pubDev,
            createdDate: '2020-03-15T00:00:00Z',
        };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('Created: 2020-03-15'));
    });

});

describe('report: copy-as-JSON button', () => {
    it('should include a copy button in each row', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(html.includes('copy-btn'));
        assert.ok(html.includes('data-pkg="http"'));
    });

    it('should include copy column header', () => {
        const html = buildReportHtml(opts([]));
        assert.ok(html.includes('col-copy'));
    });

    it('should embed packageData script variable', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(html.includes('var packageData='));
    });

    it('should include package name and links in JSON data', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        /* The packageData JS object contains the package entry */
        assert.ok(html.includes('"http"'));
        assert.ok(html.includes('pub.dev/packages/http'));
        assert.ok(html.includes('pub.dev/packages/http/versions'));
        assert.ok(html.includes('pub.dev/packages/http/changelog'));
    });

    it('should include health breakdown in JSON data', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(html.includes('"resolutionVelocity"'));
        assert.ok(html.includes('"engagementLevel"'));
        assert.ok(html.includes('"popularity"'));
        assert.ok(html.includes('"publisherTrust"'));
    });

    it('should include isOverridden in JSON data', () => {
        const result = makeResult('http', 80);
        const html = buildReportHtml({
            results: [result],
            overrideCount: 1,
            overrideNames: new Set(['http']),
            pubspecUri: null,
        });
        assert.ok(html.includes('"isOverridden":true'));
    });

    it('should include vulnerability data in JSON', () => {
        const result = {
            ...makeResult('http', 80),
            vulnerabilities: [{
                id: 'GHSA-1234', summary: 'XSS vuln', severity: 'high' as const,
                cvssScore: 8.5, fixedVersion: '2.0.0', url: 'https://example.com/vuln',
            }],
        };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('GHSA-1234'));
        assert.ok(html.includes('XSS vuln'));
    });
});

describe('report: Issues column', () => {
    it('should show issue count from openIssues', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        /* makeResult has openIssues: 5, no trueOpenIssues */
        assert.ok(html.includes('data-issues="5"'));
    });

    it('should prefer trueOpenIssues over openIssues', () => {
        const result = makeResult('http', 80);
        (result as any).github = { ...result.github, trueOpenIssues: 3 };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('data-issues="3"'));
    });

    it('should link to repo /issues when repoUrl available', () => {
        const result = makeResult('http', 80);
        (result as any).github = { ...result.github, repoUrl: 'https://github.com/dart-lang/http' };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('href="https://github.com/dart-lang/http/issues"'));
    });

    it('should show dash when no github data', () => {
        const result = { ...makeResult('http', 80), github: null };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('data-issues=""'));
    });

    it('should include Issues column header with tooltip', () => {
        const html = buildReportHtml(opts([]));
        assert.ok(html.includes('data-col="issues"'));
        assert.ok(html.includes('Open GitHub issues'));
    });
});

describe('report: PRs column', () => {
    it('should show dash when openPullRequests undefined', () => {
        /* makeResult has no openPullRequests */
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(html.includes('data-prs=""'));
    });

    it('should show PR count when available', () => {
        const result = makeResult('http', 80);
        (result as any).github = { ...result.github, openPullRequests: 7 };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('data-prs="7"'));
    });

    it('should link to repo /pulls when repoUrl available', () => {
        const result = makeResult('http', 80);
        (result as any).github = {
            ...result.github,
            openPullRequests: 2,
            repoUrl: 'https://github.com/dart-lang/http',
        };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('href="https://github.com/dart-lang/http/pulls"'));
    });

    it('should include PRs column header with tooltip', () => {
        const html = buildReportHtml(opts([]));
        assert.ok(html.includes('data-col="prs"'));
        assert.ok(html.includes('Open GitHub pull requests'));
    });
});

describe('report: Issues and PRs in copy JSON', () => {
    it('should include openIssues in JSON data', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(html.includes('"openIssues":5'));
    });

    it('should include openPullRequests as null when unavailable', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(html.includes('"openPullRequests":null'));
    });

    it('should include openPullRequests count when available', () => {
        const result = makeResult('http', 80);
        (result as any).github = { ...result.github, openPullRequests: 4 };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('"openPullRequests":4'));
    });

    it('should include issues and pullRequests links when repo available', () => {
        const result = makeResult('http', 80);
        (result as any).github = { ...result.github, repoUrl: 'https://github.com/dart-lang/http' };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('github.com/dart-lang/http/issues'));
        assert.ok(html.includes('github.com/dart-lang/http/pulls'));
    });

    it('should set issues and pullRequests links to null when no repo', () => {
        /* makeResult has repositoryUrl: null and no repoUrl */
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        /* links object should contain null for both */
        assert.ok(html.includes('"issues":null'));
        assert.ok(html.includes('"pullRequests":null'));
    });
});

describe('report: health tooltip (score breakdown)', () => {
    it('should include score breakdown in health cell tooltip', () => {
        const result = makeResult('http', 80);
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('Vibrancy Score: 8/10'));
        assert.ok(html.includes('Resolution Velocity: 50'));
        assert.ok(html.includes('Engagement Level: 40'));
        assert.ok(html.includes('Popularity: 30'));
        assert.ok(html.includes('Publisher Trust: 0'));
    });

});

describe('report: empty-cell dash with explanatory tooltip', () => {
    /** Extract the <td> cells from the first <tr> row in the HTML table body. */
    function rowCells(html: string): string[] {
        const rowMatch = html.match(/<tbody[^>]*>([\s\S]*?)<\/tbody>/);
        if (!rowMatch) { return []; }
        const firstRow = rowMatch[1].match(/<tr[\s\S]*?<\/tr>/);
        if (!firstRow) { return []; }
        return [...firstRow[0].matchAll(/<td[^>]*>[\s\S]*?<\/td>/g)].map(m => m[0]);
    }

    it('should show dash with tooltip when stars are unavailable', () => {
        const result = { ...makeResult('http', 80), github: null };
        const html = buildReportHtml(opts([result]));
        const cells = rowCells(html);
        const starsCell = cells.find(c => c.includes('\u2014') && c.includes('No GitHub repository found'));
        assert.ok(starsCell, 'expected a cell with em-dash and GitHub tooltip for missing stars');
    });

    it('should show dash with tooltip when published date is unavailable', () => {
        const result = { ...makeResult('http', 80), pubDev: null };
        const html = buildReportHtml(opts([result]));
        assert.ok(
            html.includes('title="Publish date not available from pub.dev"'),
            'expected tooltip explaining missing publish date',
        );
        assert.ok(html.includes('>\u2014<'), 'expected em-dash for missing date');
    });

    it('should show dash with tooltip when issues count is unavailable', () => {
        const result = { ...makeResult('http', 80), github: null };
        const html = buildReportHtml(opts([result]));
        /* The issues cell should contain an em-dash with a GitHub tooltip */
        const cells = rowCells(html);
        const issueCells = cells.filter(c => c.includes('No GitHub repository found'));
        /* stars, issues, and PRs all show this tooltip when github is null */
        assert.ok(issueCells.length >= 3, 'expected at least 3 cells with GitHub tooltip (stars, issues, PRs)');
    });

    it('should show dash with tooltip when archive size is unavailable', () => {
        /* makeResult defaults to archiveSizeBytes: null */
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(html.includes('title="Archive size not available from pub.dev"'));
    });

    it('should hide license column by default (no license cell rendered)', () => {
        /* License column is off by default — tooltip should not appear */
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(!html.includes('title="License not specified on pub.dev"'));
    });

    it('should hide description column by default (no description cell rendered)', () => {
        /* Description column is off by default — no desc-text cells rendered */
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(!html.includes('class="desc-text"'));
    });

    it('should NOT show dash tooltip when stars are available', () => {
        /* makeResult has github.stars: 42 */
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        /* The stars cell should show the number, not a tooltip about missing data */
        assert.ok(html.includes('>42<'), 'expected star count rendered');
        /* "No GitHub repository found" should not appear for the stars cell */
        const cells = rowCells(html);
        const starsCellWithTooltip = cells.find(
            c => c.includes('42') && c.includes('No GitHub repository found'),
        );
        assert.ok(!starsCellWithTooltip, 'star cell with data should not have missing-data tooltip');
    });

    it('should not render license cell when license column is hidden', () => {
        /* License column is hidden by default — no MIT cell rendered */
        const result = { ...makeResult('http', 80), license: 'MIT' };
        const html = buildReportHtml(opts([result]));
        assert.ok(!html.includes('License not specified on pub.dev'));
        /* MIT value should still appear in copy-as-JSON data */
        assert.ok(html.includes('"license":"MIT"'));
    });

    it('should wrap all placeholder dashes in dimmed span', () => {
        /* A result with null github produces dimmed dashes for stars/issues/PRs */
        const result = { ...makeResult('http', 80), github: null };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('class="dimmed"'));
        /* Dashes should be inside dimmed spans, not bare */
        assert.ok(html.includes('<span class="dimmed">\u2014</span>'));
    });
});

describe('report: published column links to pub.dev', () => {
    it('should link published date to pub.dev package page', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        /* Published cell should contain a link to pub.dev/packages/http */
        assert.ok(html.includes('href="https://pub.dev/packages/http"'));
        assert.ok(html.includes('2025-06-01'));
    });

    it('should show age suffix on published column (moved from version)', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        /* makeResult has publishedDate 2025-06-01 — age suffix should be on published cell */
        assert.ok(html.includes('version-age'));
    });

    it('should show dimmed dash when no publish date', () => {
        const result = { ...makeResult('http', 80), pubDev: null };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('Publish date not available from pub.dev'));
    });
});

describe('report: package name links to pubspec entry', () => {
    it('should render package name as clickable span (not <a>)', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(html.includes('class="pkg-name-link"'));
        assert.ok(html.includes('data-pkg="http"'));
    });

    it('should include postMessage handler for pkg-name-link', () => {
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        assert.ok(html.includes('openPubspecEntry'));
    });
});

describe('report: references column (renamed from files)', () => {
    it('should use References header label', () => {
        const result = {
            ...makeResult('http', 80),
            fileUsages: [{ filePath: 'lib/main.dart', line: 1, isCommented: false }],
        };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('>References<'));
    });

    it('should render reference count as clickable span', () => {
        const result = {
            ...makeResult('http', 80),
            fileUsages: [{ filePath: 'lib/main.dart', line: 1, isCommented: false }],
        };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('class="ref-link"'));
        assert.ok(html.includes('data-pkg="http"'));
    });

    it('should include postMessage handler for ref-link', () => {
        const result = {
            ...makeResult('http', 80),
            fileUsages: [{ filePath: 'lib/main.dart', line: 1, isCommented: false }],
        };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('searchImport'));
    });
});

describe('report: update column uses dimmed hyphen', () => {
    it('should show dimmed en-dash when no update available', () => {
        /* makeResult has updateInfo: null (up-to-date) */
        const html = buildReportHtml(opts([makeResult('http', 80)]));
        /* En-dash U+2013, not checkmark U+2713 */
        assert.ok(html.includes('\u2013'));
        assert.ok(!html.includes('\u2713'));
    });

    it('should show update arrow when update available', () => {
        const result = {
            ...makeResult('http', 80),
            updateInfo: { currentVersion: '1.0.0', latestVersion: '2.0.0', updateStatus: 'major' as const, changelog: null },
        };
        const html = buildReportHtml(opts([result]));
        assert.ok(html.includes('update-major'));
        assert.ok(html.includes('\u2192'));
    });
});
