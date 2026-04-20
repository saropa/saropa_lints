import '../register-vscode-mock';
import * as assert from 'assert';
import * as vscode from 'vscode';
import {
    DetailItem, buildGroupItems, buildDependencyGroup,
    PackageItem, InsightItem, OverrideItem, SeverityGroupItem,
    SourceCodeItem,
} from '../../../vibrancy/providers/tree-items';
import {
    ProblemItem, SuggestionItem,
} from '../../../vibrancy/providers/problem-tree-items';
import { VibrancyResult, GitHubMetrics, PubDevPackageInfo, PackageInsight, OverrideAnalysis } from '../../../vibrancy/types';

function makeResult(name: string, score: number): VibrancyResult {
    return {
        package: { name, version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: null, github: null, knownIssue: null, score,
        category: score >= 70 ? 'vibrant' : 'stable',
        resolutionVelocity: 0, engagementLevel: 0, popularity: 0,
        publisherTrust: 0, updateInfo: null, license: null,
        archiveSizeBytes: null, bloatRating: null, isUnused: false,
        fileUsages: [], platforms: null, verifiedPublisher: false, wasmReady: null,
        blocker: null, upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null, alternatives: [], latestPrerelease: null, prereleaseTag: null,
        vulnerabilities: [], versionGap: null, overrideGap: null,
        replacementComplexity: null, likes: null, downloadCount30Days: null,
        reverseDependencyCount: null, readme: null,
    };
}

function stubPubDev(repoUrl: string | null = null): PubDevPackageInfo {
    return {
        name: 'http', latestVersion: '2.0.0',
        publishedDate: '2025-01-01T00:00:00Z',
        repositoryUrl: repoUrl, isDiscontinued: false,
        isUnlisted: false, pubPoints: 100, publisher: null, license: null,
        description: null, topics: [], dependencies: [],
    };
}

const stubGithub: GitHubMetrics = {
    stars: 500, openIssues: 10, closedIssuesLast90d: 5,
    mergedPrsLast90d: 3, avgCommentsPerIssue: 2,
    daysSinceLastUpdate: 7, daysSinceLastClose: 3, flaggedIssues: [], license: null,
};

describe('DetailItem URL behavior', () => {
    it('should not set command when no URL provided', () => {
        const item = new DetailItem('Label', 'detail');
        assert.strictEqual(item.command, undefined);
        assert.strictEqual(item.tooltip, undefined);
        assert.strictEqual(item.contextValue, undefined);
        assert.strictEqual(item.url, undefined);
    });

    it('should wire up command, tooltip, and contextValue when URL provided', () => {
        const item = new DetailItem('Label', 'detail', 'https://example.com');
        assert.strictEqual(item.command?.command, 'saropaLints.packageVibrancy.openUrl');
        assert.deepStrictEqual(item.command?.arguments, ['https://example.com']);
        assert.strictEqual(item.tooltip, 'https://example.com');
        assert.strictEqual(item.contextValue, 'vibrancyDetailLink');
        assert.strictEqual(item.url, 'https://example.com');
    });

    it('should not set command when URL is undefined', () => {
        const item = new DetailItem('Label', 'detail', undefined);
        assert.strictEqual(item.command, undefined);
    });
});

describe('buildVersionGroup URLs', () => {
    it('should not link Version constraint', () => {
        const result = { ...makeResult('http', 80), pubDev: stubPubDev() };
        const versionItem = buildGroupItems(result)[0].children[0];
        assert.strictEqual(versionItem.label, 'Version');
        assert.strictEqual(versionItem.url, undefined);
    });

    it('should link Latest to pub.dev version page', () => {
        const result = { ...makeResult('http', 80), pubDev: stubPubDev() };
        const latestItem = buildGroupItems(result)[0].children[1];
        assert.strictEqual(latestItem.label, 'Latest');
        assert.strictEqual(latestItem.url, 'https://pub.dev/packages/http/versions/2.0.0');
    });

    it('should link Published to pub.dev version page', () => {
        const result = { ...makeResult('http', 80), pubDev: stubPubDev() };
        const publishedItem = buildGroupItems(result)[0].children[2];
        assert.strictEqual(publishedItem.label, 'Published');
        assert.strictEqual(publishedItem.url, 'https://pub.dev/packages/http/versions/2.0.0');
    });

    it('should not link when no pubDev data', () => {
        const groups = buildGroupItems(makeResult('http', 80));
        assert.strictEqual(groups[0].children.length, 1);
        assert.strictEqual(groups[0].children[0].url, undefined);
    });
});

describe('changelog entry URLs', () => {
    function makeWithChangelog(
        entries: { version: string; body: string }[],
        truncated = false,
    ): VibrancyResult {
        return {
            ...makeResult('shared_preferences', 50),
            updateInfo: {
                currentVersion: '1.0.0', latestVersion: '2.5.3',
                updateStatus: 'major',
                changelog: { entries, truncated },
            },
        };
    }

    it('should link changelog entry with version anchor (dots stripped)', () => {
        const result = makeWithChangelog([{ version: '2.5.3', body: 'Fixed a bug' }]);
        const update = buildGroupItems(result).find(g => g.label === '⬆️ Update')!;
        assert.strictEqual(
            update.children[1].url,
            'https://pub.dev/packages/shared_preferences/changelog#253',
        );
    });

    it('should handle multi-segment version anchors', () => {
        const result = makeWithChangelog([{ version: '10.2.34', body: 'Update' }]);
        const update = buildGroupItems(result).find(g => g.label === '⬆️ Update')!;
        assert.ok(update.children[1].url?.endsWith('#10234'));
    });

    it('should link truncation item to full changelog page', () => {
        const result = makeWithChangelog(
            [{ version: '2.0.0', body: 'Major update' }], true,
        );
        const update = buildGroupItems(result).find(g => g.label === '⬆️ Update')!;
        const last = update.children[update.children.length - 1];
        assert.strictEqual(last.label, '...');
        assert.strictEqual(
            last.url, 'https://pub.dev/packages/shared_preferences/changelog',
        );
    });

    it('should not link unavailable changelog reason', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 50),
            updateInfo: {
                currentVersion: '1.0.0', latestVersion: '2.0.0',
                updateStatus: 'major',
                changelog: { entries: [], truncated: false, unavailableReason: 'Rate limited' },
            },
        };
        const update = buildGroupItems(result).find(g => g.label === '⬆️ Update')!;
        const reason = update.children[update.children.length - 1];
        assert.strictEqual(reason.label, 'Changelog');
        assert.strictEqual(reason.url, undefined);
    });
});

describe('buildCommunityGroup URLs', () => {
    it('should link Stars and Open Issues to repository URLs', () => {
        const repoUrl = 'https://github.com/dart-lang/http';
        const result = {
            ...makeResult('http', 80),
            github: stubGithub,
            pubDev: stubPubDev(repoUrl),
        };
        const community = buildGroupItems(result).find(g => g.label === '📊 Community')!;
        assert.strictEqual(community.children[0].url, repoUrl);
        assert.strictEqual(community.children[1].url, `${repoUrl}/issues`);
    });

    it('should not link when no repositoryUrl', () => {
        const result = {
            ...makeResult('http', 80),
            github: stubGithub,
            pubDev: stubPubDev(null),
        };
        const community = buildGroupItems(result).find(g => g.label === '📊 Community')!;
        assert.strictEqual(community.children[0].url, undefined);
        assert.strictEqual(community.children[1].url, undefined);
    });

    it('should not link when no pubDev data at all', () => {
        const result = { ...makeResult('http', 80), github: stubGithub };
        const community = buildGroupItems(result).find(g => g.label === '📊 Community')!;
        assert.strictEqual(community.children[0].url, undefined);
        assert.strictEqual(community.children[1].url, undefined);
    });

    it('should strip trailing slash from repository URL', () => {
        const result = {
            ...makeResult('http', 80),
            github: stubGithub,
            pubDev: stubPubDev('https://github.com/dart-lang/http/'),
        };
        const community = buildGroupItems(result).find(g => g.label === '📊 Community')!;
        assert.strictEqual(
            community.children[1].url, 'https://github.com/dart-lang/http/issues',
        );
    });
});

describe('flagged issue URLs', () => {
    const flaggedGithub = {
        ...stubGithub,
        flaggedIssues: [{
            number: 42, title: 'Bug report',
            url: 'https://github.com/dart-lang/http/issues/42',
            matchedSignals: ['crash'], commentCount: 5,
        }],
    };

    it('should link individual issue items to their GitHub URLs', () => {
        const result = { ...makeResult('http', 50), github: flaggedGithub };
        const alerts = buildGroupItems(result).find(g => g.label === '🚨 Alerts')!;
        assert.strictEqual(
            alerts.children[1].url,
            'https://github.com/dart-lang/http/issues/42',
        );
    });

    it('should not link the flagged issues header', () => {
        const result = { ...makeResult('http', 50), github: flaggedGithub };
        const alerts = buildGroupItems(result).find(g => g.label === '🚨 Alerts')!;
        assert.strictEqual(alerts.children[0].url, undefined);
    });
});

describe('detail sync duck-typing contracts', () => {
    it('PackageItem exposes result for selection handler', () => {
        const result = makeResult('http', 80);
        const item = new PackageItem(result);
        assert.ok('result' in item);
        assert.strictEqual(item.result, result);
    });

    it('InsightItem exposes insight.name for selection handler', () => {
        const insight: PackageInsight = {
            name: 'http',
            combinedRiskScore: 5,
            vibrancyScore: 50,
            category: 'stable',
            problems: [],
            suggestedAction: null,
            actionType: 'none',
            unlocksIfFixed: [],
        };
        const item = new InsightItem(insight);
        assert.ok('insight' in item);
        assert.strictEqual(item.insight.name, 'http');
    });

    it('OverrideItem exposes analysis.entry.name for selection handler', () => {
        const analysis: OverrideAnalysis = {
            entry: { name: 'http', version: '1.0.0', line: 0, isPathDep: false, isGitDep: false },
            status: 'active',
            blocker: null,
            addedDate: null,
            ageDays: null,
        };
        const item = new OverrideItem(analysis);
        assert.ok('analysis' in item);
        assert.strictEqual(item.analysis.entry.name, 'http');
    });

    it('ProblemItem exposes packageName for selection handler', () => {
        const item = new ProblemItem(
            {
                type: 'unused', id: 'http:unused', package: 'http',
                severity: 'low', line: 0,
            },
            'http',
        );
        assert.ok('packageName' in item);
        assert.strictEqual(item.packageName, 'http');
    });

    it('SuggestionItem exposes packageName for selection handler', () => {
        const item = new SuggestionItem(
            {
                type: 'remove', description: 'Remove this package',
                targetPackages: ['http'], resolvesProblemIds: [], priority: 80,
            },
            [],
            'http',
        );
        assert.ok('packageName' in item);
        assert.strictEqual(item.packageName, 'http');
    });

});

describe('SeverityGroupItem', () => {
    it('should use high label for high severity', () => {
        const item = new SeverityGroupItem('high', []);
        assert.strictEqual(item.label, '🔴 High [0]');
    });

    it('should use medium label for medium severity', () => {
        const item = new SeverityGroupItem('medium', []);
        assert.strictEqual(item.label, '🟡 Medium [0]');
    });

    it('should use low label for low severity', () => {
        const item = new SeverityGroupItem('low', []);
        assert.strictEqual(item.label, '🟢 Low [0]');
    });

    it('should use healthy label for healthy severity', () => {
        const item = new SeverityGroupItem('healthy', []);
        assert.strictEqual(item.label, '✅ Healthy [0]');
    });

    it('should be expanded for high severity', () => {
        const item = new SeverityGroupItem('high', []);
        assert.strictEqual(item.collapsibleState, vscode.TreeItemCollapsibleState.Expanded);
    });

    it('should be expanded for medium severity', () => {
        const item = new SeverityGroupItem('medium', []);
        assert.strictEqual(item.collapsibleState, vscode.TreeItemCollapsibleState.Expanded);
    });

    it('should be collapsed for low severity', () => {
        const item = new SeverityGroupItem('low', []);
        assert.strictEqual(item.collapsibleState, vscode.TreeItemCollapsibleState.Collapsed);
    });

    it('should be collapsed for healthy severity', () => {
        const item = new SeverityGroupItem('healthy', []);
        assert.strictEqual(item.collapsibleState, vscode.TreeItemCollapsibleState.Collapsed);
    });

    it('should reflect result count in label', () => {
        const results = [makeResult('a', 80), makeResult('b', 80)];
        const item = new SeverityGroupItem('healthy', results);
        assert.strictEqual(item.label, '✅ Healthy [2]');
    });

    it('should set contextValue to vibrancySeverityGroup', () => {
        const item = new SeverityGroupItem('high', []);
        assert.strictEqual(item.contextValue, 'vibrancySeverityGroup');
    });
});

describe('PackageItem description format', () => {
    it('should show category label in parentheses for vibrant package', () => {
        const result = makeResult('http', 80);
        const item = new PackageItem(result);
        assert.strictEqual(item.description, '(Vibrant)');
    });

    it('should show category label in parentheses for stable package', () => {
        const result = makeResult('http', 50);
        const item = new PackageItem(result);
        // makeResult uses score >= 70 => vibrant, else stable
        assert.strictEqual(item.description, '(Stable)');
    });

    it('should append update arrow when update available', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            updateInfo: {
                currentVersion: '1.0.0', latestVersion: '2.0.0',
                updateStatus: 'major', changelog: null,
            },
        };
        const item = new PackageItem(result);
        assert.strictEqual(item.description, '(Vibrant) → 2.0.0');
    });

    it('should not append update arrow when up-to-date', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            updateInfo: {
                currentVersion: '1.0.0', latestVersion: '1.0.0',
                updateStatus: 'up-to-date', changelog: null,
            },
        };
        const item = new PackageItem(result);
        assert.strictEqual(item.description, '(Vibrant)');
    });
});

describe('SourceCodeItem', () => {
    it('should set label with emoji prefix and Source Code', () => {
        const item = new SourceCodeItem('🟢', '50 lines, 2 files', 'full summary', 'http');
        assert.strictEqual(item.label, '🟢 Source Code');
    });

    it('should set short description and full tooltip', () => {
        const item = new SourceCodeItem('🟢', '50 lines, 2 files', 'full summary text', 'http');
        assert.strictEqual(item.description, '50 lines, 2 files');
        assert.strictEqual(item.tooltip, 'full summary text');
    });

    it('should wire command to openSourceFolder', () => {
        const item = new SourceCodeItem('🟢', 'desc', 'tip', 'http');
        assert.strictEqual(item.command?.command, 'saropaLints.packageVibrancy.openSourceFolder');
        assert.deepStrictEqual(item.command?.arguments, ['http']);
    });

    it('should set contextValue to vibrancySourceCode', () => {
        const item = new SourceCodeItem('🟢', 'desc', 'tip', 'http');
        assert.strictEqual(item.contextValue, 'vibrancySourceCode');
    });
});

describe('PackageItem shared% indicator', () => {
    it('should append shared% when transitives have shared deps', () => {
        const result: VibrancyResult = {
            ...makeResult('crop_your_image', 50),
            transitiveInfo: {
                directDep: 'crop_your_image',
                transitiveCount: 12,
                flaggedCount: 0,
                transitives: Array.from({ length: 12 }, (_, i) => `dep_${i}`),
                sharedDeps: Array.from({ length: 9 }, (_, i) => `dep_${i}`),
            },
        };
        const item = new PackageItem(result);
        // 9/12 = 75% shared
        assert.strictEqual(item.description, '(Stable) 75% shared');
    });

    it('should not append shared% when no shared deps', () => {
        const result: VibrancyResult = {
            ...makeResult('unique_pkg', 50),
            transitiveInfo: {
                directDep: 'unique_pkg',
                transitiveCount: 5,
                flaggedCount: 0,
                transitives: ['a', 'b', 'c', 'd', 'e'],
                sharedDeps: [],
            },
        };
        const item = new PackageItem(result);
        assert.strictEqual(item.description, '(Stable)');
    });

    it('should not append shared% when no transitive info', () => {
        const result = makeResult('simple_pkg', 80);
        const item = new PackageItem(result);
        assert.strictEqual(item.description, '(Vibrant)');
    });

    it('should show shared% before update arrow', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            transitiveInfo: {
                directDep: 'http',
                transitiveCount: 4,
                flaggedCount: 0,
                transitives: ['a', 'b', 'c', 'd'],
                sharedDeps: ['a', 'b'],
            },
            updateInfo: {
                currentVersion: '1.0.0', latestVersion: '2.0.0',
                updateStatus: 'major', changelog: null,
            },
        };
        const item = new PackageItem(result);
        // 2/4 = 50% shared, then update arrow
        assert.strictEqual(item.description, '(Vibrant) 50% shared → 2.0.0');
    });
});

describe('buildDependencyGroup unique/shared split', () => {
    it('should return null when no transitive info', () => {
        const result = makeResult('http', 80);
        assert.strictEqual(buildDependencyGroup(result), null);
    });

    it('should return null when transitive count is zero', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            transitiveInfo: {
                directDep: 'http',
                transitiveCount: 0,
                flaggedCount: 0,
                transitives: [],
                sharedDeps: [],
            },
        };
        assert.strictEqual(buildDependencyGroup(result), null);
    });

    it('should show only total when no shared deps', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80),
            transitiveInfo: {
                directDep: 'http',
                transitiveCount: 5,
                flaggedCount: 0,
                transitives: ['a', 'b', 'c', 'd', 'e'],
                sharedDeps: [],
            },
        };
        const group = buildDependencyGroup(result)!;
        assert.strictEqual(group.label, '📊 Dependencies');
        // Only the Transitive row, no Unique/Shared rows
        assert.strictEqual(group.children.length, 1);
        assert.strictEqual(group.children[0].description, '5 packages');
    });

    it('should show unique and shared rows when shared deps exist', () => {
        const result: VibrancyResult = {
            ...makeResult('crop_your_image', 50),
            transitiveInfo: {
                directDep: 'crop_your_image',
                transitiveCount: 12,
                flaggedCount: 0,
                transitives: Array.from({ length: 12 }, (_, i) => `dep_${i}`),
                sharedDeps: ['image', 'meta', 'collection'],
            },
        };
        const group = buildDependencyGroup(result)!;
        // Transitive + Unique + Shared = 3 rows
        assert.strictEqual(group.children.length, 3);
        assert.strictEqual(group.children[0].description, '12 packages');
        assert.strictEqual(group.children[1].label, '🆕 Unique');
        assert.strictEqual(group.children[1].description, '9 packages (added by this dep only)');
        assert.strictEqual(group.children[2].label, '🔗 Shared');
        assert.ok((group.children[2].description as string).startsWith('3 packages'));
    });

    it('should show flagged suffix on total', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 50),
            transitiveInfo: {
                directDep: 'http',
                transitiveCount: 8,
                flaggedCount: 2,
                transitives: Array.from({ length: 8 }, (_, i) => `dep_${i}`),
                sharedDeps: [],
            },
        };
        const group = buildDependencyGroup(result)!;
        assert.strictEqual(group.children[0].description, '8 packages (2 flagged)');
    });

    it('should truncate shared deps list to 3 with overflow count', () => {
        const result: VibrancyResult = {
            ...makeResult('big_pkg', 50),
            transitiveInfo: {
                directDep: 'big_pkg',
                transitiveCount: 10,
                flaggedCount: 0,
                transitives: Array.from({ length: 10 }, (_, i) => `dep_${i}`),
                sharedDeps: ['a', 'b', 'c', 'd', 'e'],
            },
        };
        const group = buildDependencyGroup(result)!;
        const sharedDesc = group.children[2].description as string;
        assert.ok(sharedDesc.includes('a, b, c'));
        assert.ok(sharedDesc.includes('+2'));
    });
});
