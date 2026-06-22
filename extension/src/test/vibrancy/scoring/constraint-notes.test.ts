/**
 * Tests [buildConstraintNotes]: assembling ceiling/floor/forbidden explanation
 * lines per package, scoped to the direct deps that get annotated.
 */
import '../register-vscode-mock';
import * as assert from 'assert';
import { buildConstraintNotes } from '../../../vibrancy/scoring/constraint-notes';
import { FloorConstraint } from '../../../vibrancy/scoring/floor-constraints';
import { ForbiddenConstraint } from '../../../vibrancy/scoring/forbidden-constraints';
import { VibrancyResult, BlockerInfo } from '../../../vibrancy/types';
import { makeMinimalResult } from '../test-helpers';

/** A VibrancyResult for `name` carrying an optional blocker. */
function resultWithBlocker(name: string, blocker: BlockerInfo | null): VibrancyResult {
    return { ...makeMinimalResult({ name }), blocker };
}

describe('constraint-notes', () => {
    it('emits a held-back note for a shared-dep ceiling block', () => {
        const result = resultWithBlocker('dart_style', {
            blockedPackage: 'dart_style', currentVersion: '3.1.7',
            latestVersion: '3.1.8', blockerPackage: 'saropa_lints',
            blockerVibrancyScore: null, blockerCategory: null,
            sharedDependency: 'analyzer', blockerConstraint: '>=9.0.0 <13.0.0',
            sharedDependencyResolvable: '12.0.0', sharedDependencyLatest: '13.1.0',
        });

        const notes = buildConstraintNotes(
            [result], [], [], new Set(['dart_style']),
        );

        assert.deepStrictEqual(notes.get('dart_style'), [
            'held back — via analyzer — saropa_lints caps >=9.0.0 <13.0.0 '
            + '(12.0.0 resolvable, 13.1.0 latest)',
        ]);
    });

    it('emits a forbidden note keyed by the declared package', () => {
        const forbidden: ForbiddenConstraint = {
            package: 'characters', declaredConstraint: '^1.4.1',
            pinnedVersion: '1.4.0', pinnedBy: 'flutter_test',
        };

        const notes = buildConstraintNotes(
            [], [], [forbidden], new Set(['characters']),
        );

        assert.deepStrictEqual(notes.get('characters'), [
            'your characters ^1.4.1 is incompatible with flutter_test '
            + '(Flutter SDK), which pins characters 1.4.0',
        ]);
    });

    it('emits a required-by note keyed by the forced dependency', () => {
        const floor: FloorConstraint = {
            dependency: 'timezone', constrainer: 'device_calendar',
            constraint: '^0.11.0', floorVersion: '0.11.0', chain: null,
        };

        const notes = buildConstraintNotes(
            [], [floor], [], new Set(['timezone']),
        );

        assert.deepStrictEqual(notes.get('timezone'), [
            'required by device_calendar (^0.11.0)',
        ]);
    });

    it('skips packages that are not annotation targets', () => {
        const floor: FloorConstraint = {
            dependency: 'timezone', constrainer: 'device_calendar',
            constraint: '^0.11.0', floorVersion: '0.11.0', chain: null,
        };

        const notes = buildConstraintNotes([], [floor], [], new Set(['other']));

        assert.strictEqual(notes.has('timezone'), false);
    });

    it('omits an ordinary reverse-dep blocker with no shared-dep detail', () => {
        const result = resultWithBlocker('foo', {
            blockedPackage: 'foo', currentVersion: '1.0.0',
            latestVersion: '2.0.0', blockerPackage: 'bar',
            blockerVibrancyScore: null, blockerCategory: null,
        });

        const notes = buildConstraintNotes([result], [], [], new Set(['foo']));

        assert.strictEqual(notes.has('foo'), false);
    });
});
