import * as assert from 'assert';
import { buildAlternatives } from '../../../vibrancy/services/pub-dev-search';
import { AlternativeSuggestion } from '../../../vibrancy/types';

describe('alternatives scoring', () => {
    describe('threshold logic', () => {
        it('should show curated replacement regardless of score', () => {
            const result = buildAlternatives('replacement_pkg', []);

            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].name, 'replacement_pkg');
            assert.strictEqual(result[0].source, 'curated');
        });

        it('should not include discovery alternatives when curated exists', () => {
            const discovery: AlternativeSuggestion[] = [
                { name: 'alt1', source: 'discovery', score: 90, likes: 500 },
                { name: 'alt2', source: 'discovery', score: 85, likes: 300 },
            ];

            const result = buildAlternatives('curated_pkg', discovery);

            assert.strictEqual(result.length, 1);
            assert.ok(result.every(r => r.source === 'curated'));
        });

        it('should include all discovery alternatives when no curated', () => {
            const discovery: AlternativeSuggestion[] = [
                { name: 'alt1', source: 'discovery', score: 90, likes: 500 },
                { name: 'alt2', source: 'discovery', score: 85, likes: 300 },
            ];

            const result = buildAlternatives(undefined, discovery);

            assert.strictEqual(result.length, 2);
            assert.ok(result.every(r => r.source === 'discovery'));
        });
    });

    describe('curated vs discovery priority', () => {
        it('should mark curated source correctly', () => {
            const result = buildAlternatives('http', []);

            assert.strictEqual(result[0].source, 'curated');
        });

        it('should mark discovery source correctly', () => {
            const discovery: AlternativeSuggestion[] = [
                { name: 'dio', source: 'discovery', score: 80, likes: 1000 },
            ];

            const result = buildAlternatives(undefined, discovery);

            assert.strictEqual(result[0].source, 'discovery');
        });

        it('should preserve likes count from discovery', () => {
            const discovery: AlternativeSuggestion[] = [
                { name: 'dio', source: 'discovery', score: 80, likes: 1500 },
            ];

            const result = buildAlternatives(undefined, discovery);

            assert.strictEqual(result[0].likes, 1500);
        });

        it('should set likes to 0 for curated', () => {
            const result = buildAlternatives('http', []);

            assert.strictEqual(result[0].likes, 0);
        });
    });

    describe('edge cases', () => {
        it('should handle empty discovery array', () => {
            const result = buildAlternatives(undefined, []);
            assert.deepStrictEqual(result, []);
        });

        it('should handle undefined curated with empty discovery', () => {
            const result = buildAlternatives(undefined, []);
            assert.strictEqual(result.length, 0);
        });

        it('should preserve score from discovery suggestions', () => {
            const discovery: AlternativeSuggestion[] = [
                { name: 'package_a', source: 'discovery', score: 75, likes: 200 },
            ];

            const result = buildAlternatives(undefined, discovery);

            assert.strictEqual(result[0].score, 75);
        });

        it('should handle null score in discovery', () => {
            const discovery: AlternativeSuggestion[] = [
                { name: 'package_a', source: 'discovery', score: null, likes: 200 },
            ];

            const result = buildAlternatives(undefined, discovery);

            assert.strictEqual(result[0].score, null);
        });
    });
});
