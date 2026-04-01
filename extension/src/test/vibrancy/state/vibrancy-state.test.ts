import * as assert from 'assert';
import * as vscode from 'vscode';
import { VibrancyStateManager, STATE_KEYS } from '../../../vibrancy/state/vibrancy-state';
import { VibrancyResult } from '../../../vibrancy/types';
import { clearTestConfig, setTestConfig } from '../vscode-mock';

describe('VibrancyStateManager', () => {
    let manager: VibrancyStateManager;
    let contextValues: Record<string, any> = {};

    beforeEach(() => {
        clearTestConfig();
        contextValues = {};
        (vscode.commands as any).executeCommand = async (id: string, ...args: any[]) => {
            if (id === 'setContext' && args.length === 2) {
                contextValues[args[0]] = args[1];
            }
        };
        manager = new VibrancyStateManager();
    });

    afterEach(() => {
        manager.dispose();
        clearTestConfig();
    });

    describe('initial state', () => {
        it('should have hasResults false', () => {
            assert.strictEqual(manager.hasResults.value, false);
        });

        it('should have isScanning false', () => {
            assert.strictEqual(manager.isScanning.value, false);
        });

        it('should have packageCount 0', () => {
            assert.strictEqual(manager.packageCount.value, 0);
        });

        it('should have updatableCount 0', () => {
            assert.strictEqual(manager.updatableCount.value, 0);
        });

        it('should have problemCount 0', () => {
            assert.strictEqual(manager.problemCount.value, 0);
        });

        it('should have codeLensEnabled true by default', () => {
            assert.strictEqual(manager.codeLensEnabled.value, true);
        });

        it('should have selectedPackage null', () => {
            assert.strictEqual(manager.selectedPackage.value, null);
        });

        it('should respect enableCodeLens setting', () => {
            manager.dispose();
            setTestConfig('saropaLints.packageVibrancy', 'enableCodeLens', false);
            manager = new VibrancyStateManager();
            assert.strictEqual(manager.codeLensEnabled.value, false);
        });
    });

    describe('STATE_KEYS', () => {
        it('should have correct key prefixes', () => {
            assert.ok(STATE_KEYS.hasResults.startsWith('saropaLints.packageVibrancy.'));
            assert.ok(STATE_KEYS.isScanning.startsWith('saropaLints.packageVibrancy.'));
            assert.ok(STATE_KEYS.codeLensEnabled.startsWith('saropaLints.packageVibrancy.'));
        });
    });

    describe('scanning state', () => {
        it('startScanning should set isScanning true', () => {
            manager.startScanning();
            assert.strictEqual(manager.isScanning.value, true);
        });

        it('stopScanning should set isScanning false', () => {
            manager.startScanning();
            manager.stopScanning();
            assert.strictEqual(manager.isScanning.value, false);
        });

        it('startScanning should fire onDidChangeScanning', (done) => {
            manager.onDidChangeScanning((scanning) => {
                assert.strictEqual(scanning, true);
                done();
            });
            manager.startScanning();
        });

        it('stopScanning should fire onDidChangeScanning', (done) => {
            manager.startScanning();
            manager.onDidChangeScanning((scanning) => {
                assert.strictEqual(scanning, false);
                done();
            });
            manager.stopScanning();
        });
    });

    describe('updateFromResults', () => {
        const makeResult = (overrides: Partial<VibrancyResult> = {}): VibrancyResult => ({
            package: { name: 'test', version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
            pubDev: null,
            github: null,
            knownIssue: null,
            score: 50,
            category: 'vibrant',
            resolutionVelocity: 0,
            engagementLevel: 0,
            popularity: 0,
            publisherTrust: 0,
            updateInfo: null,
            license: null,
            archiveSizeBytes: null,
            bloatRating: null,
            isUnused: false,
            platforms: null,
            verifiedPublisher: false,
            wasmReady: null,
            blocker: null,
            upgradeBlockStatus: 'up-to-date',
            transitiveInfo: null,
            alternatives: [],
            latestPrerelease: null,
            prereleaseTag: null,
            vulnerabilities: [],
            ...overrides,
        });

        it('should set hasResults true when results exist', () => {
            manager.updateFromResults([makeResult()]);
            assert.strictEqual(manager.hasResults.value, true);
        });

        it('should set hasResults false for empty results', () => {
            manager.updateFromResults([makeResult()]);
            manager.updateFromResults([]);
            assert.strictEqual(manager.hasResults.value, false);
        });

        it('should update packageCount', () => {
            manager.updateFromResults([makeResult(), makeResult()]);
            assert.strictEqual(manager.packageCount.value, 2);
        });

        it('should count updatable packages', () => {
            manager.updateFromResults([
                makeResult({ updateInfo: { currentVersion: '1.0.0', latestVersion: '2.0.0', updateStatus: 'major', changelog: null } }),
                makeResult({ updateInfo: { currentVersion: '1.0.0', latestVersion: '1.0.0', updateStatus: 'up-to-date', changelog: null } }),
                makeResult({ updateInfo: { currentVersion: '1.0.0', latestVersion: '1.1.0', updateStatus: 'minor', changelog: null } }),
            ]);
            assert.strictEqual(manager.updatableCount.value, 2);
        });

        it('should not count unknown updates as updatable', () => {
            manager.updateFromResults([
                makeResult({ updateInfo: { currentVersion: '1.0.0', latestVersion: '???', updateStatus: 'unknown', changelog: null } }),
            ]);
            assert.strictEqual(manager.updatableCount.value, 0);
        });

        it('should not count null updateInfo as updatable', () => {
            manager.updateFromResults([
                makeResult({ updateInfo: null }),
            ]);
            assert.strictEqual(manager.updatableCount.value, 0);
        });

        it('should count problem packages', () => {
            // Abandoned, end-of-life, and outdated are all problem categories
            manager.updateFromResults([
                makeResult({ category: 'end-of-life' }),
                makeResult({ category: 'abandoned' }),
                makeResult({ category: 'outdated' }),
                makeResult({ category: 'vibrant' }),
                makeResult({ category: 'stable' }),
            ]);
            assert.strictEqual(manager.problemCount.value, 3);
        });

        it('should fire onDidChangeResults', (done) => {
            manager.onDidChangeResults(() => {
                done();
            });
            manager.updateFromResults([makeResult()]);
        });
    });

    describe('codeLens methods', () => {
        it('toggleCodeLens should flip state', () => {
            assert.strictEqual(manager.codeLensEnabled.value, true);
            manager.toggleCodeLens();
            assert.strictEqual(manager.codeLensEnabled.value, false);
            manager.toggleCodeLens();
            assert.strictEqual(manager.codeLensEnabled.value, true);
        });

        it('showCodeLens should enable', () => {
            manager.hideCodeLens();
            manager.showCodeLens();
            assert.strictEqual(manager.codeLensEnabled.value, true);
        });

        it('hideCodeLens should disable', () => {
            manager.hideCodeLens();
            assert.strictEqual(manager.codeLensEnabled.value, false);
        });
    });

    describe('reset', () => {
        it('should reset all values to defaults', () => {
            manager.updateFromResults([{
                package: { name: 'test', version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
                pubDev: null, github: null, knownIssue: null, score: 50, category: 'vibrant',
                resolutionVelocity: 0, engagementLevel: 0, popularity: 0, publisherTrust: 0,
                updateInfo: { currentVersion: '1.0.0', latestVersion: '2.0.0', updateStatus: 'major', changelog: null },
                platforms: null, verifiedPublisher: false, wasmReady: null, blocker: null,
                upgradeBlockStatus: 'up-to-date', transitiveInfo: null, alternatives: [], latestPrerelease: null, prereleaseTag: null, vulnerabilities: [],
            }]);
            manager.startScanning();
            manager.selectedPackage.value = 'some_package';

            manager.reset();

            assert.strictEqual(manager.hasResults.value, false);
            assert.strictEqual(manager.isScanning.value, false);
            assert.strictEqual(manager.packageCount.value, 0);
            assert.strictEqual(manager.updatableCount.value, 0);
            assert.strictEqual(manager.problemCount.value, 0);
            assert.strictEqual(manager.selectedPackage.value, null);
        });

        it('should not reset codeLensEnabled', () => {
            manager.hideCodeLens();
            manager.reset();
            assert.strictEqual(manager.codeLensEnabled.value, false);
        });
    });

    describe('syncAll', () => {
        it('should sync all states to context', () => {
            contextValues = {};
            manager.syncAll();

            assert.strictEqual(contextValues[STATE_KEYS.hasResults], false);
            assert.strictEqual(contextValues[STATE_KEYS.isScanning], false);
            assert.strictEqual(contextValues[STATE_KEYS.packageCount], 0);
            assert.strictEqual(contextValues[STATE_KEYS.updatableCount], 0);
            assert.strictEqual(contextValues[STATE_KEYS.problemCount], 0);
            assert.strictEqual(contextValues[STATE_KEYS.codeLensEnabled], true);
            assert.strictEqual(contextValues[STATE_KEYS.selectedPackage], null);
        });
    });

    describe('dispose', () => {
        it('should be callable', () => {
            manager.dispose();
        });

        it('should be callable multiple times', () => {
            manager.dispose();
            manager.dispose();
        });
    });
});
