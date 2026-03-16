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
exports.BudgetItem = exports.BudgetGroupItem = exports.InsightItem = exports.ActionItemsGroupItem = exports.OverrideItem = exports.OverridesGroupItem = exports.DepGraphSummaryItem = exports.GroupItem = exports.PrereleaseItem = exports.DetailItem = exports.SuppressedPackageItem = exports.SectionGroupItem = exports.SuppressedGroupItem = exports.PackageItem = exports.SECTION_LABELS = void 0;
exports.categoryColor = categoryColor;
exports.severityIcon = severityIcon;
exports.severityColor = severityColor;
const vscode = __importStar(require("vscode"));
const status_classifier_1 = require("../scoring/status-classifier");
const prerelease_classifier_1 = require("../scoring/prerelease-classifier");
/**
 * Tree item class definitions.
 * Extracted from tree-items.ts for modularity.
 */
exports.SECTION_LABELS = {
    dependencies: 'Dependencies',
    dev_dependencies: 'Dev Dependencies',
    transitive: 'Transitive',
};
const SECTION_ICONS = {
    dependencies: 'package',
    dev_dependencies: 'tools',
    transitive: 'references',
};
function categoryColor(cat) {
    switch (cat) {
        case 'vibrant': return new vscode.ThemeColor('testing.iconPassed');
        case 'quiet': return new vscode.ThemeColor('editorInfo.foreground');
        case 'legacy-locked': return new vscode.ThemeColor('editorWarning.foreground');
        case 'stale': return new vscode.ThemeColor('editorWarning.foreground');
        case 'end-of-life': return new vscode.ThemeColor('editorError.foreground');
    }
}
function severityIcon(severity) {
    switch (severity) {
        case 'high': return 'error';
        case 'medium': return 'warning';
        case 'low': return 'info';
    }
}
function severityColor(severity) {
    switch (severity) {
        case 'high': return new vscode.ThemeColor('editorError.foreground');
        case 'medium': return new vscode.ThemeColor('editorWarning.foreground');
        case 'low': return new vscode.ThemeColor('editorInfo.foreground');
    }
}
class PackageItem extends vscode.TreeItem {
    result;
    constructor(result, problemCount) {
        super(result.package.name, vscode.TreeItemCollapsibleState.Collapsed);
        this.result = result;
        const hasUpdate = result.updateInfo?.updateStatus
            && result.updateInfo.updateStatus !== 'up-to-date';
        const displayScore = Math.round(result.score / 10);
        let desc = `${displayScore}/10 — ${(0, status_classifier_1.categoryLabel)(result.category)}`;
        if (hasUpdate) {
            desc += ` → ${result.updateInfo.latestVersion}`;
        }
        if (problemCount && problemCount > 0) {
            desc += ` — ${problemCount} problem${problemCount === 1 ? '' : 's'}`;
        }
        this.description = desc;
        this.iconPath = new vscode.ThemeIcon((0, status_classifier_1.categoryIcon)(result.category), categoryColor(result.category));
        const base = result.isUnused
            ? 'vibrancyPackageUnused' : 'vibrancyPackage';
        this.contextValue = hasUpdate ? base + 'Updatable' : base;
        this.command = {
            command: 'saropaLints.packageVibrancy.goToPackage',
            title: 'Go to pubspec.yaml',
            arguments: [result.package.name],
        };
    }
}
exports.PackageItem = PackageItem;
class SuppressedGroupItem extends vscode.TreeItem {
    constructor(count) {
        super(`Suppressed (${count})`, vscode.TreeItemCollapsibleState.Collapsed);
        this.iconPath = new vscode.ThemeIcon('eye-closed', new vscode.ThemeColor('disabledForeground'));
        this.contextValue = 'vibrancySuppressedGroup';
    }
}
exports.SuppressedGroupItem = SuppressedGroupItem;
class SectionGroupItem extends vscode.TreeItem {
    section;
    results;
    constructor(section, results) {
        const label = exports.SECTION_LABELS[section];
        const count = results.length;
        super(`${label} (${count})`, vscode.TreeItemCollapsibleState.Expanded);
        this.section = section;
        this.results = results;
        this.iconPath = new vscode.ThemeIcon(SECTION_ICONS[section]);
        this.contextValue = 'vibrancySectionGroup';
    }
}
exports.SectionGroupItem = SectionGroupItem;
class SuppressedPackageItem extends PackageItem {
    constructor(result) {
        super(result);
        this.iconPath = new vscode.ThemeIcon('eye-closed', new vscode.ThemeColor('disabledForeground'));
        const hasUpdate = result.updateInfo?.updateStatus
            && result.updateInfo.updateStatus !== 'up-to-date';
        this.contextValue = hasUpdate
            ? 'vibrancyPackageSuppressedUpdatable'
            : 'vibrancyPackageSuppressed';
    }
}
exports.SuppressedPackageItem = SuppressedPackageItem;
class DetailItem extends vscode.TreeItem {
    url;
    constructor(label, detail, url) {
        super(label, vscode.TreeItemCollapsibleState.None);
        this.description = detail;
        if (url) {
            this.url = url;
            this.command = {
                command: 'saropaLints.packageVibrancy.openUrl',
                title: 'Open Link',
                arguments: [url],
            };
            this.tooltip = url;
            this.contextValue = 'vibrancyDetailLink';
        }
    }
}
exports.DetailItem = DetailItem;
class PrereleaseItem extends vscode.TreeItem {
    packageName;
    prereleaseVersion;
    prereleaseTag;
    constructor(packageName, prereleaseVersion, prereleaseTag) {
        const tag = (0, prerelease_classifier_1.formatPrereleaseTag)(prereleaseTag);
        super(`🧪 Prerelease: ${prereleaseVersion}`, vscode.TreeItemCollapsibleState.None);
        this.packageName = packageName;
        this.prereleaseVersion = prereleaseVersion;
        this.prereleaseTag = prereleaseTag;
        this.description = tag;
        this.iconPath = new vscode.ThemeIcon('beaker', new vscode.ThemeColor('editorInfo.foreground'));
        this.tooltip = `Update to prerelease version ${prereleaseVersion} (${tag})`;
        this.contextValue = 'vibrancyPrerelease';
        this.command = {
            command: 'saropaLints.packageVibrancy.updateToPrerelease',
            title: 'Update to Prerelease',
            arguments: [packageName, prereleaseVersion],
        };
    }
}
exports.PrereleaseItem = PrereleaseItem;
class GroupItem extends vscode.TreeItem {
    children;
    constructor(label, children) {
        super(label, vscode.TreeItemCollapsibleState.Expanded);
        this.children = children;
    }
}
exports.GroupItem = GroupItem;
class DepGraphSummaryItem extends vscode.TreeItem {
    summary;
    constructor(summary) {
        super('Dependency Graph', vscode.TreeItemCollapsibleState.Collapsed);
        this.summary = summary;
        this.iconPath = new vscode.ThemeIcon('graph');
        this.contextValue = 'vibrancyDepGraphSummary';
    }
}
exports.DepGraphSummaryItem = DepGraphSummaryItem;
class OverridesGroupItem extends vscode.TreeItem {
    analyses;
    constructor(analyses) {
        super(`Overrides (${analyses.length})`, vscode.TreeItemCollapsibleState.Expanded);
        this.analyses = analyses;
        const staleCount = analyses.filter(a => a.status === 'stale').length;
        this.iconPath = new vscode.ThemeIcon('wrench', staleCount > 0
            ? new vscode.ThemeColor('editorWarning.foreground')
            : new vscode.ThemeColor('editorInfo.foreground'));
        this.tooltip = staleCount > 0
            ? `${staleCount} override(s) with no version conflict detected.`
            : 'Dependency overrides in pubspec.yaml.';
        this.contextValue = 'vibrancyOverridesGroup';
    }
}
exports.OverridesGroupItem = OverridesGroupItem;
class OverrideItem extends vscode.TreeItem {
    analysis;
    constructor(analysis) {
        super(`${analysis.entry.name}: ${analysis.entry.version}`, vscode.TreeItemCollapsibleState.Collapsed);
        this.analysis = analysis;
        this.description = analysis.status === 'stale' ? '⚠️ Stale' : '';
        this.iconPath = new vscode.ThemeIcon(analysis.status === 'stale' ? 'warning' : 'wrench', analysis.status === 'stale'
            ? new vscode.ThemeColor('editorWarning.foreground')
            : new vscode.ThemeColor('editorInfo.foreground'));
        this.tooltip = analysis.status === 'stale'
            ? 'No version conflict detected — review this override.'
            : `Active override — ${analysis.blocker ?? 'resolves a conflict'}.`;
        this.contextValue = analysis.status === 'stale'
            ? 'vibrancyOverrideStale'
            : 'vibrancyOverrideActive';
        this.command = {
            command: 'saropaLints.packageVibrancy.goToOverride',
            title: 'Go to override in pubspec.yaml',
            arguments: [analysis.entry.name],
        };
    }
}
exports.OverrideItem = OverrideItem;
class ActionItemsGroupItem extends vscode.TreeItem {
    insights;
    constructor(insights) {
        super(`Action Items (${insights.length})`, vscode.TreeItemCollapsibleState.Expanded);
        this.insights = insights;
        this.iconPath = new vscode.ThemeIcon('target', new vscode.ThemeColor('editorWarning.foreground'));
        this.tooltip = `${insights.length} package(s) need attention. Sorted by risk.`;
        this.contextValue = 'vibrancyActionItemsGroup';
    }
}
exports.ActionItemsGroupItem = ActionItemsGroupItem;
class InsightItem extends vscode.TreeItem {
    insight;
    constructor(insight) {
        const problemCount = insight.problems.length;
        super(insight.name, vscode.TreeItemCollapsibleState.Collapsed);
        this.insight = insight;
        this.description = `${insight.combinedRiskScore} risk — ${problemCount} problem(s)`;
        const highestSeverity = insight.problems.reduce((max, p) => {
            if (p.severity === 'high') {
                return 'high';
            }
            if (p.severity === 'medium' && max !== 'high') {
                return 'medium';
            }
            return max;
        }, 'low');
        this.iconPath = new vscode.ThemeIcon(severityIcon(highestSeverity), severityColor(highestSeverity));
        this.tooltip = insight.suggestedAction ?? `${problemCount} problem(s) detected`;
        this.contextValue = 'vibrancyInsight';
        this.command = {
            command: 'saropaLints.packageVibrancy.goToPackage',
            title: 'Go to pubspec.yaml',
            arguments: [insight.name],
        };
    }
}
exports.InsightItem = InsightItem;
// Re-export budget classes from their own module so existing callers
// that import from this file continue to work without changes.
var tree_item_budget_classes_1 = require("./tree-item-budget-classes");
Object.defineProperty(exports, "BudgetGroupItem", { enumerable: true, get: function () { return tree_item_budget_classes_1.BudgetGroupItem; } });
Object.defineProperty(exports, "BudgetItem", { enumerable: true, get: function () { return tree_item_budget_classes_1.BudgetItem; } });
//# sourceMappingURL=tree-item-classes.js.map