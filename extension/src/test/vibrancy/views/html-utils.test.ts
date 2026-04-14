import * as assert from 'assert';
import { resolveRepoUrl } from '../../../vibrancy/views/html-utils';

describe('resolveRepoUrl', () => {
    it('should prefer GitHub URL over pub.dev URL', () => {
        assert.strictEqual(
            resolveRepoUrl('https://github.com/dart-lang/http', 'https://pub.dev/repo'),
            'https://github.com/dart-lang/http',
        );
    });

    it('should fall back to pub.dev URL when GitHub URL is null', () => {
        assert.strictEqual(
            resolveRepoUrl(null, 'https://github.com/dart-lang/http'),
            'https://github.com/dart-lang/http',
        );
    });

    it('should fall back to pub.dev URL when GitHub URL is undefined', () => {
        assert.strictEqual(
            resolveRepoUrl(undefined, 'https://github.com/dart-lang/http'),
            'https://github.com/dart-lang/http',
        );
    });

    it('should return empty string when both are null', () => {
        assert.strictEqual(resolveRepoUrl(null, null), '');
    });

    it('should return empty string when both are undefined', () => {
        assert.strictEqual(resolveRepoUrl(undefined, undefined), '');
    });

    it('should strip trailing slashes', () => {
        assert.strictEqual(
            resolveRepoUrl('https://github.com/dart-lang/http/', null),
            'https://github.com/dart-lang/http',
        );
    });

    it('should strip multiple trailing slashes', () => {
        assert.strictEqual(
            resolveRepoUrl('https://github.com/dart-lang/http///', null),
            'https://github.com/dart-lang/http',
        );
    });

    it('should not strip slashes from the middle of the URL', () => {
        assert.strictEqual(
            resolveRepoUrl('https://github.com/dart-lang/http', null),
            'https://github.com/dart-lang/http',
        );
    });
});
