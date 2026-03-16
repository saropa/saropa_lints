import * as assert from 'assert';
import { buildPurl } from '../../../vibrancy/scoring/purl-builder';

describe('purl-builder', () => {
    it('should build basic pub PURL', () => {
        assert.strictEqual(buildPurl('http', '1.2.0'), 'pkg:pub/http@1.2.0');
    });

    it('should handle scoped package names', () => {
        assert.strictEqual(
            buildPurl('flutter_bloc', '8.1.3'),
            'pkg:pub/flutter_bloc@8.1.3',
        );
    });

    it('should handle pre-release versions', () => {
        assert.strictEqual(
            buildPurl('pkg', '2.0.0-dev.1'),
            'pkg:pub/pkg@2.0.0-dev.1',
        );
    });

    it('should encode special characters in name', () => {
        const result = buildPurl('my%pkg', '1.0.0');
        assert.ok(result.includes('my%25pkg'));
    });
});
