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
exports.buildTriageData = buildTriageData;
exports.getTriageGroupChildren = getTriageGroupChildren;
exports.renderTreeItem = renderTreeItem;
/** I1/I2: Triage node types and data computation for the Config view. */
const vscode = __importStar(require("vscode"));
const triageUtils_1 = require("../triageUtils");
const healthScore_1 = require("../healthScore");
const configWriter_1 = require("../configWriter");
/** Compute all triage groups from violations data. */
function buildTriageData(data, root) {
    const issuesByRule = data.summary?.issuesByRule;
    if (!issuesByRule)
        return null;
    const violations = data.violations ?? [];
    const impactMap = (0, triageUtils_1.buildRuleImpactMap)(violations);
    // Critical rules — have at least one critical-impact violation.
    const criticalRules = (0, triageUtils_1.identifyCriticalRules)(impactMap, issuesByRule);
    const criticalRuleNames = new Set(criticalRules.map((r) => r.ruleName));
    // Filter critical rules OUT of the volume grouping to avoid double-counting.
    const nonCriticalIssues = {};
    for (const [rule, count] of Object.entries(issuesByRule)) {
        if (!criticalRuleNames.has(rule))
            nonCriticalIssues[rule] = count;
    }
    // Also filter stylistic rules out of volume grouping.
    const stylisticNames = new Set(data.config?.stylisticRuleNames ?? []);
    const volumeIssues = {};
    const stylisticIssues = {};
    for (const [rule, count] of Object.entries(nonCriticalIssues)) {
        if (stylisticNames.has(rule)) {
            stylisticIssues[rule] = count;
        }
        else {
            volumeIssues[rule] = count;
        }
    }
    const volumeGroups = (0, triageUtils_1.groupRulesByVolume)(volumeIssues);
    // Build group nodes with score estimates.
    const criticalGroup = criticalRules.length > 0
        ? buildGroupNode('critical', 'Critical rules', criticalRules.map((r) => r.ruleName), criticalRules.reduce((s, r) => s + r.issueCount, 0), data, impactMap)
        : null;
    const volumeNodes = volumeGroups.map((g) => buildGroupNode(g.id, `Group ${g.id}: ${g.label}`, g.rules, g.totalIssues, data, impactMap));
    // Stylistic group.
    const { stylistic } = (0, triageUtils_1.partitionStylistic)(Object.keys(stylisticIssues), data.config?.stylisticRuleNames);
    const stylisticTotal = stylistic.reduce((s, r) => s + (issuesByRule[r] ?? 0), 0);
    const stylisticGroup = stylistic.length > 0
        ? buildGroupNode('stylistic', 'Stylistic (opt-in)', stylistic, stylisticTotal, data, impactMap)
        : null;
    // Zero-issue count.
    const enabledRuleNames = data.config?.enabledRuleNames ?? [];
    const zeroCount = (0, triageUtils_1.getZeroIssueCount)(enabledRuleNames, issuesByRule);
    // I2: Count rules explicitly disabled by user overrides.
    const disabledCount = root ? (0, configWriter_1.countDisabledOverrides)(root) : 0;
    return {
        criticalGroup,
        volumeGroups: volumeNodes,
        zeroIssueCount: zeroCount,
        disabledOverrideCount: disabledCount,
        stylisticGroup,
        issuesByRule,
    };
}
function buildGroupNode(id, label, rules, totalIssues, data, impactMap) {
    const estimate = (0, healthScore_1.estimateScoreForRuleRemoval)(data, impactMap, rules);
    const desc = formatGroupDescription(rules.length, totalIssues, estimate);
    return { kind: 'triageGroup', groupId: id, label, description: desc, rules, totalIssues };
}
function formatGroupDescription(ruleCount, totalIssues, estimate) {
    const parts = [];
    parts.push(`${ruleCount} rule${ruleCount === 1 ? '' : 's'}`);
    parts.push(`${totalIssues} issue${totalIssues === 1 ? '' : 's'}`);
    if (estimate && estimate.delta > 0) {
        parts.push(`est. +${estimate.delta} pts`);
    }
    return parts.join(', ');
}
/** Build child rule nodes for a triage group. */
function getTriageGroupChildren(group, issuesByRule) {
    return group.rules
        .map((rule) => ({
        kind: 'triageRule',
        ruleName: rule,
        issueCount: issuesByRule[rule] ?? 0,
    }))
        .sort((a, b) => b.issueCount - a.issueCount);
}
/** Convert a ConfigTreeNode to a VS Code TreeItem for rendering. */
function renderTreeItem(node) {
    switch (node.kind) {
        case 'configSetting': {
            const item = new vscode.TreeItem(node.label, vscode.TreeItemCollapsibleState.None);
            item.description = node.description;
            if (node.commandId)
                item.command = { command: node.commandId, title: node.label, arguments: [] };
            // contextValue enables context menu actions (e.g. "Copy as JSON").
            item.contextValue = 'configSetting';
            return item;
        }
        case 'triageGroup':
            return renderGroupItem(node);
        case 'triageRule': {
            const item = new vscode.TreeItem(node.ruleName, vscode.TreeItemCollapsibleState.None);
            item.description = `${node.issueCount}`;
            item.command = { command: 'saropaLints.focusIssuesForRules', title: 'Show in Issues', arguments: [[node.ruleName]] };
            item.contextValue = 'triageRule';
            item.iconPath = new vscode.ThemeIcon('circle-outline');
            return item;
        }
        case 'triageInfo': {
            const item = new vscode.TreeItem(node.label, vscode.TreeItemCollapsibleState.None);
            item.description = node.description;
            item.iconPath = new vscode.ThemeIcon('pass', new vscode.ThemeColor('testing.iconPassed'));
            // contextValue enables context menu actions (e.g. "Copy as JSON").
            item.contextValue = 'triageInfo';
            return item;
        }
    }
}
function renderGroupItem(node) {
    const item = new vscode.TreeItem(node.label, vscode.TreeItemCollapsibleState.Collapsed);
    item.description = node.description;
    item.command = { command: 'saropaLints.focusIssuesForRules', title: 'Show in Issues', arguments: [node.rules] };
    item.contextValue = 'triageGroup';
    const icon = node.groupId === 'critical' ? 'flame'
        : node.groupId === 'stylistic' ? 'paintcan' : 'tag';
    const color = node.groupId === 'critical' ? new vscode.ThemeColor('list.errorForeground') : undefined;
    item.iconPath = new vscode.ThemeIcon(icon, color);
    return item;
}
//# sourceMappingURL=triageTree.js.map