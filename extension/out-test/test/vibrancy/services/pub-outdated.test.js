"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const assert = __importStar(require("assert"));
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const pub_outdated_1 = require("../../../vibrancy/services/pub-outdated");
const fixturesDir = path.join(__dirname, '..', '..', '..', 'src', 'test', 'fixtures');
const FIXTURE_PATH = path.join(fixturesDir, 'pub-outdated.json');
describe('pub-outdated', () => {
    describe('parsePubOutdatedJson', () => {
        it('should parse fixture into typed entries', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const entries = (0, pub_outdated_1.parsePubOutdatedJson)(json);
            assert.strictEqual(entries.length, 4);
        });
        it('should extract version fields correctly', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const entries = (0, pub_outdated_1.parsePubOutdatedJson)(json);
            const intl = entries.find(e => e.package === 'intl');
            assert.ok(intl);
            assert.strictEqual(intl.current, '0.17.0');
            assert.strictEqual(intl.upgradable, '0.17.0');
            assert.strictEqual(intl.resolvable, '0.17.0');
            assert.strictEqual(intl.latest, '0.19.0');
        });
        it('should identify up-to-date packages', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const entries = (0, pub_outdated_1.parsePubOutdatedJson)(json);
            const pathPkg = entries.find(e => e.package === 'path');
            assert.ok(pathPkg);
            assert.strictEqual(pathPkg.current, pathPkg.latest);
        });
        it('should return empty array for empty JSON', () => {
            assert.deepStrictEqual((0, pub_outdated_1.parsePubOutdatedJson)('{}'), []);
        });
        it('should return empty array for invalid JSON', () => {
            assert.deepStrictEqual((0, pub_outdated_1.parsePubOutdatedJson)('not json'), []);
        });
        it('should return empty array when packages is not an array', () => {
            assert.deepStrictEqual((0, pub_outdated_1.parsePubOutdatedJson)('{"packages": "bad"}'), []);
        });
        it('should skip entries without package name', () => {
            const json = JSON.stringify({
                packages: [
                    { current: { version: '1.0.0' } },
                    { package: 'valid', current: { version: '1.0.0' } },
                ],
            });
            const entries = (0, pub_outdated_1.parsePubOutdatedJson)(json);
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
            const entries = (0, pub_outdated_1.parsePubOutdatedJson)(json);
            assert.strictEqual(entries[0].current, null);
            assert.strictEqual(entries[0].upgradable, null);
            assert.strictEqual(entries[0].resolvable, '2.0.0');
        });
        it('should handle JSON with leading non-JSON text', () => {
            const json = 'Some warning text\n' + JSON.stringify({
                packages: [{ package: 'pkg', current: { version: '1.0.0' } }],
            });
            const entries = (0, pub_outdated_1.parsePubOutdatedJson)(json);
            assert.strictEqual(entries.length, 1);
        });
    });
});
//# sourceMappingURL=pub-outdated.test.js.map