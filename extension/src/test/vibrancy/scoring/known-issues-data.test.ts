/** Data-consistency checks for the bundled known_issues.json (guards hand edits and migrations). */
import * as assert from 'assert';
import * as fs from 'fs';
import * as path from 'path';
import { allKnownIssues, isReplacementPackageName } from '../../../vibrancy/scoring/known-issues';
import knownIssuesData from '../../../vibrancy/data/known_issues.json';
import schema from '../../../vibrancy/data/known_issues_schema.json';

type Raw = Record<string, unknown>;
const raw = (knownIssuesData as { issues: Raw[] }).issues;
const label = (e: Raw): string => `${String(e.name)} [${String(e.status)}]`;
const STATUSES: string[] = (schema as any).properties.issues.items.properties.status.enum;

/** Numeric [major, minor, patch] of a semver-ish string, or null when it does not parse. */
function parse(v: unknown): number[] | null {
    if (typeof v !== 'string') { return null; }
    const m = /^(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:[-+][0-9A-Za-z.-]+)?$/.exec(v.trim());
    return m ? [Number(m[1]), Number(m[2] ?? 0), Number(m[3] ?? 0)] : null;
}
function cmp(a: number[], b: number[]): number {
    for (let i = 0; i < 3; i++) { if (a[i] !== b[i]) { return a[i] - b[i]; } }
    return 0;
}
const bounds = (e: Raw): { lo: string | null; hi: string | null } => ({
    lo: (e.appliesToMinVersion as string | null | undefined) || null,
    hi: (e.appliesToMaxVersion as string | null | undefined) || null,
});

describe('known_issues.json data consistency', () => {
    it('every entry has valid required fields, status and date formats', () => {
        for (const e of raw) {
            assert.ok(typeof e.name === 'string' && e.name.length > 0, `bad name ${JSON.stringify(e.name)}`);
            assert.ok(STATUSES.includes(e.status as string), `${label(e)}: invalid status`);
            assert.ok(/^\d{4}-\d{2}-\d{2}$/.test(String(e.as_of)), `${label(e)}: as_of must be YYYY-MM-DD`);
            if (e.lastUpdated) {
                assert.ok(/^\d{4}-\d{2}-\d{2}$/.test(String(e.lastUpdated)), `${label(e)}: lastUpdated format`);
            }
        }
    });

    it('bounds parse as semver and min < max', () => {
        for (const e of raw) {
            const { lo, hi } = bounds(e);
            const pl = lo ? parse(lo) : null;
            const ph = hi ? parse(hi) : null;
            if (lo) { assert.ok(pl, `${label(e)}: appliesToMinVersion '${lo}' not semver`); }
            if (hi) { assert.ok(ph, `${label(e)}: appliesToMaxVersion '${hi}' not semver`); }
            if (pl && ph) { assert.ok(cmp(pl, ph) < 0, `${label(e)}: min ${lo} >= max ${hi}`); }
        }
    });

    it('bounded entries are upgrade_required or caution, and upgrade_required is always bounded', () => {
        for (const e of raw) {
            const { lo, hi } = bounds(e);
            if (lo || hi) {
                assert.ok(e.status === 'upgrade_required' || e.status === 'caution',
                    `${label(e)}: bounded entry must be upgrade_required or caution`);
            }
            if (e.status === 'upgrade_required') {
                assert.ok(lo || hi, `${label(e)}: upgrade_required without bounds`);
            }
        }
    });

    it('no two bounded entries for one package overlap', () => {
        for (const [name, list] of allKnownIssues()) {
            const ranges = list
                .filter(e => e.appliesToMinVersion || e.appliesToMaxVersion)
                .map(e => ({
                    lo: e.appliesToMinVersion ? parse(e.appliesToMinVersion) : [0, 0, 0],
                    hi: e.appliesToMaxVersion ? parse(e.appliesToMaxVersion) : [Infinity, 0, 0],
                }));
            for (let i = 0; i < ranges.length; i++) {
                for (let j = i + 1; j < ranges.length; j++) {
                    const a = ranges[i], b = ranges[j];
                    if (!a.lo || !a.hi || !b.lo || !b.hi) { continue; }
                    const overlap = cmp(a.lo, b.hi) < 0 && cmp(b.lo, a.hi) < 0; // max is exclusive
                    assert.ok(!overlap, `${name}: overlapping bounded entries`);
                }
            }
        }
    });

    it('at most one unscoped entry per package', () => {
        for (const [name, list] of allKnownIssues()) {
            const unscoped = list.filter(e => !e.appliesToMinVersion && !e.appliesToMaxVersion);
            assert.ok(unscoped.length <= 1, `${name}: ${unscoped.length} unscoped entries`);
        }
    });

    it('package-name replacements exist on pub.dev (skipped without a snapshot)', function () {
        // reports/ is gitignored; from out-test/test/vibrancy/scoring or src/test/... the repo root is 5 up.
        const snapPath = path.resolve(__dirname, '../../../../../reports/pubdev_snapshot.json');
        if (!fs.existsSync(snapPath)) { this.skip(); }
        const packages = (JSON.parse(fs.readFileSync(snapPath, 'utf8')) as {
            packages: Record<string, { status: string }>;
        }).packages;
        for (const e of raw) {
            const r = e.replacement;
            if (typeof r !== 'string' || !isReplacementPackageName(r)) { continue; }
            const s = packages[r.trim()];
            if (!s) { continue; } // not in this snapshot
            assert.notStrictEqual(s.status, 'not_found', `${label(e)}: replacement '${r}' 404s on pub.dev`);
        }
    });
});
