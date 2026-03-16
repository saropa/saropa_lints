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
const upgrade_executor_1 = require("../../../vibrancy/services/upgrade-executor");
function makeStep(name, order, opts) {
    return {
        packageName: name,
        currentVersion: '1.0.0',
        targetVersion: '2.0.0',
        updateType: (opts?.updateType ?? 'minor'),
        familyId: opts?.familyId ?? null,
        order,
        mayResolveOverride: opts?.mayResolveOverride ?? null,
    };
}
describe('upgrade-executor', () => {
    describe('formatUpgradePlan', () => {
        it('should format a multi-step plan', () => {
            const steps = [
                makeStep('meta', 1, { updateType: 'patch' }),
                makeStep('http', 2, { updateType: 'minor' }),
                makeStep('go_router', 3, { updateType: 'major' }),
            ];
            const output = (0, upgrade_executor_1.formatUpgradePlan)(steps);
            assert.ok(output.includes('Upgrade Plan (3 packages)'));
            assert.ok(output.includes('[patch]'));
            assert.ok(output.includes('[minor]'));
            assert.ok(output.includes('[major]'));
            assert.ok(output.includes('meta'));
        });
        it('should include family annotations', () => {
            const steps = [
                makeStep('firebase_core', 1, {
                    updateType: 'minor', familyId: 'firebase',
                }),
            ];
            const output = (0, upgrade_executor_1.formatUpgradePlan)(steps);
            assert.ok(output.includes('← family: firebase'));
        });
        it('should handle empty plan', () => {
            const output = (0, upgrade_executor_1.formatUpgradePlan)([]);
            assert.ok(output.includes('0 packages'));
        });
    });
    describe('formatUpgradeReport', () => {
        it('should format all-success report', () => {
            const report = {
                steps: [
                    { step: makeStep('a', 1), outcome: 'success', output: '' },
                    { step: makeStep('b', 2), outcome: 'success', output: '' },
                ],
                completedCount: 2,
                failedAt: null,
            };
            const output = (0, upgrade_executor_1.formatUpgradeReport)(report);
            assert.ok(output.includes('✅ a'));
            assert.ok(output.includes('✅ b'));
        });
        it('should format pub-get failure', () => {
            const report = {
                steps: [
                    { step: makeStep('a', 1), outcome: 'pub-get-failed', output: 'error' },
                    { step: makeStep('b', 2), outcome: 'skipped', output: '' },
                ],
                completedCount: 0,
                failedAt: 'a',
            };
            const output = (0, upgrade_executor_1.formatUpgradeReport)(report);
            assert.ok(output.includes('❌ a'));
            assert.ok(output.includes('pub get failed'));
            assert.ok(output.includes('⏭️ b'));
        });
        it('should format test failure', () => {
            const report = {
                steps: [
                    { step: makeStep('a', 1), outcome: 'success', output: '' },
                    { step: makeStep('b', 2), outcome: 'test-failed', output: '' },
                ],
                completedCount: 1,
                failedAt: 'b',
            };
            const output = (0, upgrade_executor_1.formatUpgradeReport)(report);
            assert.ok(output.includes('✅ a'));
            assert.ok(output.includes('❌ b'));
            assert.ok(output.includes('flutter test failed'));
        });
    });
});
//# sourceMappingURL=upgrade-executor.test.js.map