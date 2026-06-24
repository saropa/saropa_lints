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
        codeSizeBytes: null,
        folderBreakdown: null,
        maintainerQuality: null,
        maintainerQualityBonus: 0,
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

    it('exposes the keyboard-shortcut overlay trigger and dialog (§15.2)', () => {
        const html = buildPackageDetailHtml(makeResult('http'), [], null);
        assert.ok(
            html.includes('id="kbdShortcutsToggle"'),
            'expected kbd-shortcut overlay trigger button',
        );
        assert.ok(
            html.includes('id="kbdShortcutsOverlay"'),
            'expected kbd-shortcut overlay dialog markup',
        );
    });

    it('omits the partial-fetch banner when every lazy fetch is clean (§8.16.3)', () => {
        // The banner is hidden entirely (returns empty string) when no fetch
        // has failed — the "everything loaded" state never advertises itself.
        const html = buildPackageDetailHtml(makeResult('http'), [], null);
        assert.ok(
            !html.includes('class="partial-banner"'),
            'partial banner should not render when fetch errors are absent',
        );
        assert.ok(
            !html.includes('id="retry-fetches"'),
            'retry button should not render without partial state',
        );
    });

    it('renders the partial-fetch banner with a Retry button when a lazy fetch fails (§8.16.3)', () => {
        // Default value of `fetchErrors` is "no errors"; callers explicitly
        // pass per-fetch flags. Asserting the failure path keeps the banner's
        // copy and the retry-button id stable for the script wiring.
        const html = buildPackageDetailHtml(makeResult('http'), [], null, {
            readme: true, gap: false, reverseDeps: false,
        });
        assert.ok(
            html.includes('class="partial-banner"'),
            'partial banner should render when README fetch failed',
        );
        assert.ok(
            html.includes('id="retry-fetches"'),
            'retry button should be wired so the script can postMessage retryFetches',
        );
        // The busy label is server-rendered (localized) and read by the report
        // script to relabel the button to "Retrying…" while the re-fetch runs;
        // without it the button gives no in-pane busy signal.
        assert.ok(
            /id="retry-fetches"[^>]*data-busy-label="/.test(html),
            'retry button should carry data-busy-label for the in-pane busy state',
        );
        assert.ok(
            html.includes('README and logo'),
            'banner should name the failed fetch in user-facing language',
        );
    });
});

describe('Package Detail Panel — consolidated changelog', () => {
    function withChangelog(
        entries: { version: string; date?: string; body: string }[],
        truncated = false,
    ): VibrancyResult {
        const base = makeResult('http');
        return {
            ...base,
            updateInfo: {
                currentVersion: '1.0.0',
                latestVersion: '1.2.0',
                updateStatus: 'minor',
                changelog: { entries, truncated },
            },
        };
    }

    it('renders parsed changelog entries inline so an upgrade is a reviewed decision', () => {
        const html = buildPackageDetailHtml(
            withChangelog([
                { version: '1.2.0', date: '2025-06-01', body: '- Added a thing' },
                { version: '1.1.0', body: '- Fixed a bug' },
            ]),
            [], null,
        );
        assert.ok(html.includes('CHANGELOG'), 'changelog section header should render');
        assert.ok(html.includes('1.2.0 — 2025-06-01'), 'dated entry heading should render');
        assert.ok(html.includes('1.1.0'), 'undated entry heading should render');
        assert.ok(html.includes('Added a thing') && html.includes('Fixed a bug'),
            'entry bodies should render as markdown');
    });

    it('renders the Upgrade button with a busy label so the pane can show progress', () => {
        // updateInfo is a minor bump with no blocker, so the Upgrade action
        // renders. data-busy-label is the localized "Upgrading…" the report
        // script swaps in while pub get + the test suite run (multi-minute), so
        // the pane button does not look idle behind a lone toast.
        const html = buildPackageDetailHtml(withChangelog([]), [], null);
        assert.ok(
            html.includes('data-action="upgrade"'),
            'upgrade action button should render for an available minor update',
        );
        assert.ok(
            /data-action="upgrade"[^>]*data-busy-label="/.test(html),
            'upgrade button should carry data-busy-label for the in-pane busy state',
        );
    });

    it('escapes HTML in untrusted changelog bodies (no raw script injection)', () => {
        const html = buildPackageDetailHtml(
            withChangelog([{ version: '1.2.0', body: '<img src=x onerror=alert(1)>' }]),
            [], null,
        );
        assert.ok(!html.includes('<img src=x onerror=alert(1)>'),
            'raw HTML from an external changelog must be escaped, not rendered');
        assert.ok(html.includes('&lt;img'), 'the angle bracket should be escaped');
    });

    it('shows a truncation note linking to the full changelog when capped', () => {
        const html = buildPackageDetailHtml(
            withChangelog([{ version: '1.2.0', body: 'x' }], true),
            [], null,
        );
        assert.ok(html.includes('most recent releases'), 'truncation note should render');
        assert.ok(html.includes('pub.dev/packages/http/changelog'),
            'truncation note should link to the full changelog');
    });

    it('renders nothing when there is no update (no changelog noise on current packages)', () => {
        const html = buildPackageDetailHtml(makeResult('http'), [], null);
        assert.ok(!html.includes('CHANGELOG'),
            'changelog section must be absent when updateInfo is null');
    });
});
