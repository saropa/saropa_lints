"use strict";
/**
 * Tree data provider for Saropa Lints Issues view.
 * Structure: Severity (Error, Warning, Info) → folder path tree → file → violations (capped).
 * Supports text/type filters and suppressions (hide folder, file, rule). Scale-safe for 65k+ issues.
 */
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
exports.IssuesTreeProvider = void 0;
exports.registerIssueCommands = registerIssueCommands;
const vscode = __importStar(require("vscode"));
const path = __importStar(require("path"));
const pathUtils_1 = require("../pathUtils");
const ruleMetadata_1 = require("../ruleMetadata");
const violationsReader_1 = require("../violationsReader");
const healthScore_1 = require("../healthScore");
const reportWriter_1 = require("../reportWriter");
const suppressionsStore_1 = require("../suppressionsStore");
const securityPostureTree_1 = require("./securityPostureTree");
const projectRoot_1 = require("../projectRoot");
const SEVERITY_ORDER = ['error', 'warning', 'info'];
const DEFAULT_PAGE_SIZE = 100;
const MESSAGE_LABEL_LEN = 56;
/** Map a severity string to a colored ThemeIcon matching VS Code's diagnostic palette. */
function severityThemeIcon(severity) {
    const name = severity === 'error' ? 'error' : severity === 'warning' ? 'warning' : 'info';
    const color = severity === 'error'
        ? 'list.errorForeground'
        : severity === 'warning'
            ? 'list.warningForeground'
            : 'editorInfo.foreground';
    return new vscode.ThemeIcon(name, new vscode.ThemeColor(color));
}
function getPageSize() {
    const n = vscode.workspace.getConfiguration('saropaLints').get('issuesPageSize', DEFAULT_PAGE_SIZE);
    return Math.max(1, Math.min(1000, typeof n === 'number' && !Number.isNaN(n) ? n : DEFAULT_PAGE_SIZE));
}
/** Build index: severity -> file path -> violations[]. Only includes violations that pass filters and suppressions. */
function buildFilteredIndex(violations, textFilter, severitiesToShow, impactsToShow, rulesToHide, suppressions, focusedFile) {
    const text = textFilter.trim().toLowerCase();
    const bySeverity = new Map();
    for (const v of violations) {
        // Focus mode: exact file match takes priority over all other filters.
        if (focusedFile && v.file !== focusedFile)
            continue;
        const severity = (v.severity ?? 'info').toLowerCase();
        const impact = (v.impact ?? 'low').toLowerCase();
        if (!severitiesToShow.has(severity) || !impactsToShow.has(impact))
            continue;
        if (suppressions.hiddenSeverities.includes(severity) || suppressions.hiddenImpacts.includes(impact))
            continue;
        if (rulesToHide.has(v.rule))
            continue;
        if ((0, suppressionsStore_1.isPathHidden)(suppressions, v.file))
            continue;
        if ((0, suppressionsStore_1.isRuleHidden)(suppressions, v.file, v.rule))
            continue;
        if (text) {
            const file = (0, pathUtils_1.normalizePath)(v.file);
            const match = file.includes(text) ||
                v.rule.toLowerCase().includes(text) ||
                (v.message && v.message.toLowerCase().includes(text));
            if (!match)
                continue;
        }
        let byFile = bySeverity.get(severity);
        if (!byFile) {
            byFile = new Map();
            bySeverity.set(severity, byFile);
        }
        const list = byFile.get(v.file) ?? [];
        list.push(v);
        byFile.set(v.file, list);
    }
    return bySeverity;
}
/** Get immediate children path segments under a folder prefix. Returns { folders: [name], files: [{ path, violations }] }. */
function getPathTreeChildren(severity, pathPrefix, byFile) {
    const prefix = pathPrefix ? pathPrefix + '/' : '';
    const folderSet = new Set();
    const files = [];
    for (const [filePath, list] of byFile.entries()) {
        if (!filePath.startsWith(prefix))
            continue;
        const rest = filePath.slice(prefix.length);
        const parts = rest.split('/');
        if (parts.length === 1) {
            files.push({ path: filePath, violations: list });
        }
        else {
            folderSet.add(parts[0]);
        }
    }
    const folders = Array.from(folderSet).sort();
    files.sort((a, b) => a.path.localeCompare(b.path));
    return { folders, files };
}
function violationLabel(v) {
    const msg = (v.message ?? '').slice(0, MESSAGE_LABEL_LEN);
    return `L${v.line}: [${v.rule}] ${msg}${msg.length >= MESSAGE_LABEL_LEN ? '…' : ''}`;
}
class IssuesTreeProvider {
    _onDidChangeTreeData = new vscode.EventEmitter();
    onDidChangeTreeData = this._onDidChangeTreeData.event;
    workspaceState;
    suppressions;
    textFilter = '';
    severitiesToShow = new Set(SEVERITY_ORDER);
    impactsToShow = new Set(['critical', 'high', 'medium', 'low', 'opinionated']);
    rulesToHide = new Set();
    focusedFile = undefined;
    groupBy = 'severity';
    cachedIndex = null;
    totalUnfiltered = 0;
    /** Rules that have quick-fix generators. Null = unknown (older analyzer), treat all as fixable. */
    rulesWithFixesSet = null;
    constructor(workspaceState) {
        this.workspaceState = workspaceState;
        this.suppressions = (0, suppressionsStore_1.loadSuppressions)(workspaceState);
    }
    hasViolations() {
        const root = (0, projectRoot_1.getProjectRoot)();
        return root ? (0, violationsReader_1.hasViolations)(root) : false;
    }
    refresh() {
        this.cachedIndex = null;
        this.rulesWithFixesSet = null;
        this._onDidChangeTreeData.fire();
    }
    getTypeFilterState() {
        return {
            severitiesToShow: new Set(this.severitiesToShow),
            impactsToShow: new Set(this.impactsToShow),
        };
    }
    /** Rule names that have violations in current data (for Filter by rule). */
    getRuleNamesFromData() {
        const root = (0, projectRoot_1.getProjectRoot)();
        if (!root)
            return [];
        const data = (0, violationsReader_1.readViolations)(root);
        const violations = data?.violations ?? [];
        const set = new Set();
        for (const v of violations)
            set.add(v.rule);
        return Array.from(set).sort();
    }
    getRulesToHide() {
        return new Set(this.rulesToHide);
    }
    getFilterState() {
        const root = (0, projectRoot_1.getProjectRoot)();
        let totalUnfiltered = this.totalUnfiltered;
        let filteredCount = 0;
        if (this.cachedIndex) {
            for (const byFile of this.cachedIndex.values()) {
                for (const list of byFile.values())
                    filteredCount += list.length;
            }
        }
        else if (root) {
            const data = (0, violationsReader_1.readViolations)(root);
            const violations = data?.violations ?? [];
            totalUnfiltered = violations.length;
            const idx = buildFilteredIndex(violations, this.textFilter, this.severitiesToShow, this.impactsToShow, this.rulesToHide, this.suppressions, this.focusedFile);
            this.cachedIndex = idx;
            this.totalUnfiltered = totalUnfiltered;
            for (const byFile of idx.values()) {
                for (const list of byFile.values())
                    filteredCount += list.length;
            }
        }
        const hasActiveFilters = this.textFilter.trim() !== '' ||
            this.severitiesToShow.size < 3 ||
            this.impactsToShow.size < 5 ||
            this.rulesToHide.size > 0 ||
            this.focusedFile !== undefined;
        const hasSuppressions = this.suppressions.hiddenFolders.length > 0 ||
            this.suppressions.hiddenFiles.length > 0 ||
            this.suppressions.hiddenRules.length > 0 ||
            Object.keys(this.suppressions.hiddenRuleInFile).length > 0 ||
            this.suppressions.hiddenSeverities.length > 0 ||
            this.suppressions.hiddenImpacts.length > 0;
        return {
            textFilter: this.textFilter,
            hasActiveFilters,
            hasSuppressions,
            totalUnfiltered,
            filteredCount,
        };
    }
    setTextFilter(value) {
        this.textFilter = value;
        this.cachedIndex = null;
        this._onDidChangeTreeData.fire();
    }
    setSeverityFilter(severities) {
        this.severitiesToShow = new Set(severities);
        this.cachedIndex = null;
        this._onDidChangeTreeData.fire();
    }
    setImpactFilter(impacts) {
        this.impactsToShow = new Set(impacts);
        this.cachedIndex = null;
        this._onDidChangeTreeData.fire();
    }
    setRulesToHide(rules) {
        this.rulesToHide = new Set(rules);
        this.cachedIndex = null;
        this._onDidChangeTreeData.fire();
    }
    setFocusedFile(filePath) {
        this.focusedFile = filePath;
        this.cachedIndex = null;
        this._onDidChangeTreeData.fire();
    }
    clearFocusedFile() {
        this.focusedFile = undefined;
        this.cachedIndex = null;
        this._onDidChangeTreeData.fire();
    }
    getFocusedFile() {
        return this.focusedFile;
    }
    clearFilters() {
        this.textFilter = '';
        this.severitiesToShow = new Set(SEVERITY_ORDER);
        this.impactsToShow = new Set(['critical', 'high', 'medium', 'low', 'opinionated']);
        this.rulesToHide = new Set();
        this.focusedFile = undefined;
        this.cachedIndex = null;
        this._onDidChangeTreeData.fire();
    }
    /** D10: Current grouping mode. */
    getGroupBy() {
        return this.groupBy;
    }
    /** D10: Change the grouping mode and refresh. */
    setGroupBy(mode) {
        this.groupBy = mode;
        this.cachedIndex = null;
        this._onDidChangeTreeData.fire();
    }
    clearSuppressionsAndRefresh() {
        this.suppressions = (0, suppressionsStore_1.clearSuppressions)();
        (0, suppressionsStore_1.saveSuppressions)(this.workspaceState, this.suppressions);
        this.cachedIndex = null;
        this._onDidChangeTreeData.fire();
    }
    addSuppressionFolder(folderPath) {
        this.suppressions = (0, suppressionsStore_1.addHiddenFolder)(this.suppressions, folderPath);
        (0, suppressionsStore_1.saveSuppressions)(this.workspaceState, this.suppressions);
        this.cachedIndex = null;
        this._onDidChangeTreeData.fire();
    }
    addSuppressionFile(filePath) {
        this.suppressions = (0, suppressionsStore_1.addHiddenFile)(this.suppressions, filePath);
        (0, suppressionsStore_1.saveSuppressions)(this.workspaceState, this.suppressions);
        this.cachedIndex = null;
        this._onDidChangeTreeData.fire();
    }
    addSuppressionRule(rule) {
        this.suppressions = (0, suppressionsStore_1.addHiddenRule)(this.suppressions, rule);
        (0, suppressionsStore_1.saveSuppressions)(this.workspaceState, this.suppressions);
        this.cachedIndex = null;
        this._onDidChangeTreeData.fire();
    }
    addSuppressionRuleInFile(filePath, rule) {
        this.suppressions = (0, suppressionsStore_1.addHiddenRuleInFile)(this.suppressions, filePath, rule);
        (0, suppressionsStore_1.saveSuppressions)(this.workspaceState, this.suppressions);
        this.cachedIndex = null;
        this._onDidChangeTreeData.fire();
    }
    addSuppressionSeverity(severity) {
        this.suppressions = (0, suppressionsStore_1.addHiddenSeverity)(this.suppressions, severity);
        (0, suppressionsStore_1.saveSuppressions)(this.workspaceState, this.suppressions);
        this.cachedIndex = null;
        this._onDidChangeTreeData.fire();
    }
    addSuppressionImpact(impact) {
        this.suppressions = (0, suppressionsStore_1.addHiddenImpact)(this.suppressions, impact);
        (0, suppressionsStore_1.saveSuppressions)(this.workspaceState, this.suppressions);
        this.cachedIndex = null;
        this._onDidChangeTreeData.fire();
    }
    getIndex(root) {
        const data = (0, violationsReader_1.readViolations)(root);
        if (!data)
            return null;
        const violations = data.violations ?? [];
        this.totalUnfiltered = violations.length;
        // Cache fix availability for contextValue in getTreeItem.
        // Null when the analyzer doesn't emit this field (backward compat).
        const fixNames = data.config?.rulesWithFixes;
        this.rulesWithFixesSet = fixNames ? new Set(fixNames) : null;
        this.cachedIndex = buildFilteredIndex(violations, this.textFilter, this.severitiesToShow, this.impactsToShow, this.rulesToHide, this.suppressions, this.focusedFile);
        return this.cachedIndex;
    }
    getTreeItem(element) {
        const wsRoot = (0, projectRoot_1.getProjectRoot)() ?? '';
        if (element.kind === 'placeholder') {
            const item = new vscode.TreeItem(element.label, vscode.TreeItemCollapsibleState.None);
            item.description = element.description;
            item.iconPath =
                element.id === 'no-data'
                    ? new vscode.ThemeIcon('run')
                    : element.id === 'no-match'
                        ? new vscode.ThemeIcon('filter')
                        : new vscode.ThemeIcon('loading');
            if (element.command) {
                item.command = {
                    command: element.command,
                    title: element.id === 'no-match' ? 'Clear filters' : 'Run Analysis',
                };
            }
            item.contextValue = 'placeholder';
            return item;
        }
        if (element.kind === 'severity') {
            const label = `${element.severity.charAt(0).toUpperCase() + element.severity.slice(1)} (${element.count})`;
            const item = new vscode.TreeItem(label, vscode.TreeItemCollapsibleState.Collapsed);
            item.iconPath = severityThemeIcon(element.severity);
            item.tooltip = `${element.count} ${element.severity}(s)`;
            item.contextValue = 'severity';
            item.accessibilityInformation = { label: `${element.severity}, ${element.count} issues`, role: 'treeitem' };
            return item;
        }
        if (element.kind === 'folder') {
            const item = new vscode.TreeItem(element.segmentName, vscode.TreeItemCollapsibleState.Collapsed);
            // Inherit severity icon+color from parent so folders visually match their severity group.
            item.iconPath = element.severity
                ? severityThemeIcon(element.severity)
                : new vscode.ThemeIcon('folder');
            item.description = `${element.count} issues`;
            item.tooltip = `${element.pathPrefix || element.segmentName}/ — ${element.count} issues`;
            item.contextValue = 'folder';
            item.accessibilityInformation = {
                label: `${element.segmentName}, ${element.count} issues`,
                role: 'treeitem',
            };
            return item;
        }
        if (element.kind === 'file') {
            const base = path.basename(element.filePath);
            const item = new vscode.TreeItem(`${base} (${element.violations.length})`, vscode.TreeItemCollapsibleState.Collapsed);
            item.resourceUri = vscode.Uri.file(path.join(wsRoot, element.filePath));
            item.iconPath = new vscode.ThemeIcon('document');
            item.description = element.filePath;
            // D10: When grouped by file/impact/rule/owasp, severity is empty — use generic label.
            item.tooltip = element.severity
                ? `${element.filePath} — ${element.violations.length} ${element.severity}(s)`
                : `${element.filePath} — ${element.violations.length} violation${element.violations.length === 1 ? '' : 's'}`;
            item.contextValue = 'file';
            item.accessibilityInformation = {
                label: `${base}, ${element.violations.length} issues`,
                role: 'treeitem',
            };
            return item;
        }
        if (element.kind === 'violation') {
            const v = element.violation;
            const item = new vscode.TreeItem(violationLabel(v), vscode.TreeItemCollapsibleState.None);
            item.resourceUri = vscode.Uri.file(path.join(wsRoot, v.file));
            item.command = {
                command: 'vscode.open',
                title: 'Open',
                arguments: [
                    item.resourceUri,
                    { selection: new vscode.Range(v.line - 1, 0, v.line - 1, 0) },
                ],
            };
            const tooltip = new vscode.MarkdownString();
            tooltip.appendMarkdown((v.message ?? '').replace(/]/g, '\\]'));
            if (v.correction) {
                tooltip.appendMarkdown('\n\n**Fix:** ');
                tooltip.appendMarkdown(v.correction.replace(/]/g, '\\]'));
            }
            const ruleName = v.rule ?? '';
            if (ruleName) {
                tooltip.appendMarkdown('\n\n**Rule:** `' + ruleName.replace(/`/g, '\\`') + '`');
                const desc = (0, ruleMetadata_1.getRuleDescription)(ruleName);
                if (desc) {
                    tooltip.appendMarkdown('\n\n' + desc.replace(/]/g, '\\]'));
                }
                tooltip.appendMarkdown('\n\n[More](' + (0, ruleMetadata_1.getRuleDocUrl)(ruleName) + ')');
            }
            item.tooltip = tooltip;
            // Mark fixable violations so "Apply fix" is enabled; null set = unknown,
            // default to fixable for backward compat with older analyzer output.
            const hasFix = this.rulesWithFixesSet === null || this.rulesWithFixesSet.has(v.rule);
            item.contextValue = hasFix ? 'violationFixable' : 'violation';
            item.accessibilityInformation = {
                label: `Line ${v.line} ${v.rule}, ${(v.message ?? '').slice(0, 40)}`,
                role: 'button',
            };
            return item;
        }
        if (element.kind === 'overflow') {
            const item = new vscode.TreeItem(`and ${element.count} more…`, vscode.TreeItemCollapsibleState.None);
            item.iconPath = new vscode.ThemeIcon('ellipsis');
            item.tooltip = 'Open file or use Problems view to see all';
            item.resourceUri = vscode.Uri.file(path.join(wsRoot, element.filePath));
            item.command = {
                command: 'vscode.open',
                title: 'Open file',
                arguments: [item.resourceUri],
            };
            item.contextValue = 'overflow';
            return item;
        }
        // D10: Generic group item for impact/rule/owasp grouping.
        if (element.kind === 'group') {
            const item = new vscode.TreeItem(`${element.label} (${element.count})`, vscode.TreeItemCollapsibleState.Collapsed);
            // D10: Mode-aware icon — reads from element.mode (snapshot at creation) to avoid stale this.groupBy.
            if (element.mode === 'impact') {
                const k = element.groupKey;
                item.iconPath = new vscode.ThemeIcon(k === 'critical' ? 'error' : k === 'high' ? 'warning' : k === 'medium' ? 'info' : 'circle-outline');
            }
            else if (element.mode === 'owasp') {
                item.iconPath = new vscode.ThemeIcon('shield');
            }
            else {
                item.iconPath = new vscode.ThemeIcon('symbol-method');
            }
            item.tooltip = `${element.count} violation${element.count === 1 ? '' : 's'}`;
            item.contextValue = 'group';
            return item;
        }
        return new vscode.TreeItem('', vscode.TreeItemCollapsibleState.None);
    }
    async getChildren(element) {
        const root = (0, projectRoot_1.getProjectRoot)();
        if (!root)
            return [];
        const data = (0, violationsReader_1.readViolations)(root);
        // C5: Return empty array when no violations file so viewsWelcome content renders.
        if (!data)
            return [];
        const violations = data.violations ?? [];
        // Zero violations after analysis — show a clean-state item (not empty,
        // because viewsWelcome would misleadingly say "No analysis results yet").
        if (violations.length === 0 && !element) {
            return [
                {
                    kind: 'placeholder',
                    id: 'no-data',
                    label: 'No violations found',
                    description: 'All clear',
                    command: 'saropaLints.runAnalysis',
                },
            ];
        }
        const index = this.getIndex(root);
        if (!index)
            return [];
        let filteredTotal = 0;
        for (const byFile of index.values()) {
            for (const list of byFile.values())
                filteredTotal += list.length;
        }
        if (filteredTotal === 0 && !element) {
            return [
                {
                    kind: 'placeholder',
                    id: 'no-match',
                    label: 'No issues match your filters',
                    description: 'Clear filters or suppressions',
                    command: 'saropaLints.clearIssuesFilters',
                },
            ];
        }
        if (!element) {
            // D10: Delegate to grouping-mode-specific root builder.
            if (this.groupBy !== 'severity') {
                return this.buildGroupedRoot(index);
            }
            const items = [];
            for (const sev of SEVERITY_ORDER) {
                const byFile = index.get(sev);
                if (!byFile)
                    continue;
                let count = 0;
                for (const list of byFile.values())
                    count += list.length;
                if (count > 0)
                    items.push({ kind: 'severity', severity: sev, count });
            }
            return items;
        }
        // D10: GroupItem children — sub-group violations by file for easy navigation.
        if (element.kind === 'group') {
            return buildFileItems(element.violations);
        }
        if (element.kind === 'severity') {
            const byFile = index.get(element.severity);
            if (!byFile)
                return [];
            const { folders, files } = getPathTreeChildren(element.severity, '', byFile);
            const result = [];
            for (const name of folders) {
                const pathPrefix = ''; // root-level folder: no prefix
                const segmentName = name;
                let count = 0;
                for (const [filePath, list] of byFile.entries()) {
                    if (filePath === segmentName || filePath.startsWith(segmentName + '/'))
                        count += list.length;
                }
                result.push({
                    kind: 'folder',
                    severity: element.severity,
                    pathPrefix,
                    segmentName,
                    count,
                });
            }
            for (const { path: filePath, violations: list } of files) {
                result.push({
                    kind: 'file',
                    severity: element.severity,
                    filePath,
                    violations: list,
                });
            }
            return result;
        }
        if (element.kind === 'folder') {
            const byFile = index.get(element.severity);
            if (!byFile)
                return [];
            const prefix = element.pathPrefix ? `${element.pathPrefix}/${element.segmentName}` : element.segmentName;
            const { folders, files } = getPathTreeChildren(element.severity, prefix, byFile);
            const result = [];
            for (const name of folders) {
                const nextPrefix = `${prefix}/${name}`;
                let count = 0;
                for (const [filePath, list] of byFile.entries()) {
                    if (filePath === nextPrefix || filePath.startsWith(nextPrefix + '/'))
                        count += list.length;
                }
                result.push({
                    kind: 'folder',
                    severity: element.severity,
                    pathPrefix: prefix,
                    segmentName: name,
                    count,
                });
            }
            for (const { path: filePath, violations: list } of files) {
                result.push({
                    kind: 'file',
                    severity: element.severity,
                    filePath,
                    violations: list,
                });
            }
            return result;
        }
        if (element.kind === 'file') {
            const list = element.violations;
            const sorted = [...list].sort((a, b) => a.line - b.line);
            const pageSize = getPageSize();
            const page = sorted.slice(0, pageSize);
            const result = page.map((v) => ({ kind: 'violation', violation: v }));
            const rest = sorted.length - pageSize;
            if (rest > 0) {
                result.push({
                    kind: 'overflow',
                    filePath: element.filePath,
                    severity: element.severity,
                    count: rest,
                });
            }
            return result;
        }
        return [];
    }
    /**
     * D10: Flatten all violations from the severity→file index into a single array.
     * Needed by non-severity grouping modes which ignore severity boundaries.
     */
    collectAllViolations(index) {
        const all = [];
        for (const byFile of index.values()) {
            for (const list of byFile.values()) {
                for (const v of list)
                    all.push(v);
            }
        }
        return all;
    }
    /**
     * D10: Build root nodes for non-severity grouping modes.
     * File mode → flat FileItem[] sorted by violation count.
     * Impact/rule/owasp → GroupItem[] where each group header expands to FileItem[] children.
     * A single violation can appear in multiple OWASP groups (fan-out).
     */
    buildGroupedRoot(index) {
        const all = this.collectAllViolations(index);
        // File mode bypasses GroupItem — returns FileItem[] directly.
        if (this.groupBy === 'file') {
            return buildFileItems(all);
        }
        // Snapshot mode once so extractGroupKeys and GroupItem.mode are consistent,
        // and getTreeItem reads element.mode instead of this.groupBy (avoids stale-icon race).
        const currentMode = this.groupBy;
        // Fan out violations into group buckets.
        // extractGroupKeys may return multiple keys (e.g. OWASP M1 + A03),
        // so one violation can appear under multiple group headers.
        const groups = new Map();
        for (const v of all) {
            for (const key of this.extractGroupKeys(v, currentMode)) {
                const list = groups.get(key) ?? [];
                list.push(v);
                groups.set(key, list);
            }
        }
        const items = [];
        for (const [key, violations] of groups) {
            items.push({
                kind: 'group',
                mode: currentMode,
                groupKey: key,
                label: currentMode === 'impact' ? key.charAt(0).toUpperCase() + key.slice(1) : key,
                count: violations.length,
                violations,
            });
        }
        // Impact uses severity-like predefined order; others sort by count desc with name tie-breaker.
        if (currentMode === 'impact') {
            const order = ['critical', 'high', 'medium', 'low', 'opinionated'];
            items.sort((a, b) => order.indexOf(a.groupKey) - order.indexOf(b.groupKey));
        }
        else {
            items.sort((a, b) => b.count - a.count || a.groupKey.localeCompare(b.groupKey));
        }
        return items;
    }
    /**
     * D10: Extract grouping keys for a violation based on the given mode.
     * Returns an array because OWASP mode can map one violation to multiple categories.
     * Impact and rule modes always return exactly one key.
     * Accepts explicit mode parameter so callers use the snapshot, not live this.groupBy.
     */
    extractGroupKeys(v, mode) {
        if (mode === 'impact')
            return [(v.impact ?? 'low').toLowerCase()];
        if (mode === 'rule')
            return [v.rule];
        if (mode === 'file')
            return [v.file];
        // OWASP: violation can map to multiple categories (e.g. both M1 and A03).
        // Use normalizeOwaspId (strip text after colon) to match the canonical IDs
        // used by securityPostureTree and owaspExport.
        const cats = [...(v.owasp?.mobile ?? []), ...(v.owasp?.web ?? [])].map(securityPostureTree_1.normalizeOwaspId);
        return cats.length > 0 ? cats : ['Uncategorized'];
    }
    getParent(element) {
        return undefined;
    }
}
exports.IssuesTreeProvider = IssuesTreeProvider;
/** D10: Group violations by file into FileItem[], sorted by count desc then name. */
function buildFileItems(violations) {
    const byFile = new Map();
    for (const v of violations) {
        const list = byFile.get(v.file) ?? [];
        list.push(v);
        byFile.set(v.file, list);
    }
    const items = [];
    for (const [filePath, list] of byFile) {
        items.push({ kind: 'file', severity: '', filePath, violations: list });
    }
    // Sort by count descending, then by path ascending as tie-breaker for stable order.
    items.sort((a, b) => b.violations.length - a.violations.length || a.filePath.localeCompare(b.filePath));
    return items;
}
function folderPath(e) {
    return e.pathPrefix ? `${e.pathPrefix}/${e.segmentName}` : e.segmentName;
}
/** Max end character for a line when requesting code actions (range is clamped by the editor). */
const APPLY_FIX_LINE_END = 4096;
/** Number of code actions to resolve when applying fix from tree (enough to find rule match). */
const APPLY_FIX_RESOLVE_COUNT = 10;
/**
 * Returns the string form of a diagnostic's code (VS Code allows code to be string, number, or { value }).
 */
function diagnosticCodeString(code) {
    if (code === undefined || code === null)
        return '';
    if (typeof code === 'object' && code !== null && 'value' in code) {
        return String(code.value);
    }
    return String(code);
}
/**
 * Invokes the Dart analyzer's quick fix for the given violation at its file/line.
 * Prefers a code action matching the violation's rule; otherwise uses the first quick fix.
 */
async function applyFixForViolation(v, root) {
    const uri = vscode.Uri.file(path.join(root, v.file));
    const line = Math.max(0, (v.line ?? 1) - 1);
    const range = new vscode.Range(line, 0, line, APPLY_FIX_LINE_END);
    const codeActions = await vscode.commands.executeCommand('vscode.executeCodeActionProvider', uri, range, vscode.CodeActionKind.QuickFix.value, APPLY_FIX_RESOLVE_COUNT);
    if (!Array.isArray(codeActions) || codeActions.length === 0) {
        void vscode.window.showInformationMessage('No quick fix available for this violation.');
        // D4: Return false — no fix was available.
        return false;
    }
    const rule = (v.rule ?? '').toString();
    const match = codeActions.find((a) => (Array.isArray(a.diagnostics) &&
        a.diagnostics.some((d) => diagnosticCodeString(d?.code) === rule)) ||
        (a.title && String(a.title).toLowerCase().includes(rule.toLowerCase())));
    const action = match ?? codeActions[0];
    if (action.edit) {
        await vscode.workspace.applyEdit(action.edit);
    }
    if (action.command) {
        await vscode.commands.executeCommand(action.command.command, ...(action.command.arguments ?? []));
    }
    if (!action.edit && !action.command) {
        void vscode.window.showInformationMessage('No quick fix available for this violation.');
        // D4: Return false — code action had no edit or command.
        return false;
    }
    return true;
}
/**
 * D7: Fix all auto-fixable violations in a single file.
 * Processes violations bottom-up (descending line order) to avoid
 * line-number shifts invalidating subsequent fixes.
 */
async function fixAllInFile(violations, root, progress) {
    const sorted = [...violations].sort((a, b) => (b.line ?? 0) - (a.line ?? 0));
    let fixed = 0;
    let skipped = 0;
    for (const v of sorted) {
        progress.report({ message: `${fixed + skipped + 1}/${sorted.length}` });
        const ok = await applyFixForViolation(v, root);
        if (ok) {
            fixed++;
        }
        else {
            skipped++;
        }
    }
    return { fixed, skipped };
}
function registerIssueCommands(provider, context) {
    context.subscriptions.push(vscode.commands.registerCommand('saropaLints.hideFolder', (element) => {
        if (element && typeof element === 'object' && 'kind' in element && element.kind === 'folder') {
            provider.addSuppressionFolder(folderPath(element));
            vscode.window.setStatusBarMessage('Folder hidden. Clear suppressions to show again.', 3000);
        }
    }), vscode.commands.registerCommand('saropaLints.hideFile', (element) => {
        if (element && typeof element === 'object' && 'kind' in element && element.kind === 'file') {
            provider.addSuppressionFile(element.filePath);
            vscode.window.setStatusBarMessage('File hidden. Clear suppressions to show again.', 3000);
        }
    }), vscode.commands.registerCommand('saropaLints.hideRule', (element) => {
        if (element && typeof element === 'object' && 'kind' in element && element.kind === 'violation') {
            provider.addSuppressionRule(element.violation.rule);
            vscode.window.setStatusBarMessage('Rule hidden. Clear suppressions to show again.', 3000);
        }
    }), vscode.commands.registerCommand('saropaLints.hideRuleInFile', (element) => {
        if (element && typeof element === 'object' && 'kind' in element && element.kind === 'violation') {
            const v = element.violation;
            provider.addSuppressionRuleInFile(v.file, v.rule);
            vscode.window.setStatusBarMessage('Rule hidden in this file. Clear suppressions to show again.', 3000);
        }
    }), vscode.commands.registerCommand('saropaLints.hideSeverity', (element) => {
        if (element && typeof element === 'object' && 'kind' in element && element.kind === 'severity') {
            provider.addSuppressionSeverity(element.severity);
            vscode.window.setStatusBarMessage('Severity hidden. Clear suppressions to show again.', 3000);
        }
    }), vscode.commands.registerCommand('saropaLints.hideImpact', (element) => {
        if (element && typeof element === 'object' && 'kind' in element && element.kind === 'violation') {
            const impact = (element.violation.impact ?? 'low').toLowerCase();
            provider.addSuppressionImpact(impact);
            vscode.window.setStatusBarMessage('Impact hidden. Clear suppressions to show again.', 3000);
        }
    }), vscode.commands.registerCommand('saropaLints.copyPath', (element) => {
        if (element && typeof element === 'object' && 'kind' in element) {
            const e = element;
            let p = '';
            if (e.kind === 'folder')
                p = folderPath(e);
            else if (e.kind === 'file')
                p = e.filePath;
            if (p)
                void vscode.env.clipboard.writeText(p);
        }
    }), vscode.commands.registerCommand('saropaLints.copyMessage', (element) => {
        if (element && typeof element === 'object' && 'kind' in element && element.kind === 'violation') {
            const msg = element.violation.message ?? '';
            void vscode.env.clipboard.writeText(msg);
        }
    }), vscode.commands.registerCommand('saropaLints.applyFix', async (element) => {
        if (!element || typeof element !== 'object' || !('kind' in element) || element.kind !== 'violation') {
            return;
        }
        const v = element.violation;
        const root = (0, projectRoot_1.getProjectRoot)();
        if (!root)
            return;
        // D4: Estimate score delta before applying fix.
        const data = (0, violationsReader_1.readViolations)(root);
        const estimate = data ? (0, healthScore_1.estimateScoreWithoutViolation)(data, v.impact ?? 'medium') : null;
        const applied = await vscode.window.withProgress({ location: vscode.ProgressLocation.Notification, title: 'Applying fix…', cancellable: false }, () => applyFixForViolation(v, root));
        // D4: Show score-aware result in status bar after successful fix.
        if (applied && estimate && estimate.delta > 0) {
            const pts = estimate.delta === 1 ? 'pt' : 'pts';
            void vscode.window.setStatusBarMessage(`Fixed 1 ${v.impact ?? ''} issue (est. +${estimate.delta} ${pts})`, 4000);
        }
        // Report: log fix attempt.
        if (root) {
            (0, reportWriter_1.logSection)('Fix');
            (0, reportWriter_1.logReport)(`- Rule: ${v.rule} (${v.file}:${v.line})`);
            (0, reportWriter_1.logReport)(`- Result: ${applied ? 'applied' : 'no fix available'}`);
            (0, reportWriter_1.flushReport)(root);
        }
    }), 
    // D7: Fix all auto-fixable violations in a file.
    vscode.commands.registerCommand('saropaLints.fixAllInFile', async (element) => {
        if (!element || typeof element !== 'object' || !('kind' in element) ||
            element.kind !== 'file')
            return;
        const fileNode = element;
        const root = (0, projectRoot_1.getProjectRoot)();
        if (!root)
            return;
        const data = (0, violationsReader_1.readViolations)(root);
        if (!data)
            return;
        const fileViolations = data.violations.filter((v) => v.file === fileNode.filePath);
        if (fileViolations.length === 0)
            return;
        // D7: Confirm before bulk-fixing files with many violations.
        const fileName = path.basename(fileNode.filePath);
        if (fileViolations.length > 20) {
            const ok = await vscode.window.showWarningMessage(`Fix ${fileViolations.length} violations in ${fileName}?`, { modal: true }, 'Fix All');
            if (ok !== 'Fix All')
                return;
        }
        const result = await vscode.window.withProgress({
            location: vscode.ProgressLocation.Notification,
            title: `Fixing violations in ${fileName}`,
            cancellable: false,
        }, (progress) => fixAllInFile(fileViolations, root, progress));
        // D7: Show result summary.
        const fixedMsg = `Fixed ${result.fixed}` +
            (result.skipped > 0 ? `, skipped ${result.skipped} (no fix available)` : '');
        void vscode.window.showInformationMessage(`${fixedMsg}. Run analysis to update score.`);
        // Report: log bulk fix result.
        if (root) {
            (0, reportWriter_1.logSection)('Bulk Fix');
            (0, reportWriter_1.logReport)(`- File: ${fileNode.filePath}`);
            (0, reportWriter_1.logReport)(`- Fixed: ${result.fixed}, Skipped: ${result.skipped}`);
            (0, reportWriter_1.flushReport)(root);
        }
        // D7: Auto-run analysis after bulk fix to update score.
        const cfg = vscode.workspace.getConfiguration('saropaLints');
        const runAfter = cfg.get('runAnalysisAfterConfigChange', true);
        if (runAfter && result.fixed > 0) {
            await vscode.commands.executeCommand('saropaLints.runAnalysis');
        }
    }));
}
//# sourceMappingURL=issuesTree.js.map