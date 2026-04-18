import * as assert from 'assert';
import {
    formatUpgradePlan, formatUpgradeReport,
} from '../../../vibrancy/services/upgrade-executor';
import { UpgradeStep, UpgradeReport } from '../../../vibrancy/types';

function makeStep(name: string, order: number, opts?: {
    updateType?: string; familyId?: string | null; mayResolveOverride?: string | null;
}): UpgradeStep {
    return {
        packageName: name,
        currentVersion: '1.0.0',
        targetVersion: '2.0.0',
        updateType: (opts?.updateType ?? 'minor') as UpgradeStep['updateType'],
        familyId: opts?.familyId ?? null,
        order,
        mayResolveOverride: opts?.mayResolveOverride ?? null,
    };
}

describe('upgrade-executor', () => {
    describe('formatUpgradePlan', () => {
        it('should format a multi-step plan', () => {
            const steps: UpgradeStep[] = [
                makeStep('meta', 1, { updateType: 'patch' }),
                makeStep('http', 2, { updateType: 'minor' }),
                makeStep('go_router', 3, { updateType: 'major' }),
            ];
            const output = formatUpgradePlan(steps);
            assert.ok(output.includes('Upgrade Plan (3 packages)'));
            assert.ok(output.includes('[patch]'));
            assert.ok(output.includes('[minor]'));
            assert.ok(output.includes('[major]'));
            assert.ok(output.includes('meta'));
        });

        it('should include family annotations', () => {
            const steps: UpgradeStep[] = [
                makeStep('firebase_core', 1, {
                    updateType: 'minor', familyId: 'firebase',
                }),
            ];
            const output = formatUpgradePlan(steps);
            assert.ok(output.includes('← family: firebase'));
        });

        it('should handle empty plan', () => {
            const output = formatUpgradePlan([]);
            assert.ok(output.includes('0 packages'));
        });
    });

    describe('formatUpgradeReport', () => {
        it('should format all-success report', () => {
            const report: UpgradeReport = {
                steps: [
                    { step: makeStep('a', 1), outcome: 'success', output: '' },
                    { step: makeStep('b', 2), outcome: 'success', output: '' },
                ],
                completedCount: 2,
                failedAt: null,
            };
            const output = formatUpgradeReport(report);
            assert.ok(output.includes('✅ a'));
            assert.ok(output.includes('✅ b'));
        });

        it('should format pub-get failure with error details', () => {
            const pubOutput = 'Resolving dependencies...\n'
                + 'Because foo depends on bar ^1.0.0 which depends on baz ^2.0.0, baz ^2.0.0 is required.\n'
                + 'So, because foo depends on baz ^3.0.0, version solving failed.';
            const report: UpgradeReport = {
                steps: [
                    { step: makeStep('a', 1), outcome: 'pub-get-failed', output: pubOutput },
                    { step: makeStep('b', 2), outcome: 'success', output: '' },
                ],
                completedCount: 1,
                failedAt: 'a',
            };
            const output = formatUpgradeReport(report);
            assert.ok(output.includes('❌ a'));
            assert.ok(output.includes('pub get failed'));
            // Error summary should include the "Because..." line
            assert.ok(
                output.includes('Because foo depends on bar'),
                'Should include version conflict reason',
            );
            // b should still succeed — failures no longer halt the plan
            assert.ok(output.includes('✅ b'));
        });

        it('should format test failure', () => {
            const report: UpgradeReport = {
                steps: [
                    { step: makeStep('a', 1), outcome: 'success', output: '' },
                    { step: makeStep('b', 2), outcome: 'test-failed', output: '' },
                ],
                completedCount: 1,
                failedAt: 'b',
            };
            const output = formatUpgradeReport(report);
            assert.ok(output.includes('✅ a'));
            assert.ok(output.includes('❌ b'));
            assert.ok(output.includes('flutter test failed'));
        });
    });
});
