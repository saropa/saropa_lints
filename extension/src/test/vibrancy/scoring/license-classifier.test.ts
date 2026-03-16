import * as assert from 'assert';
import {
    classifyLicense, licenseEmoji, LicenseTier,
} from '../../../vibrancy/scoring/license-classifier';

describe('license-classifier', () => {
    describe('classifyLicense', () => {
        it('should classify MIT as permissive', () => {
            assert.strictEqual(classifyLicense('MIT'), 'permissive');
        });

        it('should classify BSD-3-Clause as permissive', () => {
            assert.strictEqual(classifyLicense('BSD-3-Clause'), 'permissive');
        });

        it('should classify Apache-2.0 as permissive', () => {
            assert.strictEqual(classifyLicense('Apache-2.0'), 'permissive');
        });

        it('should classify GPL-3.0 as copyleft', () => {
            assert.strictEqual(classifyLicense('GPL-3.0'), 'copyleft');
        });

        it('should classify LGPL-2.1 as copyleft', () => {
            assert.strictEqual(classifyLicense('LGPL-2.1'), 'copyleft');
        });

        it('should classify MPL-2.0 as copyleft', () => {
            assert.strictEqual(classifyLicense('MPL-2.0'), 'copyleft');
        });

        it('should return unknown for null', () => {
            assert.strictEqual(classifyLicense(null), 'unknown');
        });

        it('should return unknown for empty string', () => {
            assert.strictEqual(classifyLicense(''), 'unknown');
        });

        it('should return unknown for whitespace', () => {
            assert.strictEqual(classifyLicense('   '), 'unknown');
        });

        it('should return unknown for unrecognized license', () => {
            assert.strictEqual(classifyLicense('WTFPL'), 'unknown');
        });

        it('should use least restrictive for OR expression', () => {
            assert.strictEqual(
                classifyLicense('MIT OR GPL-3.0'), 'permissive',
            );
        });

        it('should use most restrictive for AND expression', () => {
            assert.strictEqual(
                classifyLicense('MIT AND GPL-3.0'), 'copyleft',
            );
        });

        it('should handle compound with unknown component', () => {
            assert.strictEqual(
                classifyLicense('MIT OR CustomLicense'), 'permissive',
            );
        });

        it('should handle case-insensitive OR/AND', () => {
            assert.strictEqual(
                classifyLicense('MIT or Apache-2.0'), 'permissive',
            );
        });
    });

    describe('licenseEmoji', () => {
        const cases: [LicenseTier, string][] = [
            ['permissive', '🟢'],
            ['copyleft', '🟡'],
            ['unknown', '🔴'],
        ];
        for (const [tier, emoji] of cases) {
            it(`should return ${emoji} for ${tier}`, () => {
                assert.strictEqual(licenseEmoji(tier), emoji);
            });
        }
    });
});
