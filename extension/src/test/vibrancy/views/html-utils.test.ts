/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks). */
import * as assert from 'assert';
import { escapeJsonStringForScriptBlock, jsonForScriptBlock, resolveRepoUrl } from '../../../vibrancy/views/html-utils';

/** Script-block JSON escaping for safe inline <script> embedding. */

describe('escapeJsonStringForScriptBlock', () => {
    it('escapes < to prevent script breakout', () => {
        // A JSON string containing </script> would close the script tag.
        const json = '{"msg":"</script>alert(1)"}';
        const result = escapeJsonStringForScriptBlock(json);
        assert.ok(!result.includes('<'), 'No literal < should survive');
        assert.ok(result.includes('\\u003c'), '< should be escaped to \\u003c');
    });

    it('escapes & for parser strictness', () => {
        const json = '{"name":"AT&T"}';
        const result = escapeJsonStringForScriptBlock(json);
        assert.ok(!result.includes('&'), 'No literal & should survive');
        assert.ok(result.includes('\\u0026'), '& should be escaped to \\u0026');
    });

    it('escapes U+2028 line separator', () => {
        // U+2028 is legal in JSON but illegal in a JS string literal (pre-ES2019).
        const json = '{"text":"line break"}';
        assert.ok(!escapeJsonStringForScriptBlock(json).includes(' '));
    });

    it('escapes U+2029 paragraph separator', () => {
        const json = '{"text":"para break"}';
        assert.ok(!escapeJsonStringForScriptBlock(json).includes(' '));
    });

    it('passes through safe JSON unchanged', () => {
        const json = '{"count":42,"name":"hello"}';
        // No <, &, U+2028, or U+2029 — should come back identical.
        assert.strictEqual(escapeJsonStringForScriptBlock(json), json);
    });

    it('produces the same result as jsonForScriptBlock for any value', () => {
        // jsonForScriptBlock delegates to escapeJsonStringForScriptBlock,
        // so their outputs must be identical for the same input value.
        const value = { rule: '<script>&</script>', line: 1 };
        const viaCompose = escapeJsonStringForScriptBlock(JSON.stringify(value));
        const viaDirect = jsonForScriptBlock(value);
        assert.strictEqual(viaCompose, viaDirect);
    });
});

/** Pick repository URL for webview (GitHub vs pub.dev homepage). */

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
