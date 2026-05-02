/**
 * HTML-render coverage for the single-package detail panel's adherence to
 * the editor-dashboard UX guidelines. Pins:
 *
 *   §8.1 — title prefix is applied exactly once: the page renders
 *          *Saropa <package-name>* (NOT *Saropa Package: <package-name>*),
 *          which was the double-noun bug the audit caught.
 *   §14.14 — external-link strip renders only ONCE (at the bottom band),
 *            not duplicated below the hero.
 *   §4 — body has a max-width cap and the chrome's full-width toggle hook.
 *   §8.10 — Upgrade and View Changelog are differentiated (primary vs
 *           secondary action class), so only one is emphasized per region.
 */
import '../register-vscode-mock';

import * as assert from 'node:assert';

import { buildPackageDetailHtml } from '../../../vibrancy/views/package-detail-html';
import type { VibrancyResult } from '../../../vibrancy/types';

function makeResult(name = 'http'): VibrancyResult {
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
        github: null,
        knownIssue: null,
        score: 75,
        category: 'vibrant',
        resolutionVelocity: 0,
        engagementLevel: 0,
        popularity: 0,
        publisherTrust: 0,
        updateInfo: null,
        archiveSizeBytes: null,
        bloatRating: null,
        license: 'MIT',
        isUnused: false,
        fileUsages: [],
        platforms: ['android'],
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

describe('Package Detail Panel HTML', () => {
    it('applies the Saropa prefix exactly once, not double-noun "Saropa Package: foo" (§8.1)', () => {
        const html = buildPackageDetailHtml(makeResult('http'), [], null);
        // Document title and h1 should both read "Saropa http", NOT
        // "Saropa Package: http". The hero builder owns the prefix.
        assert.ok(html.includes('<title>Saropa http</title>'));
        assert.ok(html.includes('Saropa http'));
        assert.ok(!html.includes('Saropa Package:'));
    });

    it('renders the external-link strip only once (at the bottom band) (§14.14)', () => {
        const html = buildPackageDetailHtml(makeResult('http'), [], null);
        // .links-row appears once — at the end of the page via buildLinksRow.
        // The header copy was dropped per §14.14 so reference content lives
        // below the data.
        const linksMatches = html.match(/class="links-row"/g);
        assert.ok(linksMatches, 'links-row must render at least once');
        assert.strictEqual(linksMatches.length, 1, 'links-row should render exactly once (bottom band only)');
    });

    it('binds the body to a max-width with the full-width toggle override (§4)', () => {
        const html = buildPackageDetailHtml(makeResult('http'), [], null);
        assert.ok(html.includes('max-width: 1280px'));
        assert.ok(html.includes('body[data-full-width="true"]'));
    });

    it('renders View Changelog as the secondary action, not as a second primary (§8.10)', () => {
        const html = buildPackageDetailHtml(makeResult('http'), [], null);
        // View Changelog should always render as .action-btn.secondary so
        // the only emphasized button per region (Upgrade, when present)
        // remains the single primary.
        assert.ok(html.includes('class="action-btn secondary"'));
        assert.ok(html.includes('View Changelog'));
    });
});
