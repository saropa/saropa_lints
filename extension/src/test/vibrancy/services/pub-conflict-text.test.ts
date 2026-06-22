/**
 * Tests [extractPubConflictExplanation]: pulling pub's verbatim version-solving
 * reasoning out of a failed resolution's stderr.
 */
import * as assert from 'assert';
import { extractPubConflictExplanation } from '../../../vibrancy/services/pub-conflict-text';

describe('pub-conflict-text', () => {
    it('extracts the Because / forbidden / required solver lines', () => {
        const stderr = [
            'Resolving dependencies...',
            'Because every version of flutter_test from sdk depends on '
            + 'characters 1.4.0 and saropa depends on characters ^1.4.1, '
            + 'flutter_test from sdk is forbidden.',
            'So, because saropa depends on flutter_test from sdk, version '
            + 'solving failed.',
            'Because saropa depends on device_calendar which depends on '
            + 'timezone ^0.11.0, timezone ^0.11.0 is required.',
        ].join('\n');

        const result = extractPubConflictExplanation(stderr);

        assert.strictEqual(result.length, 3);
        assert.ok(result[0].includes('flutter_test from sdk is forbidden'));
        assert.ok(result[1].includes('version solving failed'));
        assert.ok(result[2].includes('timezone ^0.11.0 is required'));
    });

    it('ignores non-solver noise', () => {
        const stderr = [
            'Resolving dependencies...',
            'Could not find a file named "pubspec.yaml".',
            "bash: dart: command not found",
        ].join('\n');

        assert.deepStrictEqual(extractPubConflictExplanation(stderr), []);
    });

    it('de-duplicates repeated reason lines', () => {
        const reason = 'Because foo depends on bar ^1.0.0, bar ^1.0.0 is required.';
        const result = extractPubConflictExplanation(`${reason}\n${reason}`);
        assert.deepStrictEqual(result, [reason]);
    });

    it('returns empty for empty input', () => {
        assert.deepStrictEqual(extractPubConflictExplanation(''), []);
    });
});
