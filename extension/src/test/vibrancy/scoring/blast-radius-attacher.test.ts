/**
 * Tests the blast-radius wiring: attachment, nudge suppression, breaker
 * formatting, and exclusion from bulk upgrade-all (analyzer 12 -> 13).
 */
import * as assert from 'assert';
import {
    attachBlastRadius, isUpgradeSuppressed, formatBreakers, blastRadiusCandidates,
} from '../../../vibrancy/scoring/blast-radius-attacher';
import { getUpdatablePackages } from '../../../vibrancy/services/bulk-updater';
import { formatCodeLensTitle } from '../../../vibrancy/scoring/codelens-formatter';
import { DepEdge, VibrancyResult } from '../../../vibrancy/types';

function makeResult(name: string, current: string, latest: string): VibrancyResult {
    return {
        package: { name, version: current, constraint: `^${current}`, source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: null, github: null, knownIssue: null, score: 80, category: 'vibrant',
        resolutionVelocity: 0.8, engagementLevel: 0.7, popularity: 0.6, publisherTrust: 15,
        updateInfo: current === latest ? null
            : { currentVersion: current, latestVersion: latest, updateStatus: 'major', changelog: null },
        license: 'MIT', archiveSizeBytes: null, bloatRating: null, isUnused: false,
        platforms: null, verifiedPublisher: true, wasmReady: null, blocker: null,
        upgradeBlockStatus: 'upgradable', transitiveInfo: null, alternatives: [],
        latestPrerelease: null, prereleaseTag: null, vulnerabilities: [],
    } as unknown as VibrancyResult;
}

const reverse = new Map<string, DepEdge[]>([
    ['analyzer', [{ dependentPackage: 'custom_lint' }]],
    ['custom_lint', [{ dependentPackage: 'app' }]],
]);
const constraints = new Map([['custom_lint', new Map([['analyzer', '>=11.0.0 <13.0.0']])]]);

describe('blast-radius wiring', () => {
    it('analyzer 12 -> 13 is held back, suppressed, and skipped by bulk upgrade', () => {
        const results = attachBlastRadius(
            [makeResult('analyzer', '12.0.0', '13.1.0'), makeResult('http', '1.0.0', '1.2.0')],
            { reverseDeps: reverse, constraints },
        );
        const analyzer = results[0];
        assert.strictEqual(analyzer.blastRadius?.verdict, 'held-back');
        assert.strictEqual(isUpgradeSuppressed(analyzer), true);
        assert.ok(formatBreakers(analyzer.blastRadius!)[0].startsWith('custom_lint (>=11.0.0 <13.0.0)'));
        assert.ok(formatCodeLensTitle(analyzer, 'full').includes('held back'));

        const { updatable, skipped } = getUpdatablePackages(results, new Set(), new Set(), 'all');
        assert.deepStrictEqual(updatable.map(u => u.name), ['http']);
        assert.ok(skipped.some(s => s.name === 'analyzer' && s.reason.includes('not recommended')));
    });

    it('a safe upgrade keeps the plain nudge', () => {
        const [r] = attachBlastRadius([makeResult('http', '1.0.0', '1.2.0')], { reverseDeps: reverse, constraints });
        assert.strictEqual(r.blastRadius?.verdict, 'safe');
        assert.strictEqual(isUpgradeSuppressed(r), false);
        assert.ok(formatCodeLensTitle(r, 'full').includes('1.2.0'));
    });

    it('breaks-dependents suppresses without a held-back entry', () => {
        const [r] = attachBlastRadius([makeResult('analyzer', '12.0.0', '13.1.0')],
            { reverseDeps: reverse, constraints, heldBack: [] });
        assert.strictEqual(r.blastRadius?.verdict, 'breaks-dependents');
        assert.strictEqual(isUpgradeSuppressed(r), true);
    });

    it('collects dependents of updatable packages as candidates', () => {
        const names = blastRadiusCandidates([makeResult('analyzer', '12.0.0', '13.1.0')], reverse);
        assert.deepStrictEqual([...names], ['custom_lint']);
    });
});
