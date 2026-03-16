import * as assert from 'assert';
import * as fs from 'fs';
import * as path from 'path';
import { parsePubOutdatedJson } from '../../../vibrancy/services/pub-outdated';

const fixturesDir = path.join(
    __dirname, '..', '..', '..', 'src', 'test', 'fixtures',
);
const FIXTURE_PATH = path.join(fixturesDir, 'pub-outdated.json');

describe('pub-outdated', () => {
    describe('parsePubOutdatedJson', () => {
        it('should parse fixture into typed entries', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const entries = parsePubOutdatedJson(json);
            assert.strictEqual(entries.length, 4);
        });

        it('should extract version fields correctly', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const entries = parsePubOutdatedJson(json);
            const intl = entries.find(e => e.package === 'intl');
            assert.ok(intl);
            assert.strictEqual(intl.current, '0.17.0');
            assert.strictEqual(intl.upgradable, '0.17.0');
            assert.strictEqual(intl.resolvable, '0.17.0');
            assert.strictEqual(intl.latest, '0.19.0');
        });

        it('should identify up-to-date packages', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const entries = parsePubOutdatedJson(json);
            const pathPkg = entries.find(e => e.package === 'path');
            assert.ok(pathPkg);
            assert.strictEqual(pathPkg.current, pathPkg.latest);
        });

        it('should return empty array for empty JSON', () => {
            assert.deepStrictEqual(parsePubOutdatedJson('{}'), []);
        });

        it('should return empty array for invalid JSON', () => {
            assert.deepStrictEqual(parsePubOutdatedJson('not json'), []);
        });

        it('should return empty array when packages is not an array', () => {
            assert.deepStrictEqual(
                parsePubOutdatedJson('{"packages": "bad"}'),
                [],
            );
        });

        it('should skip entries without package name', () => {
            const json = JSON.stringify({
                packages: [
                    { current: { version: '1.0.0' } },
                    { package: 'valid', current: { version: '1.0.0' } },
                ],
            });
            const entries = parsePubOutdatedJson(json);
            assert.strictEqual(entries.length, 1);
            assert.strictEqual(entries[0].package, 'valid');
        });

        it('should handle null version objects', () => {
            const json = JSON.stringify({
                packages: [{
                    package: 'test_pkg',
                    current: null,
                    upgradable: null,
                    resolvable: { version: '2.0.0' },
                    latest: { version: '2.0.0' },
                }],
            });
            const entries = parsePubOutdatedJson(json);
            assert.strictEqual(entries[0].current, null);
            assert.strictEqual(entries[0].upgradable, null);
            assert.strictEqual(entries[0].resolvable, '2.0.0');
        });

        it('should handle JSON with leading non-JSON text', () => {
            const json = 'Some warning text\n' + JSON.stringify({
                packages: [{ package: 'pkg', current: { version: '1.0.0' } }],
            });
            const entries = parsePubOutdatedJson(json);
            assert.strictEqual(entries.length, 1);
        });
    });
});
