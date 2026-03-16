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
const flutter_releases_1 = require("../../../vibrancy/services/flutter-releases");
describe('flutter-releases', () => {
    describe('parseStableReleases', () => {
        it('should filter to stable channel only', () => {
            const json = {
                releases: [
                    { version: '3.24.0', release_date: '2024-08-01', channel: 'stable' },
                    { version: '3.25.0-dev', release_date: '2024-09-01', channel: 'dev' },
                    { version: '3.24.1', release_date: '2024-08-15', channel: 'stable' },
                    { version: '3.25.0-beta', release_date: '2024-09-10', channel: 'beta' },
                ],
            };
            const releases = (0, flutter_releases_1.parseStableReleases)(json);
            assert.strictEqual(releases.length, 2);
            assert.ok(releases.every(r => !r.version.includes('dev')));
            assert.ok(releases.every(r => !r.version.includes('beta')));
        });
        it('should sort newest first', () => {
            const json = {
                releases: [
                    { version: '3.22.0', release_date: '2024-06-01', channel: 'stable' },
                    { version: '3.24.0', release_date: '2024-08-01', channel: 'stable' },
                    { version: '3.19.0', release_date: '2024-03-01', channel: 'stable' },
                ],
            };
            const releases = (0, flutter_releases_1.parseStableReleases)(json);
            assert.strictEqual(releases[0].version, '3.24.0');
            assert.strictEqual(releases[2].version, '3.19.0');
        });
        it('should return empty for missing releases array', () => {
            assert.deepStrictEqual((0, flutter_releases_1.parseStableReleases)({}), []);
        });
        it('should return empty for null input', () => {
            assert.deepStrictEqual((0, flutter_releases_1.parseStableReleases)(null), []);
        });
        it('should extract version and releaseDate', () => {
            const json = {
                releases: [
                    { version: '3.24.0', release_date: '2024-08-01T00:00:00Z', channel: 'stable' },
                ],
            };
            const releases = (0, flutter_releases_1.parseStableReleases)(json);
            assert.strictEqual(releases[0].version, '3.24.0');
            assert.strictEqual(releases[0].releaseDate, '2024-08-01T00:00:00Z');
        });
    });
});
//# sourceMappingURL=flutter-releases.test.js.map