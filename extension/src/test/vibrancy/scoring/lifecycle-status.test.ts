/** Tests lifecycle detection: known-issue lookup scoping, upgrade-required category, notes, retraction. */
import * as assert from 'assert';
import { findKnownIssue, effectiveIssueStatus, allKnownIssues } from '../../../vibrancy/scoring/known-issues';
import { classifyStatus, countByCategory } from '../../../vibrancy/scoring/status-classifier';
import { getLifecycleNotes, isEolStatusPossiblyStale } from '../../../vibrancy/scoring/lifecycle-notes';
import { pickNonRetractedLatest } from '../../../vibrancy/services/pub-dev-api';
import { CATEGORY_DICTIONARY } from '../../../vibrancy/category-dictionary';
import { flagRiskyTransitives } from '../../../vibrancy/scoring/transitive-analyzer';
import { l10n } from '../../../i18n/runtime';
import { problemMessage } from '../../../vibrancy/problems/problem-types';
import { collectProblems } from '../../../vibrancy/scoring/consolidate-insights';
import { computeActuals } from '../../../vibrancy/scoring/budget-checker';
import type { KnownIssue, PubDevPackageInfo, VibrancyResult } from '../../../vibrancy/types';

const ki = (o: Partial<KnownIssue>): KnownIssue =>
    ({ name: 'p', status: 'end_of_life', as_of: '2025-01-01', ...o } as KnownIssue);
const pub = (o: Partial<PubDevPackageInfo>): PubDevPackageInfo => ({
    name: 'p', latestVersion: '2.0.0', publishedDate: new Date().toISOString(),
    repositoryUrl: null, isDiscontinued: false, isUnlisted: false, pubPoints: 100,
    publisher: null, license: null, description: null, topics: [], dependencies: [], ...o,
});
const res = (o: Partial<VibrancyResult>): VibrancyResult => ({ ...o } as VibrancyResult);

describe('lifecycle status', () => {
    describe('findKnownIssue without version (F1)', () => {
        it('never returns a version-bounded entry when no version is given', () => {
            for (const [name, entries] of allKnownIssues()) {
                const onlyBounded = entries.every(e => e.appliesToMinVersion || e.appliesToMaxVersion);
                if (onlyBounded) {
                    assert.strictEqual(findKnownIssue(name), null, name);
                }
            }
        });
        it('still returns unscoped entries without a version', () => {
            const unscoped = [...allKnownIssues()].find(([, es]) =>
                es.some(e => !e.appliesToMinVersion && !e.appliesToMaxVersion));
            assert.ok(unscoped);
            assert.ok(findKnownIssue(unscoped![0]));
        });
    });

    describe('effectiveIssueStatus backward compat', () => {
        it('reads bounded end_of_life as upgrade_required', () => {
            assert.strictEqual(effectiveIssueStatus(ki({ appliesToMaxVersion: '3.0.0' })), 'upgrade_required');
            assert.strictEqual(effectiveIssueStatus(ki({ appliesToMinVersion: '1.0.0' })), 'upgrade_required');
        });
        it('keeps unscoped end_of_life and other statuses', () => {
            assert.strictEqual(effectiveIssueStatus(ki({})), 'end_of_life');
            assert.strictEqual(effectiveIssueStatus(ki({ status: 'caution' })), 'caution');
            assert.strictEqual(effectiveIssueStatus(null), null);
        });
        it('passes a native upgrade_required through', () => {
            assert.strictEqual(effectiveIssueStatus(ki({ status: 'upgrade_required' })), 'upgrade_required');
        });
    });

    describe('classifyStatus upgrade-required (F2)', () => {
        it('maps bounded end_of_life to upgrade-required, not end-of-life', () => {
            const c = classifyStatus({ score: 90, knownIssue: ki({ appliesToMaxVersion: '3.0.0' }), pubDev: null });
            assert.strictEqual(c, 'upgrade-required');
        });
        it('maps native upgrade_required to upgrade-required', () => {
            assert.strictEqual(
                classifyStatus({ score: 90, knownIssue: ki({ status: 'upgrade_required' }), pubDev: null }),
                'upgrade-required');
        });
        it('unscoped end_of_life stays end-of-life', () => {
            assert.strictEqual(classifyStatus({ score: 90, knownIssue: ki({}), pubDev: null }), 'end-of-life');
        });
        it('discontinued and archived beat upgrade-required', () => {
            const k = ki({ appliesToMaxVersion: '3.0.0' });
            assert.strictEqual(classifyStatus({ score: 90, knownIssue: k, pubDev: pub({ isDiscontinued: true }) }), 'end-of-life');
            assert.strictEqual(classifyStatus({ score: 90, knownIssue: k, pubDev: null, isArchived: true }), 'end-of-life');
        });
        it('maintenance_mode and caution do not change category', () => {
            for (const status of ['maintenance_mode', 'caution']) {
                assert.strictEqual(classifyStatus({ score: 80, knownIssue: ki({ status }), pubDev: null }), 'vibrant');
            }
        });
        it('discontinued + unlisted is end-of-life', () => {
            assert.strictEqual(
                classifyStatus({ score: 80, knownIssue: null, pubDev: pub({ isDiscontinued: true, isUnlisted: true }) }),
                'end-of-life');
        });
        it('countByCategory counts upgradeRequired', () => {
            const c = countByCategory([res({ category: 'upgrade-required' }), res({ category: 'end-of-life' })]);
            assert.strictEqual(c.upgradeRequired, 1);
            assert.strictEqual(c.eol, 1);
        });
        it('dictionary reads as upgrade needed, grade D', () => {
            const d = CATEGORY_DICTIONARY['upgrade-required'];
            assert.strictEqual(d.label, 'Upgrade Required');
            assert.strictEqual(d.grade, 'D');
        });
    });

    describe('transitive flagging', () => {
        it('does not flag a bounded (old-major) end_of_life transitive as dead', () => {
            const map = new Map([['t', [ki({ name: 't', appliesToMaxVersion: '2.0.0' })]]]);
            const out = flagRiskyTransitives([{ directDep: 'd', transitives: ['t'] } as any], map);
            assert.strictEqual(out.length, 0);
        });
        it('flags an unscoped end_of_life transitive', () => {
            const map = new Map([['t', [ki({ name: 't' })]]]);
            const out = flagRiskyTransitives([{ directDep: 'd', transitives: ['t'] } as any], map);
            assert.strictEqual(out.length, 1);
        });
    });

    describe('lifecycle notes (F3/F4/F5)', () => {
        const now = Date.parse('2026-09-19');
        it('flags stale unscoped EOL when live data is fresh and not discontinued', () => {
            const r = res({ knownIssue: ki({}), pubDev: pub({ publishedDate: '2026-06-01T00:00:00Z' }) });
            assert.ok(isEolStatusPossiblyStale(r, now));
            assert.ok(getLifecycleNotes(r, now).some(n => n.kind === 'status-may-be-outdated'));
        });
        it('does not flag when discontinued, old, scoped, or no pub data', () => {
            const fresh = pub({ publishedDate: '2026-06-01T00:00:00Z' });
            assert.ok(!isEolStatusPossiblyStale(res({ knownIssue: ki({}), pubDev: { ...fresh, isDiscontinued: true } }), now));
            assert.ok(!isEolStatusPossiblyStale(res({ knownIssue: ki({}), pubDev: pub({ publishedDate: '2024-01-01T00:00:00Z' }) }), now));
            assert.ok(!isEolStatusPossiblyStale(res({ knownIssue: ki({ appliesToMaxVersion: '2.0.0' }), pubDev: fresh }), now));
            assert.ok(!isEolStatusPossiblyStale(res({ knownIssue: ki({}), pubDev: null }), now));
        });
        it('surfaces maintenance_mode, caution and unlisted without category change', () => {
            const kinds = (r: Partial<VibrancyResult>) => getLifecycleNotes(res(r), now).map(n => n.kind);
            assert.deepStrictEqual(kinds({ knownIssue: ki({ status: 'maintenance_mode' }) }), ['maintenance-mode']);
            assert.deepStrictEqual(kinds({ knownIssue: ki({ status: 'caution' }) }), ['caution']);
            assert.deepStrictEqual(kinds({ pubDev: pub({ isUnlisted: true }) }), ['unlisted']);
            assert.deepStrictEqual(kinds({ pubDev: pub({}) }), []);
        });
    });

    describe('retracted latest (F5)', () => {
        it('keeps a non-retracted latest', () => {
            assert.strictEqual(pickNonRetractedLatest({ latest: { version: '2.0.0' } }).version, '2.0.0');
        });
        it('falls back to newest non-retracted stable when latest is retracted', () => {
            const json = {
                latest: { version: '3.0.0', retracted: true },
                versions: [
                    { version: '1.0.0' }, { version: '2.0.0' },
                    { version: '2.1.0-beta' }, { version: '3.0.0', retracted: true },
                ],
            };
            assert.strictEqual(pickNonRetractedLatest(json).version, '2.0.0');
        });
        it('returns empty object when nothing qualifies', () => {
            assert.deepStrictEqual(pickNonRetractedLatest({ latest: { retracted: true }, versions: [] }), {});
        });
    });

    describe('range parity and adoption-gate lookups', () => {
        /** Every real bounded-max entry, with its package name. */
        const boundedEntries = () => [...allKnownIssues()].flatMap(([name, es]) =>
            es.filter(e => e.appliesToMaxVersion).map(e => ({ name, e })));
        it('a bounded entry is NOT returned at/above its max (exclusive), nor for latest', () => {
            const all = boundedEntries();
            assert.ok(all.length > 0);
            for (const { name, e } of all) {
                assert.notStrictEqual(findKnownIssue(name, e.appliesToMaxVersion!), e, name);
                assert.notStrictEqual(findKnownIssue(name, '999.0.0'), e, name);
            }
        });
        it('a bounded entry is returned just below its max and reads as upgrade_required', () => {
            const cand = boundedEntries().find(({ e }) =>
                (e.status === 'end_of_life' || e.status === 'upgrade_required') && !e.appliesToMinVersion && /^\d+\.0\.0$/.test(e.appliesToMaxVersion!)
                && parseInt(e.appliesToMaxVersion!, 10) > 0);
            assert.ok(cand);
            const major = parseInt(cand!.e.appliesToMaxVersion!, 10);
            const found = findKnownIssue(cand!.name, `${major - 1}.9.9`);
            assert.strictEqual(found, cand!.e);
            assert.strictEqual(effectiveIssueStatus(found), 'upgrade_required');
        });
    });

    describe('l10n of upgrade-required text', () => {
        it('all lifecycle keys resolve in the English catalog', () => {
            const keys = [
                'lifecycle.note.statusMayBeOutdated', 'lifecycle.note.maintenanceMode',
                'lifecycle.note.caution', 'lifecycle.note.unlisted',
                'lifecycle.upgradeRequired.diagnostic', 'lifecycle.upgradeRequired.problem',
                'lifecycle.upgradeRequired.insight', 'packageDashboard.summary.upgradeTitle',
            ];
            for (const k of keys) { assert.notStrictEqual(l10n(k), k, k); }
        });
        it('problemMessage and collectProblems use the catalog', () => {
            const msg = problemMessage({
                type: 'unhealthy', category: 'upgrade-required', score: 55, package: 'p',
                severity: 'medium', id: 'x', line: 0,
            } as any);
            assert.strictEqual(msg, 'Score 55/100 — installed version needs upgrading');
            const probs = collectProblems(res({ category: 'upgrade-required', package: { name: 'p' } } as any), new Map(), new Map());
            assert.strictEqual(probs[0].message, l10n('lifecycle.upgradeRequired.insight'));
        });
        it('budget counts upgrade-required with outdated', () => {
            const a = computeActuals([res({ category: 'upgrade-required', score: 50 } as any)]);
            assert.strictEqual(a.outdatedCount, 1);
            assert.strictEqual(a.endOfLifeCount, 0);
        });
    });
});
