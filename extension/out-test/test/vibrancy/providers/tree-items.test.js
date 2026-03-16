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
const tree_items_1 = require("../../../vibrancy/providers/tree-items");
const problem_tree_items_1 = require("../../../vibrancy/providers/problem-tree-items");
function makeResult(name, score) {
    return {
        package: { name, version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: null, github: null, knownIssue: null, score,
        category: score >= 70 ? 'vibrant' : 'quiet',
        resolutionVelocity: 0, engagementLevel: 0, popularity: 0,
        publisherTrust: 0, updateInfo: null,
        archiveSizeBytes: null, bloatRating: null, license: null, drift: null, isUnused: false, platforms: null, verifiedPublisher: false, wasmReady: null, blocker: null, upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null, alternatives: [], latestPrerelease: null, prereleaseTag: null,
        vulnerabilities: [],
    };
}
function stubPubDev(repoUrl = null) {
    return {
        name: 'http', latestVersion: '2.0.0',
        publishedDate: '2025-01-01T00:00:00Z',
        repositoryUrl: repoUrl, isDiscontinued: false,
        isUnlisted: false, pubPoints: 100, publisher: null, license: null,
        description: null, topics: [],
    };
}
const stubGithub = {
    stars: 500, openIssues: 10, closedIssuesLast90d: 5,
    mergedPrsLast90d: 3, avgCommentsPerIssue: 2,
    daysSinceLastUpdate: 7, daysSinceLastClose: 3, flaggedIssues: [], license: null,
};
describe('DetailItem URL behavior', () => {
    it('should not set command when no URL provided', () => {
        const item = new tree_items_1.DetailItem('Label', 'detail');
        assert.strictEqual(item.command, undefined);
        assert.strictEqual(item.tooltip, undefined);
        assert.strictEqual(item.contextValue, undefined);
        assert.strictEqual(item.url, undefined);
    });
    it('should wire up command, tooltip, and contextValue when URL provided', () => {
        const item = new tree_items_1.DetailItem('Label', 'detail', 'https://example.com');
        assert.strictEqual(item.command?.command, 'saropaLints.packageVibrancy.openUrl');
        assert.deepStrictEqual(item.command?.arguments, ['https://example.com']);
        assert.strictEqual(item.tooltip, 'https://example.com');
        assert.strictEqual(item.contextValue, 'vibrancyDetailLink');
        assert.strictEqual(item.url, 'https://example.com');
    });
    it('should not set command when URL is undefined', () => {
        const item = new tree_items_1.DetailItem('Label', 'detail', undefined);
        assert.strictEqual(item.command, undefined);
    });
});
describe('buildVersionGroup URLs', () => {
    it('should not link Version constraint', () => {
        const result = { ...makeResult('http', 80), pubDev: stubPubDev() };
        const versionItem = (0, tree_items_1.buildGroupItems)(result)[0].children[0];
        assert.strictEqual(versionItem.label, 'Version');
        assert.strictEqual(versionItem.url, undefined);
    });
    it('should link Latest to pub.dev version page', () => {
        const result = { ...makeResult('http', 80), pubDev: stubPubDev() };
        const latestItem = (0, tree_items_1.buildGroupItems)(result)[0].children[1];
        assert.strictEqual(latestItem.label, 'Latest');
        assert.strictEqual(latestItem.url, 'https://pub.dev/packages/http/versions/2.0.0');
    });
    it('should link Published to pub.dev version page', () => {
        const result = { ...makeResult('http', 80), pubDev: stubPubDev() };
        const publishedItem = (0, tree_items_1.buildGroupItems)(result)[0].children[2];
        assert.strictEqual(publishedItem.label, 'Published');
        assert.strictEqual(publishedItem.url, 'https://pub.dev/packages/http/versions/2.0.0');
    });
    it('should not link when no pubDev data', () => {
        const groups = (0, tree_items_1.buildGroupItems)(makeResult('http', 80));
        assert.strictEqual(groups[0].children.length, 1);
        assert.strictEqual(groups[0].children[0].url, undefined);
    });
});
describe('changelog entry URLs', () => {
    function makeWithChangelog(entries, truncated = false) {
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
        const update = (0, tree_items_1.buildGroupItems)(result).find(g => g.label === '⬆️ Update');
        assert.strictEqual(update.children[1].url, 'https://pub.dev/packages/shared_preferences/changelog#253');
    });
    it('should handle multi-segment version anchors', () => {
        const result = makeWithChangelog([{ version: '10.2.34', body: 'Update' }]);
        const update = (0, tree_items_1.buildGroupItems)(result).find(g => g.label === '⬆️ Update');
        assert.ok(update.children[1].url?.endsWith('#10234'));
    });
    it('should link truncation item to full changelog page', () => {
        const result = makeWithChangelog([{ version: '2.0.0', body: 'Major update' }], true);
        const update = (0, tree_items_1.buildGroupItems)(result).find(g => g.label === '⬆️ Update');
        const last = update.children[update.children.length - 1];
        assert.strictEqual(last.label, '...');
        assert.strictEqual(last.url, 'https://pub.dev/packages/shared_preferences/changelog');
    });
    it('should not link unavailable changelog reason', () => {
        const result = {
            ...makeResult('http', 50),
            updateInfo: {
                currentVersion: '1.0.0', latestVersion: '2.0.0',
                updateStatus: 'major',
                changelog: { entries: [], truncated: false, unavailableReason: 'Rate limited' },
            },
        };
        const update = (0, tree_items_1.buildGroupItems)(result).find(g => g.label === '⬆️ Update');
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
        const community = (0, tree_items_1.buildGroupItems)(result).find(g => g.label === '📊 Community');
        assert.strictEqual(community.children[0].url, repoUrl);
        assert.strictEqual(community.children[1].url, `${repoUrl}/issues`);
    });
    it('should not link when no repositoryUrl', () => {
        const result = {
            ...makeResult('http', 80),
            github: stubGithub,
            pubDev: stubPubDev(null),
        };
        const community = (0, tree_items_1.buildGroupItems)(result).find(g => g.label === '📊 Community');
        assert.strictEqual(community.children[0].url, undefined);
        assert.strictEqual(community.children[1].url, undefined);
    });
    it('should not link when no pubDev data at all', () => {
        const result = { ...makeResult('http', 80), github: stubGithub };
        const community = (0, tree_items_1.buildGroupItems)(result).find(g => g.label === '📊 Community');
        assert.strictEqual(community.children[0].url, undefined);
        assert.strictEqual(community.children[1].url, undefined);
    });
    it('should strip trailing slash from repository URL', () => {
        const result = {
            ...makeResult('http', 80),
            github: stubGithub,
            pubDev: stubPubDev('https://github.com/dart-lang/http/'),
        };
        const community = (0, tree_items_1.buildGroupItems)(result).find(g => g.label === '📊 Community');
        assert.strictEqual(community.children[1].url, 'https://github.com/dart-lang/http/issues');
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
        const alerts = (0, tree_items_1.buildGroupItems)(result).find(g => g.label === '🚨 Alerts');
        assert.strictEqual(alerts.children[1].url, 'https://github.com/dart-lang/http/issues/42');
    });
    it('should not link the flagged issues header', () => {
        const result = { ...makeResult('http', 50), github: flaggedGithub };
        const alerts = (0, tree_items_1.buildGroupItems)(result).find(g => g.label === '🚨 Alerts');
        assert.strictEqual(alerts.children[0].url, undefined);
    });
});
describe('detail sync duck-typing contracts', () => {
    it('PackageItem exposes result for selection handler', () => {
        const result = makeResult('http', 80);
        const item = new tree_items_1.PackageItem(result);
        assert.ok('result' in item);
        assert.strictEqual(item.result, result);
    });
    it('InsightItem exposes insight.name for selection handler', () => {
        const insight = {
            name: 'http',
            combinedRiskScore: 5,
            problems: [],
            suggestedAction: null,
            actionType: 'none',
            unlocksIfFixed: [],
        };
        const item = new tree_items_1.InsightItem(insight);
        assert.ok('insight' in item);
        assert.strictEqual(item.insight.name, 'http');
    });
    it('OverrideItem exposes analysis.entry.name for selection handler', () => {
        const analysis = {
            entry: { name: 'http', version: '1.0.0', line: 0, isPathDep: false, isGitDep: false },
            status: 'active',
            blocker: null,
            addedDate: null,
            ageDays: null,
        };
        const item = new tree_items_1.OverrideItem(analysis);
        assert.ok('analysis' in item);
        assert.strictEqual(item.analysis.entry.name, 'http');
    });
    it('ProblemItem exposes packageName for selection handler', () => {
        const item = new problem_tree_items_1.ProblemItem({
            type: 'unused', id: 'http:unused', package: 'http',
            severity: 'low', line: 0,
        }, 'http');
        assert.ok('packageName' in item);
        assert.strictEqual(item.packageName, 'http');
    });
    it('SuggestionItem exposes packageName for selection handler', () => {
        const item = new problem_tree_items_1.SuggestionItem({
            type: 'remove', description: 'Remove this package',
            targetPackages: ['http'], resolvesProblemIds: [], priority: 80,
        }, [], 'http');
        assert.ok('packageName' in item);
        assert.strictEqual(item.packageName, 'http');
    });
});
//# sourceMappingURL=tree-items.test.js.map