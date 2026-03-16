import * as assert from 'assert';
import knownIssuesData from '../../../vibrancy/data/known_issues.json';
import { findKnownIssue, allKnownIssues, isReplacementPackageName, getReplacementDisplayText } from '../../../vibrancy/scoring/known-issues';

/** Flatten grouped map into a flat array of [name, issue] pairs. */
function flatEntries(): [string, { status: string; replacement?: string; migrationNotes?: string; archiveSizeBytes?: number }][] {
    const result: [string, any][] = [];
    for (const [name, issues] of allKnownIssues()) {
        for (const issue of issues) {
            result.push([name, issue]);
        }
    }
    return result;
}

describe('known-issues', () => {
    it('should have unique name+version tuples', () => {
        type RawIssue = { name: string; appliesToMinVersion?: string; appliesToMaxVersion?: string };
        const issues = (knownIssuesData as { issues: RawIssue[] }).issues;
        const keys = issues.map(
            (e) => `${e.name}|${e.appliesToMinVersion ?? ''}|${e.appliesToMaxVersion ?? ''}`,
        );
        const dupes = keys.filter(
            (k, i) => keys.indexOf(k) !== i,
        );
        assert.deepStrictEqual(
            dupes,
            [],
            `duplicate name+version tuples in known_issues.json: ${dupes.join(', ')}`,
        );
    });

    it('should find a known bad package', () => {
        const issue = findKnownIssue('flutter_datetime_picker');
        assert.ok(issue);
        assert.strictEqual(issue.status, 'end_of_life');
        assert.ok(issue.reason && issue.reason.length > 0);
    });

    it('should return null for unknown packages', () => {
        assert.strictEqual(findKnownIssue('totally_made_up_pkg'), null);
    });

    it('should load all known issues', () => {
        const all = allKnownIssues();
        assert.ok(all.size >= 400, `expected at least 400 unique names, got ${all.size}`);
    });

    it('should have required fields on every entry', () => {
        for (const [name, issue] of flatEntries()) {
            assert.ok(name.length > 0, `empty name`);
            assert.ok(issue.status.length > 0, `${name}: missing status`);
        }
    });

    it('should find an active status package', () => {
        const issue = findKnownIssue('http');
        assert.ok(issue);
        assert.strictEqual(issue.status, 'active');
    });

    it('should normalize N/A replacement to undefined', () => {
        const issue = findKnownIssue('http');
        assert.ok(issue);
        assert.strictEqual(issue.replacement, undefined);
        assert.strictEqual(issue.migrationNotes, undefined);
    });

    it('should preserve archiveSizeBytes when present', () => {
        const issue = findKnownIssue('flutter_datetime_picker');
        assert.ok(issue);
        assert.strictEqual(issue.archiveSizeBytes, 317440);
    });

    it('should leave archiveSizeBytes undefined when null in JSON', () => {
        let foundUndefined = false;
        for (const [, issue] of flatEntries()) {
            if (issue.archiveSizeBytes === undefined) {
                foundUndefined = true;
                break;
            }
        }
        assert.ok(foundUndefined, 'expected at least one entry with undefined archiveSizeBytes');
    });

    it('should parse license field when present', () => {
        const issue = findKnownIssue('flutter_datetime_picker');
        assert.ok(issue);
        assert.strictEqual(issue.license, 'MIT');
    });

    it('should parse platforms array when present', () => {
        const issue = findKnownIssue('flutter_datetime_picker');
        assert.ok(issue);
        assert.ok(Array.isArray(issue.platforms));
    });

    it('should parse pubPoints when present', () => {
        const issue = findKnownIssue('flutter_datetime_picker');
        assert.ok(issue);
        assert.strictEqual(typeof issue.pubPoints, 'number');
    });

    it('should parse verifiedPublisher when present', () => {
        const issue = findKnownIssue('flutter_datetime_picker');
        assert.ok(issue);
        assert.strictEqual(typeof issue.verifiedPublisher, 'boolean');
    });

    it('should parse overrideReason when present', () => {
        const issue = findKnownIssue('path_provider_foundation');
        assert.ok(issue);
        assert.strictEqual(typeof issue.overrideReason, 'string');
        assert.ok(issue.overrideReason!.length > 0);
    });

    it('should have migrationNotes when replacement is present', () => {
        for (const [name, issue] of flatEntries()) {
            if (issue.replacement) {
                assert.ok(
                    issue.migrationNotes,
                    `${name}: has replacement but missing migrationNotes`,
                );
            }
        }
    });

    describe('version-scoped lookup', () => {
        it('should match scoped entry when version falls in range', () => {
            const issue = findKnownIssue('flutter_local_notifications', '8.5.0');
            assert.ok(issue, 'expected a match for flutter_local_notifications@8.5.0');
            assert.strictEqual(issue.appliesToMinVersion, '8.0.0');
            assert.strictEqual(issue.appliesToMaxVersion, '9.0.0');
        });

        it('should match different scoped entry for different version', () => {
            const issue = findKnownIssue('flutter_local_notifications', '9.2.0');
            assert.ok(issue, 'expected a match for flutter_local_notifications@9.2.0');
            assert.strictEqual(issue.appliesToMinVersion, '9.0.0');
            assert.strictEqual(issue.appliesToMaxVersion, '10.0.0');
        });

        it('should return null when version outside all ranges and no unscoped entry', () => {
            // flutter_local_notifications has only scoped entries (v8, v9), no unscoped
            const issue = findKnownIssue('flutter_local_notifications', '10.0.0');
            assert.strictEqual(issue, null);
        });

        it('should return unscoped entry when no version provided', () => {
            // flutter_datetime_picker has an unscoped entry
            const issue = findKnownIssue('flutter_datetime_picker');
            assert.ok(issue);
            assert.strictEqual(issue.status, 'end_of_life');
        });

        it('should prefer scoped entry over unscoped for matching version', () => {
            // timeago has both scoped v2 (end_of_life) and unscoped (active)
            const v2 = findKnownIssue('timeago', '2.5.0');
            assert.ok(v2, 'expected scoped v2 match');
            assert.strictEqual(v2.appliesToMinVersion, '2.0.0');

            const v4 = findKnownIssue('timeago', '4.0.0');
            assert.ok(v4, 'expected unscoped fallback');
            assert.strictEqual(v4.appliesToMinVersion, undefined);
        });

        it('should treat min as inclusive', () => {
            // Exactly at min bound should match
            const issue = findKnownIssue('flutter_local_notifications', '8.0.0');
            assert.ok(issue, 'min bound should be inclusive');
            assert.strictEqual(issue.appliesToMinVersion, '8.0.0');
        });

        it('should treat max as exclusive', () => {
            // Exactly at max bound should NOT match that range
            // 9.0.0 is the max of v8 range — should match v9 range instead
            const issue = findKnownIssue('flutter_local_notifications', '9.0.0');
            assert.ok(issue);
            assert.strictEqual(issue.appliesToMinVersion, '9.0.0');
        });
    });

    describe('isReplacementPackageName', () => {
        it('should return true for pub package names', () => {
            assert.strictEqual(isReplacementPackageName('dio'), true);
            assert.strictEqual(isReplacementPackageName('path_provider'), true);
            assert.strictEqual(isReplacementPackageName('flutter_secure_storage'), true);
        });

        it('should return false for upgrade instructions and freeform text', () => {
            assert.strictEqual(isReplacementPackageName('Update to v9+'), false);
            assert.strictEqual(isReplacementPackageName('Update to latest version'), false);
            assert.strictEqual(isReplacementPackageName('Use Native Channels'), false);
            assert.strictEqual(isReplacementPackageName('Native `showDialog`'), false);
        });
    });

    describe('getReplacementDisplayText', () => {
        it('should return replacement when no obsolete-from-version or when version below', () => {
            assert.strictEqual(getReplacementDisplayText('dio', '1.0.0'), 'dio');
            assert.strictEqual(getReplacementDisplayText('Update to latest version', '1.0.0'), 'Update to latest version');
            assert.strictEqual(getReplacementDisplayText('Update to v9+', '8.0.0', '9.0.0'), 'Update to v9+');
            assert.strictEqual(getReplacementDisplayText('Update to v9+', '5.0.0', '9.0.0'), 'Update to v9+');
        });

        it('should return undefined when replacementObsoleteFromVersion set and current >= it', () => {
            assert.strictEqual(getReplacementDisplayText('Update to v9+', '10.0.0', '9.0.0'), undefined);
            assert.strictEqual(getReplacementDisplayText('Update to v9+', '9.0.0', '9.0.0'), undefined);
            assert.strictEqual(getReplacementDisplayText('Update to v9+', '9.1.0', '9.0.0'), undefined);
        });

        it('should support single-segment threshold (e.g. "9")', () => {
            assert.strictEqual(getReplacementDisplayText('Update to v9+', '10', '9'), undefined);
            assert.strictEqual(getReplacementDisplayText('Update to v9+', '8', '9'), 'Update to v9+');
        });
    });
});
