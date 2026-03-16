import * as assert from 'assert';
import * as sinon from 'sinon';
import * as vscode from 'vscode';
import { workspace } from '../vscode-mock';
import { VibrancyTreeProvider } from '../../../vibrancy/providers/tree-data-provider';
import {
    PackageItem, GroupItem, DetailItem, SuppressedGroupItem,
    SuppressedPackageItem, buildGroupItems, SectionGroupItem,
} from '../../../vibrancy/providers/tree-items';
import { VibrancyResult, GitHubMetrics, DependencySection } from '../../../vibrancy/types';

function makeResult(
    name: string,
    score: number,
    updateStatus?: string,
    section: DependencySection = 'dependencies',
): VibrancyResult {
    return {
        package: { name, version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section },
        pubDev: null,
        github: null,
        knownIssue: null,
        score,
        category: score >= 70 ? 'vibrant' : score >= 40 ? 'quiet' : 'legacy-locked',
        resolutionVelocity: 0,
        engagementLevel: 0,
        popularity: 0,
        publisherTrust: 0,
        updateInfo: updateStatus ? {
            currentVersion: '1.0.0',
            latestVersion: '2.0.0',
            updateStatus: updateStatus as any,
            changelog: null,
        } : null,
        archiveSizeBytes: null,
        bloatRating: null,
        license: null,
        drift: null,
        isUnused: false, platforms: null, verifiedPublisher: false, wasmReady: null,
        blocker: null, upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null, alternatives: [], latestPrerelease: null, prereleaseTag: null,
        vulnerabilities: [],
    };
}

describe('VibrancyTreeProvider', () => {
    let provider: VibrancyTreeProvider;

    beforeEach(() => {
        provider = new VibrancyTreeProvider();
    });

    it('should return empty array when no results', () => {
        assert.strictEqual(provider.getChildren().length, 0);
    });

    it('should return PackageItems at root', () => {
        provider.updateResults([makeResult('http', 80)]);
        const children = provider.getChildren();
        assert.strictEqual(children.length, 1);
        assert.ok(children[0] instanceof PackageItem);
    });

    it('should sort worst-first', () => {
        provider.updateResults([
            makeResult('good', 90),
            makeResult('bad', 20),
            makeResult('mid', 50),
        ]);
        const children = provider.getChildren() as PackageItem[];
        assert.strictEqual(children[0].result.package.name, 'bad');
        assert.strictEqual(children[2].result.package.name, 'good');
    });

    it('should return GroupItems as children of PackageItem', () => {
        provider.updateResults([makeResult('http', 80)]);
        const root = provider.getChildren() as PackageItem[];
        const groups = provider.getChildren(root[0]);
        assert.ok(groups.length > 0);
        assert.ok(groups[0] instanceof GroupItem);
    });

    it('should return DetailItems as children of GroupItem', () => {
        provider.updateResults([makeResult('http', 80)]);
        const root = provider.getChildren() as PackageItem[];
        const groups = provider.getChildren(root[0]) as GroupItem[];
        const details = provider.getChildren(groups[0]);
        assert.ok(details.length > 0);
        assert.ok(details[0] instanceof DetailItem);
    });

    it('should fire onDidChangeTreeData on update', () => {
        let fired = false;
        provider.onDidChangeTreeData(() => { fired = true; });
        provider.updateResults([makeResult('http', 80)]);
        assert.ok(fired);
    });

    describe('getResultByName', () => {
        it('returns result when package name exists', () => {
            const r = makeResult('mock_data', 30);
            provider.updateResults([makeResult('http', 80), r, makeResult('path', 70)]);
            const found = provider.getResultByName('mock_data');
            assert.strictEqual(found, r);
        });

        it('returns undefined when no results', () => {
            assert.strictEqual(provider.getResultByName('any'), undefined);
        });

        it('returns undefined when name not in results', () => {
            provider.updateResults([makeResult('http', 80)]);
            assert.strictEqual(provider.getResultByName('nonexistent'), undefined);
        });
    });
});

describe('suppressed grouping', () => {
    let provider: VibrancyTreeProvider;
    let sandbox: sinon.SinonSandbox;

    beforeEach(() => {
        sandbox = sinon.createSandbox();
        provider = new VibrancyTreeProvider();
    });

    afterEach(() => {
        sandbox.restore();
    });

    function stubSuppressed(names: string[]): void {
        sandbox.stub(workspace, 'getConfiguration').returns({
            get: <T>(_key: string, _defaultValue?: T): T | undefined =>
                names as unknown as T,
            update: async () => {},
        });
    }

    it('should show SuppressedGroupItem when packages are suppressed', () => {
        stubSuppressed(['bad']);
        provider.updateResults([makeResult('bad', 20), makeResult('good', 90)]);
        const children = provider.getChildren();
        assert.strictEqual(children.length, 2);
        assert.ok(children[0] instanceof PackageItem);
        assert.ok(children[1] instanceof SuppressedGroupItem);
    });

    it('should return SuppressedPackageItems as children of group', () => {
        stubSuppressed(['bad']);
        provider.updateResults([makeResult('bad', 20), makeResult('good', 90)]);
        const group = provider.getChildren().find(
            c => c instanceof SuppressedGroupItem,
        )!;
        const suppressed = provider.getChildren(group);
        assert.strictEqual(suppressed.length, 1);
        assert.ok(suppressed[0] instanceof SuppressedPackageItem);
    });

    it('should show no group when none suppressed', () => {
        stubSuppressed([]);
        provider.updateResults([makeResult('good', 90)]);
        const children = provider.getChildren();
        assert.strictEqual(children.length, 1);
        assert.ok(children[0] instanceof PackageItem);
    });

    it('should show correct count in group label', () => {
        stubSuppressed(['a', 'b']);
        provider.updateResults([
            makeResult('a', 20), makeResult('b', 30), makeResult('c', 90),
        ]);
        const group = provider.getChildren().find(
            c => c instanceof SuppressedGroupItem,
        ) as SuppressedGroupItem;
        assert.strictEqual(group.label, 'Suppressed (2)');
    });

    it('should fire onDidChangeTreeData on refresh', () => {
        let fired = false;
        provider.onDidChangeTreeData(() => { fired = true; });
        provider.refresh();
        assert.ok(fired);
    });
});

describe('PackageItem', () => {
    it('should set contextValue to vibrancyPackage when no update', () => {
        const item = new PackageItem(makeResult('http', 80));
        assert.strictEqual(item.contextValue, 'vibrancyPackage');
    });

    it('should set contextValue to vibrancyPackageUpdatable when update available', () => {
        const item = new PackageItem(makeResult('http', 50, 'minor'));
        assert.strictEqual(item.contextValue, 'vibrancyPackageUpdatable');
    });

    it('should set contextValue to vibrancyPackage when up-to-date', () => {
        const item = new PackageItem(makeResult('http', 80, 'up-to-date'));
        assert.strictEqual(item.contextValue, 'vibrancyPackage');
    });

    it('should set goToPackage command with package name', () => {
        const item = new PackageItem(makeResult('http', 80));
        assert.strictEqual(item.command?.command, 'saropaLints.packageVibrancy.goToPackage');
        assert.deepStrictEqual(item.command?.arguments, ['http']);
    });
});

describe('SuppressedPackageItem', () => {
    it('should set suppressed contextValue when no update', () => {
        const item = new SuppressedPackageItem(makeResult('http', 80));
        assert.strictEqual(item.contextValue, 'vibrancyPackageSuppressed');
    });

    it('should set suppressed updatable contextValue when update available', () => {
        const item = new SuppressedPackageItem(makeResult('http', 50, 'minor'));
        assert.strictEqual(item.contextValue, 'vibrancyPackageSuppressedUpdatable');
    });

    it('should use eye-closed icon', () => {
        const item = new SuppressedPackageItem(makeResult('http', 80));
        const icon = item.iconPath as vscode.ThemeIcon;
        assert.strictEqual(icon.id, 'eye-closed');
    });
});

const stubGithub: GitHubMetrics = {
    stars: 500, openIssues: 10, closedIssuesLast90d: 5,
    mergedPrsLast90d: 3, avgCommentsPerIssue: 2,
    daysSinceLastUpdate: 7, daysSinceLastClose: 3, flaggedIssues: [], license: null,
};

describe('buildGroupItems', () => {
    function groupLabels(result: VibrancyResult): string[] {
        return buildGroupItems(result).map(g => `${g.label}`);
    }

    it('should return only Version group for minimal result', () => {
        const labels = groupLabels(makeResult('http', 80));
        assert.deepStrictEqual(labels, ['📦 Version']);
    });

    it('should include Update group when update available', () => {
        const labels = groupLabels(makeResult('http', 50, 'minor'));
        assert.ok(labels.includes('⬆️ Update'));
    });

    it('should not include Update group when up-to-date', () => {
        const labels = groupLabels(makeResult('http', 80, 'up-to-date'));
        assert.ok(!labels.includes('⬆️ Update'));
    });

    it('should include Community group when github data present', () => {
        const result = { ...makeResult('http', 80), github: stubGithub };
        const labels = groupLabels(result);
        assert.ok(labels.includes('📊 Community'));
    });

    it('should include Size group when bloat data present', () => {
        const result = {
            ...makeResult('http', 80),
            archiveSizeBytes: 1_000_000, bloatRating: 5,
        };
        const labels = groupLabels(result);
        assert.ok(labels.includes('📏 Size'));
    });

    it('should include Alerts group when known issue present', () => {
        const result = {
            ...makeResult('http', 20),
            knownIssue: { name: 'http', status: 'end_of_life', reason: 'Deprecated' },
        };
        const labels = groupLabels(result);
        assert.ok(labels.includes('🚨 Alerts'));
    });

    it('should not include Alerts group when no issues', () => {
        const labels = groupLabels(makeResult('http', 80));
        assert.ok(!labels.includes('🚨 Alerts'));
    });

    it('should include Alerts group with Unused item when isUnused', () => {
        const result = { ...makeResult('http', 80), isUnused: true };
        const groups = buildGroupItems(result);
        const alerts = groups.find(g => g.label === '🚨 Alerts')!;
        assert.ok(alerts);
        assert.ok(alerts.children.some(
            c => `${c.label}`.includes('Unused'),
        ));
    });

    it('should use green emoji for patch update', () => {
        const groups = buildGroupItems(makeResult('http', 50, 'patch'));
        const update = groups.find(g => g.label === '⬆️ Update')!;
        assert.ok(`${update.children[0].label}`.includes('🟢'));
    });

    it('should use red emoji for major update', () => {
        const groups = buildGroupItems(makeResult('http', 50, 'major'));
        const update = groups.find(g => g.label === '⬆️ Update')!;
        assert.ok(`${update.children[0].label}`.includes('🔴'));
    });

    it('should use green emoji for low bloat', () => {
        const result = {
            ...makeResult('http', 80),
            archiveSizeBytes: 50_000, bloatRating: 2,
        };
        const groups = buildGroupItems(result);
        const size = groups.find(g => g.label === '📏 Size')!;
        assert.ok(`${size.children[0].label}`.includes('🟢'));
    });

    it('should use red emoji for high bloat', () => {
        const result = {
            ...makeResult('http', 80),
            archiveSizeBytes: 50_000_000, bloatRating: 9,
        };
        const groups = buildGroupItems(result);
        const size = groups.find(g => g.label === '📏 Size')!;
        assert.ok(`${size.children[0].label}`.includes('🔴'));
    });

    it('should include all groups when full data present', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 50, 'minor'),
            github: {
                ...stubGithub,
                flaggedIssues: [{
                    number: 1, title: 'Bug', url: '',
                    matchedSignals: ['crash'], commentCount: 0,
                }],
            },
            archiveSizeBytes: 1_000_000, bloatRating: 5,
            knownIssue: { name: 'http', status: 'active', reason: 'Slow' },
        };
        const labels = groupLabels(result);
        assert.deepStrictEqual(labels, [
            '📦 Version', '⬆️ Update', '📊 Community',
            '📏 Size', '🚨 Alerts',
        ]);
    });
});

describe('section grouping', () => {
    let provider: VibrancyTreeProvider;
    let sandbox: sinon.SinonSandbox;

    beforeEach(() => {
        sandbox = sinon.createSandbox();
        provider = new VibrancyTreeProvider();
    });

    afterEach(() => {
        sandbox.restore();
    });

    function stubGrouping(mode: 'none' | 'section'): void {
        sandbox.stub(workspace, 'getConfiguration').returns({
            get: <T>(key: string, defaultValue?: T): T | undefined => {
                if (key === 'treeGrouping') { return mode as unknown as T; }
                if (key === 'suppressedPackages') { return [] as unknown as T; }
                return defaultValue;
            },
            update: async () => {},
        });
    }

    it('should show flat list when grouping is none', () => {
        stubGrouping('none');
        provider.updateResults([
            makeResult('http', 80, undefined, 'dependencies'),
            makeResult('test', 70, undefined, 'dev_dependencies'),
        ]);
        const children = provider.getChildren();
        assert.strictEqual(children.length, 2);
        assert.ok(children.every(c => c instanceof PackageItem));
    });

    it('should show section groups when grouping is section', () => {
        stubGrouping('section');
        provider.updateResults([
            makeResult('http', 80, undefined, 'dependencies'),
            makeResult('test', 70, undefined, 'dev_dependencies'),
        ]);
        const children = provider.getChildren();
        assert.strictEqual(children.length, 2);
        assert.ok(children.every(c => c instanceof SectionGroupItem));
    });

    it('should group packages by section', () => {
        stubGrouping('section');
        provider.updateResults([
            makeResult('http', 80, undefined, 'dependencies'),
            makeResult('provider', 75, undefined, 'dependencies'),
            makeResult('test', 70, undefined, 'dev_dependencies'),
        ]);
        const children = provider.getChildren() as SectionGroupItem[];
        const deps = children.find(c => c.section === 'dependencies')!;
        const devDeps = children.find(c => c.section === 'dev_dependencies')!;

        assert.strictEqual(deps.results.length, 2);
        assert.strictEqual(devDeps.results.length, 1);
    });

    it('should return PackageItems as children of SectionGroupItem', () => {
        stubGrouping('section');
        provider.updateResults([
            makeResult('http', 80, undefined, 'dependencies'),
        ]);
        const groups = provider.getChildren() as SectionGroupItem[];
        const packages = provider.getChildren(groups[0]);
        assert.strictEqual(packages.length, 1);
        assert.ok(packages[0] instanceof PackageItem);
    });

    it('should show correct label with count', () => {
        stubGrouping('section');
        provider.updateResults([
            makeResult('http', 80, undefined, 'dependencies'),
            makeResult('bloc', 75, undefined, 'dependencies'),
        ]);
        const groups = provider.getChildren() as SectionGroupItem[];
        assert.strictEqual(groups[0].label, 'Dependencies (2)');
    });

    it('should sort packages within section by score', () => {
        stubGrouping('section');
        provider.updateResults([
            makeResult('good', 90, undefined, 'dependencies'),
            makeResult('bad', 20, undefined, 'dependencies'),
        ]);
        const groups = provider.getChildren() as SectionGroupItem[];
        const deps = groups.find(c => c.section === 'dependencies')!;
        assert.strictEqual(deps.results[0].package.name, 'bad');
        assert.strictEqual(deps.results[1].package.name, 'good');
    });
});
