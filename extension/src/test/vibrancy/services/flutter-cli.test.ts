import * as assert from 'assert';
import { runPubGet, runFlutterTest } from '../../../vibrancy/services/flutter-cli';

/**
 * flutter-cli calls execFile internally. Tests are integration-style:
 * they return real results when Flutter is installed, or fail gracefully.
 */
describe('flutter-cli', () => {
    describe('runPubGet', () => {
        it('should return a CommandResult with success boolean', async () => {
            const result = await runPubGet('.');
            assert.strictEqual(typeof result.success, 'boolean');
            assert.strictEqual(typeof result.output, 'string');
        });

        it('should fail for a non-existent directory', async () => {
            const result = await runPubGet('/nonexistent-path-12345');
            assert.strictEqual(result.success, false);
        });
    });

    describe('runFlutterTest', () => {
        it('should return a CommandResult with success boolean', async () => {
            const result = await runFlutterTest('.');
            assert.strictEqual(typeof result.success, 'boolean');
            assert.strictEqual(typeof result.output, 'string');
        });

        it('should fail for a non-existent directory', async () => {
            const result = await runFlutterTest('/nonexistent-path-12345');
            assert.strictEqual(result.success, false);
        });
    });
});
