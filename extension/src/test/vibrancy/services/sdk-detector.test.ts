import * as assert from 'assert';
import { detectDartVersion, detectFlutterVersion } from '../../../vibrancy/services/sdk-detector';

/**
 * sdk-detector calls execFile internally. We test the functions as
 * integration tests — they return real SDK versions when available,
 * or 'unknown' if not installed.
 */
describe('sdk-detector', () => {
    describe('detectDartVersion', () => {
        it('should return a string', async () => {
            const version = await detectDartVersion();
            assert.strictEqual(typeof version, 'string');
            assert.ok(version.length > 0);
        });

        it('should return a version number or unknown', async () => {
            const version = await detectDartVersion();
            const isVersion = /^\d+\.\d+\.\d+/.test(version);
            const isUnknown = version === 'unknown';
            assert.ok(
                isVersion || isUnknown,
                `Expected version or "unknown", got "${version}"`,
            );
        });
    });

    describe('detectFlutterVersion', () => {
        it('should return a string', async () => {
            const version = await detectFlutterVersion();
            assert.strictEqual(typeof version, 'string');
            assert.ok(version.length > 0);
        });

        it('should return a version number or unknown', async () => {
            const version = await detectFlutterVersion();
            const isVersion = /^\d+\.\d+\.\d+/.test(version);
            const isUnknown = version === 'unknown';
            assert.ok(
                isVersion || isUnknown,
                `Expected version or "unknown", got "${version}"`,
            );
        });
    });

    describe('version regex patterns', () => {
        it('should match Dart SDK version output', () => {
            const output = 'Dart SDK version: 3.3.0 (stable) on "windows_x64"';
            const match = output.match(/Dart SDK version:\s*(\S+)/);
            assert.strictEqual(match?.[1], '3.3.0');
        });

        it('should match Flutter version output', () => {
            const output = 'Flutter 3.19.0 • channel stable';
            const match = output.match(/Flutter\s+(\S+)/);
            assert.strictEqual(match?.[1], '3.19.0');
        });

        it('should not match random text for Dart', () => {
            const output = 'something else entirely';
            const match = output.match(/Dart SDK version:\s*(\S+)/);
            assert.strictEqual(match, null);
        });

        it('should not match random text for Flutter', () => {
            const output = 'not a flutter output';
            const match = output.match(/Flutter\s+(\S+)/);
            assert.strictEqual(match, null);
        });

        it('should handle pre-release Dart versions', () => {
            const output = 'Dart SDK version: 3.4.0-dev.1 (dev)';
            const match = output.match(/Dart SDK version:\s*(\S+)/);
            assert.strictEqual(match?.[1], '3.4.0-dev.1');
        });

        it('should handle pre-release Flutter versions', () => {
            const output = 'Flutter 3.20.0-1.0.pre • channel beta';
            const match = output.match(/Flutter\s+(\S+)/);
            assert.strictEqual(match?.[1], '3.20.0-1.0.pre');
        });
    });
});
