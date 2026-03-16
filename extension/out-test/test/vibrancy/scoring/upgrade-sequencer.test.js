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
const upgrade_sequencer_1 = require("../../../vibrancy/scoring/upgrade-sequencer");
function makeResult(name, opts = {}) {
    const status = opts.updateStatus ?? 'minor';
    return {
        package: {
            name, version: opts.currentVersion ?? '1.0.0',
            constraint: `^${opts.currentVersion ?? '1.0.0'}`,
            source: 'hosted', isDirect: true, section: 'dependencies',
        },
        pubDev: null, github: null, knownIssue: null,
        score: opts.score ?? 70, category: 'vibrant',
        resolutionVelocity: 0, engagementLevel: 0,
        popularity: 0, publisherTrust: 0,
        updateInfo: status === 'up-to-date' ? null : {
            currentVersion: opts.currentVersion ?? '1.0.0',
            latestVersion: opts.latestVersion ?? '2.0.0',
            updateStatus: status,
            changelog: null,
        },
        license: null, drift: null,
        archiveSizeBytes: null, bloatRating: null,
        isUnused: false, platforms: null,
        verifiedPublisher: false, wasmReady: null,
        blocker: null,
        upgradeBlockStatus: opts.blocked ? 'blocked' : 'upgradable',
        transitiveInfo: null,
        alternatives: [],
        latestPrerelease: null,
        prereleaseTag: null,
        vulnerabilities: [],
    };
}
describe('upgrade-sequencer', () => {
    describe('buildUpgradeOrder', () => {
        it('should return empty for up-to-date packages', () => {
            const results = [
                makeResult('http', { updateStatus: 'up-to-date' }),
            ];
            const steps = (0, upgrade_sequencer_1.buildUpgradeOrder)(results, new Map());
            assert.deepStrictEqual(steps, []);
        });
        it('should return empty when all are blocked', () => {
            const results = [
                makeResult('intl', { blocked: true }),
            ];
            const steps = (0, upgrade_sequencer_1.buildUpgradeOrder)(results, new Map());
            assert.deepStrictEqual(steps, []);
        });
        it('should order independent packages by risk', () => {
            const results = [
                makeResult('major_pkg', {
                    updateStatus: 'major', score: 80,
                }),
                makeResult('patch_pkg', {
                    updateStatus: 'patch', score: 60,
                }),
                makeResult('minor_pkg', {
                    updateStatus: 'minor', score: 70,
                }),
            ];
            const steps = (0, upgrade_sequencer_1.buildUpgradeOrder)(results, new Map());
            assert.strictEqual(steps[0].packageName, 'patch_pkg');
            assert.strictEqual(steps[1].packageName, 'minor_pkg');
            assert.strictEqual(steps[2].packageName, 'major_pkg');
        });
        it('should break risk ties by higher vibrancy first', () => {
            const results = [
                makeResult('low', { updateStatus: 'minor', score: 40 }),
                makeResult('high', { updateStatus: 'minor', score: 90 }),
            ];
            const steps = (0, upgrade_sequencer_1.buildUpgradeOrder)(results, new Map());
            assert.strictEqual(steps[0].packageName, 'high');
            assert.strictEqual(steps[1].packageName, 'low');
        });
        it('should respect dependency order', () => {
            // b depends on a — so a should be upgraded first
            const results = [
                makeResult('b', { updateStatus: 'minor' }),
                makeResult('a', { updateStatus: 'minor' }),
            ];
            const reverseDeps = new Map([
                ['a', [{ dependentPackage: 'b' }]],
            ]);
            const steps = (0, upgrade_sequencer_1.buildUpgradeOrder)(results, reverseDeps);
            assert.strictEqual(steps[0].packageName, 'a');
            assert.strictEqual(steps[1].packageName, 'b');
        });
        it('should handle diamond dependency', () => {
            // c depends on a and b; b depends on a
            const results = [
                makeResult('c', { updateStatus: 'minor' }),
                makeResult('b', { updateStatus: 'minor' }),
                makeResult('a', { updateStatus: 'minor' }),
            ];
            const reverseDeps = new Map([
                ['a', [
                        { dependentPackage: 'b' },
                        { dependentPackage: 'c' },
                    ]],
                ['b', [{ dependentPackage: 'c' }]],
            ]);
            const steps = (0, upgrade_sequencer_1.buildUpgradeOrder)(results, reverseDeps);
            const names = steps.map(s => s.packageName);
            assert.ok(names.indexOf('a') < names.indexOf('b'));
            assert.ok(names.indexOf('b') < names.indexOf('c'));
        });
        it('should group family packages together', () => {
            const results = [
                makeResult('http', { updateStatus: 'patch' }),
                makeResult('riverpod', { updateStatus: 'minor' }),
                makeResult('path', { updateStatus: 'patch' }),
                makeResult('flutter_riverpod', { updateStatus: 'minor' }),
            ];
            const steps = (0, upgrade_sequencer_1.buildUpgradeOrder)(results, new Map());
            const names = steps.map(s => s.packageName);
            const rpIdx = names.indexOf('riverpod');
            const frpIdx = names.indexOf('flutter_riverpod');
            assert.strictEqual(Math.abs(rpIdx - frpIdx), 1, 'Riverpod packages should be adjacent');
        });
        it('should assign sequential order numbers', () => {
            const results = [
                makeResult('a', { updateStatus: 'patch' }),
                makeResult('b', { updateStatus: 'minor' }),
            ];
            const steps = (0, upgrade_sequencer_1.buildUpgradeOrder)(results, new Map());
            assert.strictEqual(steps[0].order, 1);
            assert.strictEqual(steps[1].order, 2);
        });
        it('should set familyId for family packages', () => {
            const results = [
                makeResult('riverpod', { updateStatus: 'minor' }),
            ];
            const steps = (0, upgrade_sequencer_1.buildUpgradeOrder)(results, new Map());
            assert.strictEqual(steps[0].familyId, 'riverpod');
        });
        it('should set null familyId for non-family packages', () => {
            const results = [
                makeResult('http', { updateStatus: 'minor' }),
            ];
            const steps = (0, upgrade_sequencer_1.buildUpgradeOrder)(results, new Map());
            assert.strictEqual(steps[0].familyId, null);
        });
        it('should skip blocked packages', () => {
            const results = [
                makeResult('blocked_pkg', { blocked: true }),
                makeResult('ok_pkg', { updateStatus: 'patch' }),
            ];
            const steps = (0, upgrade_sequencer_1.buildUpgradeOrder)(results, new Map());
            assert.strictEqual(steps.length, 1);
            assert.strictEqual(steps[0].packageName, 'ok_pkg');
        });
    });
});
//# sourceMappingURL=upgrade-sequencer.test.js.map