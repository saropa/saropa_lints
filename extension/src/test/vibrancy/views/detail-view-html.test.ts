import * as assert from 'assert';
import { buildDetailViewHtml } from '../../../vibrancy/views/detail-view-html';
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
            repositoryUrl: 'https://github.com/example/pkg',
            isDiscontinued: false,
            isUnlisted: false,
            pubPoints: 140,
            publisher: 'verified.dev',
            license: null,
            description: null,
            topics: [],
            dependencies: [],
        },
        github: {
            stars: 1234,
            openIssues: 45,
            closedIssuesLast90d: 10,
            mergedPrsLast90d: 5,
            avgCommentsPerIssue: 2.5,
            daysSinceLastUpdate: 3,
            daysSinceLastClose: 7,
            flaggedIssues: [],
            license: null,
        },
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
        license: 'MIT',
        isUnused: false,
        fileUsages: [],
        platforms: ['android', 'ios', 'web'],
        verifiedPublisher: true,
        wasmReady: true,
        blocker: null,
        upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null,
        alternatives: [],
        latestPrerelease: null,
        prereleaseTag: null,
        vulnerabilities: [],
        versionGap: null,
        overrideGap: null,
        replacementComplexity: null,
        likes: null,
        downloadCount30Days: null,
        reverseDependencyCount: null,
        readme: null,
    };
}

describe('buildDetailViewHtml', () => {
    it('should return placeholder HTML when result is null', () => {
        const html = buildDetailViewHtml(null);
        assert.ok(html.includes('<!DOCTYPE html>'));
        assert.ok(html.includes('Select a package to see details'));
        assert.ok(html.includes('class="placeholder"'));
    });

    it('should return valid HTML with doctype', () => {
        const html = buildDetailViewHtml(makeResult('http', 80));
        assert.ok(html.startsWith('<!DOCTYPE html>'));
        assert.ok(html.includes('</html>'));
    });

    it('should include CSP meta tag', () => {
        const html = buildDetailViewHtml(makeResult('http', 80));
        assert.ok(html.includes('Content-Security-Policy'));
    });

    it('should show package name and grade letter', () => {
        const html = buildDetailViewHtml(makeResult('http', 80, 'vibrant'));
        assert.ok(html.includes('<h1>http</h1>'));
        /* Letter grade only; the raw /10 score is no longer rendered. */
        assert.ok(html.includes('>A</div>'));
        assert.ok(!html.includes('8/10'));
    });

    it('should expose category label via the grade tooltip (not as visible text)', () => {
        const html = buildDetailViewHtml(makeResult('http', 80, 'vibrant'));
        /* Category label moved into the title tooltip; the old standalone
           category-badge div was removed as part of the letter-only redesign. */
        assert.ok(html.includes('title="Vibrant"'));
        assert.ok(!html.includes('category-badge'));
    });

    it('should show version section', () => {
        const html = buildDetailViewHtml(makeResult('http', 80));
        assert.ok(html.includes('📦 VERSION'));
        assert.ok(html.includes('^1.0.0'));
    });

    it('should show published date', () => {
        const html = buildDetailViewHtml(makeResult('http', 80));
        assert.ok(html.includes('Published: 2025-06-01'));
    });

    it('should show license with checkmark for permissive', () => {
        const html = buildDetailViewHtml(makeResult('http', 80));
        assert.ok(html.includes('MIT ✅'));
    });

    it('should show community section', () => {
        const html = buildDetailViewHtml(makeResult('http', 80));
        assert.ok(html.includes('📊 COMMUNITY'));
        assert.ok(html.includes('⭐ 1.2k'));
        assert.ok(html.includes('📋 45 issues'));
    });

    it('should show pub points', () => {
        const html = buildDetailViewHtml(makeResult('http', 80));
        assert.ok(html.includes('140/160 pub points'));
    });

    it('should show verified publisher', () => {
        const html = buildDetailViewHtml(makeResult('http', 80));
        assert.ok(html.includes('✅ verified.dev'));
    });

    it('should show platforms section', () => {
        const html = buildDetailViewHtml(makeResult('http', 80));
        assert.ok(html.includes('📱 PLATFORMS'));
        assert.ok(html.includes('android, ios, web'));
        assert.ok(html.includes('🌐 WASM'));
    });

    it('should show links section', () => {
        const html = buildDetailViewHtml(makeResult('http', 80));
        // Link text changed from "View on pub.dev" to "pub.dev" in the
        // sidebar link refactor — verify both the label and target URL.
        assert.ok(html.includes('pub.dev'));
        assert.ok(html.includes('pub.dev/packages/http'));
        assert.ok(html.includes('Repository'));
    });

    it('should escape HTML in package names', () => {
        const result = makeResult('<script>xss</script>', 80);
        const html = buildDetailViewHtml(result);
        assert.ok(!html.includes('<script>xss</script>'));
        assert.ok(html.includes('&lt;script&gt;'));
    });

    it('should show update section when update available', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            updateInfo: {
                currentVersion: '1.0.0',
                latestVersion: '2.0.0',
                updateStatus: 'major',
                changelog: null,
            },
        };
        const html = buildDetailViewHtml(result);
        assert.ok(html.includes('⬆️ UPDATE'));
        assert.ok(html.includes('(major)'));
        assert.ok(html.includes('Upgrade'));
    });

    it('should not show update section when up-to-date', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            updateInfo: {
                currentVersion: '1.0.0',
                latestVersion: '1.0.0',
                updateStatus: 'up-to-date',
                changelog: null,
            },
        };
        const html = buildDetailViewHtml(result);
        assert.ok(!html.includes('⬆️ UPDATE'));
    });

    it('should show blocker info when upgrade blocked', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            blocker: {
                blockedPackage: 'http',
                currentVersion: '1.0.0',
                latestVersion: '2.0.0',
                blockerPackage: 'dio',
                blockerVibrancyScore: 60,
                blockerCategory: 'stable',
            },
            updateInfo: {
                currentVersion: '1.0.0',
                latestVersion: '2.0.0',
                updateStatus: 'major',
                changelog: null,
            },
        };
        const html = buildDetailViewHtml(result);
        assert.ok(html.includes('Blocked by dio'));
    });

    it('should show suggestion section for unused packages', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            isUnused: true,
        };
        const html = buildDetailViewHtml(result);
        assert.ok(html.includes('💡 SUGGESTION'));
        assert.ok(html.includes('appears to be unused'));
    });

    it('should show suggestion section with replacement', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            knownIssue: {
                name: 'http',
                status: 'deprecated',
                replacement: 'dio',
            },
        };
        const html = buildDetailViewHtml(result);
        assert.ok(html.includes('💡 SUGGESTION'));
        assert.ok(html.includes('migrating to dio'));
    });

    it('should show alternatives in suggestion', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            alternatives: [
                { name: 'dio', source: 'curated', score: 90, likes: 1000 },
                { name: 'chopper', source: 'discovery', score: 80, likes: 500 },
            ],
        };
        const html = buildDetailViewHtml(result);
        assert.ok(html.includes('💡 SUGGESTION'));
        assert.ok(html.includes('Alternatives: dio, chopper'));
    });

    it('should show alerts section for known issues', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            knownIssue: {
                name: 'http',
                status: 'security',
                reason: 'Critical vulnerability in TLS handling',
            },
        };
        const html = buildDetailViewHtml(result);
        assert.ok(html.includes('🚨 ALERTS'));
        assert.ok(html.includes('security'));
        assert.ok(html.includes('Critical vulnerability'));
    });

    it('should show flagged issues in alerts', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            github: {
                stars: 1000,
                openIssues: 10,
                closedIssuesLast90d: 5,
                mergedPrsLast90d: 3,
                avgCommentsPerIssue: 2,
                daysSinceLastUpdate: 5,
                daysSinceLastClose: 10,
                flaggedIssues: [
                    {
                        number: 123,
                        title: 'Breaking change in v2',
                        url: 'https://github.com/example/issues/123',
                        matchedSignals: ['breaking'],
                        commentCount: 15,
                    },
                ],
                license: null,
            },
        };
        const html = buildDetailViewHtml(result);
        assert.ok(html.includes('🚨 ALERTS'));
        assert.ok(html.includes('🚩 #123'));
        assert.ok(html.includes('Breaking change'));
    });

    it('should include collapsible section script', () => {
        const html = buildDetailViewHtml(makeResult('http', 80));
        assert.ok(html.includes('.section-header'));
        assert.ok(html.includes('data-expanded'));
    });

    it('should include action button handlers', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            updateInfo: {
                currentVersion: '1.0.0',
                latestVersion: '2.0.0',
                updateStatus: 'major',
                changelog: null,
            },
        };
        const html = buildDetailViewHtml(result);
        assert.ok(html.includes('data-action="upgrade"'));
        assert.ok(html.includes('vscode.postMessage'));
    });

    it('should handle all category styles', () => {
        /* After the letter-only redesign, only the .score div remains — the
           standalone .category-badge was removed. The .score box is still
           category-tinted via its modifier class and now holds the letter. */
        for (const cat of ['vibrant', 'stable', 'outdated', 'abandoned', 'end-of-life'] as const) {
            const html = buildDetailViewHtml(makeResult('http', 50, cat));
            assert.ok(html.includes(`class="score ${cat}"`), `Missing score class for ${cat}`);
        }
    });

    it('should not show empty sections', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            github: null,
            pubDev: null,
            alternatives: [],
            knownIssue: null,
            platforms: null,
        };
        const html = buildDetailViewHtml(result);
        assert.ok(!html.includes('📊 COMMUNITY'));
        assert.ok(!html.includes('💡 SUGGESTION'));
        assert.ok(!html.includes('🚨 ALERTS'));
        assert.ok(!html.includes('📱 PLATFORMS'));
        assert.ok(!html.includes('📊 DEPENDENCIES'));
    });
});

describe('buildDetailViewHtml dependencies section', () => {
    it('should not show dependencies section when no transitive info', () => {
        const html = buildDetailViewHtml(makeResult('http', 80));
        assert.ok(!html.includes('📊 DEPENDENCIES'));
    });

    it('should not show dependencies section when transitive count is zero', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            transitiveInfo: {
                directDep: 'http',
                transitiveCount: 0,
                flaggedCount: 0,
                transitives: [],
                sharedDeps: [],
            },
        };
        const html = buildDetailViewHtml(result);
        assert.ok(!html.includes('📊 DEPENDENCIES'));
    });

    it('should show dependencies section with transitive count', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            transitiveInfo: {
                directDep: 'http',
                transitiveCount: 8,
                flaggedCount: 0,
                transitives: Array.from({ length: 8 }, (_, i) => `dep_${i}`),
                sharedDeps: [],
            },
        };
        const html = buildDetailViewHtml(result);
        assert.ok(html.includes('📊 DEPENDENCIES'));
        assert.ok(html.includes('8 transitive packages'));
    });

    it('should show unique and shared breakdown with visual bar', () => {
        const result: VibrancyResult = {
            ...makeResult('crop_your_image', 80),
            transitiveInfo: {
                directDep: 'crop_your_image',
                transitiveCount: 12,
                flaggedCount: 0,
                transitives: Array.from({ length: 12 }, (_, i) => `dep_${i}`),
                sharedDeps: ['image', 'meta', 'collection'],
            },
        };
        const html = buildDetailViewHtml(result);
        assert.ok(html.includes('📊 DEPENDENCIES'));
        // Visual bar with unique (75%) and shared (25%) segments
        assert.ok(html.includes('dep-bar-unique'));
        assert.ok(html.includes('dep-bar-shared'));
        // Counts: 9 unique, 3 shared (25%)
        assert.ok(html.includes('9 unique'));
        assert.ok(html.includes('3 shared'));
        // Shared dep names listed
        assert.ok(html.includes('image'));
        assert.ok(html.includes('meta'));
        assert.ok(html.includes('collection'));
    });

    it('should show flagged indicator', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            transitiveInfo: {
                directDep: 'http',
                transitiveCount: 5,
                flaggedCount: 2,
                transitives: ['a', 'b', 'c', 'd', 'e'],
                sharedDeps: [],
            },
        };
        const html = buildDetailViewHtml(result);
        assert.ok(html.includes('(2 flagged)'));
    });

    it('should escape shared dep names to prevent XSS', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            transitiveInfo: {
                directDep: 'http',
                transitiveCount: 3,
                flaggedCount: 0,
                transitives: ['<script>evil</script>', 'safe_dep', 'another'],
                sharedDeps: ['<script>evil</script>', 'safe_dep'],
            },
        };
        const html = buildDetailViewHtml(result);
        assert.ok(!html.includes('<script>evil</script>'));
        assert.ok(html.includes('&lt;script&gt;'));
    });
});
