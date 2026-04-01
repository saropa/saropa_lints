/**
 * Per-tree-view serializers for the "Copy as JSON" feature.
 * Each serializer converts a view-specific tree node into a uniform JsonNode
 * (without children — the shared utility handles recursion).
 *
 * ## Vibrancy package tree (`serializeVibrancyNode`)
 *
 * Tree items are untyped `TreeItem`-like objects from the vibrancy providers. This module
 * maps `contextValue` plus a few payload fields (`result`, `problem`, `children`, …) into
 * stable JSON for clipboard export. **Dispatch order is significant:** earlier matchers win
 * (e.g. a node with `children[]` becomes `vibrancyGroup` before family/suggestion fallbacks).
 *
 * The vibrancy path is split into small `vibrancyAs*` helpers and a null-coalescing chain
 * in `serializeVibrancyNode` so static analysis (cognitive complexity) stays low without
 * changing behavior — each helper encodes one node kind from the UI.
 */

import type { JsonNode } from './copyTreeAsJson';
import type { IssueTreeNode } from './views/issuesTree';
import type { ConfigTreeNode } from './views/triageTree';

/** VS Code TreeItemLabel shape — avoids importing vscode at top level for testability. */
type TreeItemLabel = { label: string };

// ─── Issues Tree ──────────────────────────────────────────────────────────────

/** Serialize an Issues tree node (severity, folder, file, violation, group, etc.). */
export function serializeIssueNode(node: unknown): JsonNode | null {
    const n = node as IssueTreeNode;
    if (!n || typeof n !== 'object' || !('kind' in n)) return null;

    switch (n.kind) {
        case 'severity':
            return {
                type: 'severity',
                label: `${capitalize(n.severity)} (${n.count})`,
                data: { severity: n.severity, count: n.count },
            };
        case 'folder':
            return {
                type: 'folder',
                label: n.segmentName,
                description: `${n.count} issues`,
                data: {
                    pathPrefix: n.pathPrefix,
                    segmentName: n.segmentName,
                    severity: n.severity,
                    count: n.count,
                },
            };
        case 'file':
            return {
                type: 'file',
                label: n.filePath.split('/').pop() ?? n.filePath,
                description: n.filePath,
                data: {
                    filePath: n.filePath,
                    severity: n.severity || undefined,
                    violationCount: n.violations.length,
                },
            };
        case 'violation':
            return {
                type: 'violation',
                label: `L${n.violation.line}: [${n.violation.rule}]`,
                data: {
                    file: n.violation.file,
                    line: n.violation.line,
                    rule: n.violation.rule,
                    message: n.violation.message,
                    severity: n.violation.severity,
                    impact: n.violation.impact,
                    correction: n.violation.correction,
                    owasp: n.violation.owasp,
                },
            };
        case 'group':
            return {
                type: 'group',
                label: n.label,
                data: {
                    mode: n.mode,
                    groupKey: n.groupKey,
                    count: n.count,
                },
            };
        case 'overflow':
            return {
                type: 'overflow',
                label: `and ${n.count} more…`,
                data: { filePath: n.filePath, count: n.count },
            };
        case 'placeholder':
            return {
                type: 'placeholder',
                label: n.label,
                description: n.description,
            };
        default:
            return null;
    }
}

// ─── Config Tree ──────────────────────────────────────────────────────────────

/** Serialize a Config tree node (setting, triage group, triage rule, info). */
export function serializeConfigNode(node: unknown): JsonNode | null {
    const n = node as ConfigTreeNode;
    if (!n || typeof n !== 'object' || !('kind' in n)) return null;

    switch (n.kind) {
        case 'configSetting':
            return {
                type: 'configSetting',
                label: n.label,
                description: n.description,
            };
        case 'triageGroup':
            return {
                type: 'triageGroup',
                label: n.label,
                description: n.description,
                data: {
                    groupId: n.groupId,
                    rules: n.rules,
                    totalIssues: n.totalIssues,
                },
            };
        case 'triageRule':
            return {
                type: 'triageRule',
                label: n.ruleName,
                data: { ruleName: n.ruleName, issueCount: n.issueCount },
            };
        case 'triageInfo':
            return {
                type: 'triageInfo',
                label: n.label,
                description: n.description,
            };
        default:
            return null;
    }
}

// ─── Summary Tree ─────────────────────────────────────────────────────────────

/** Serialize a Summary tree node. Uses TreeItem properties since SummaryItem is class-based. */
export function serializeSummaryNode(node: unknown): JsonNode | null {
    const item = node as { label?: string | TreeItemLabel; description?: string; nodeId?: string };
    if (!item || typeof item !== 'object') return null;
    const label = typeof item.label === 'string' ? item.label : (item.label as { label: string })?.label ?? '';
    if (!label) return null;
    return {
        type: item.nodeId ?? 'summaryItem',
        label,
        description: typeof item.description === 'string' ? item.description : undefined,
    };
}

// ─── Security Posture Tree ────────────────────────────────────────────────────

/** Serialize a Security Posture tree node (group or category). */
export function serializeSecurityNode(node: unknown): JsonNode | null {
    const item = node as {
        categoryType?: string;
        categoryLabel?: string;
        totalCount?: number;
        count?: number;
        rules?: string[];
        label?: string | TreeItemLabel;
        description?: string;
        contextValue?: string;
    };
    if (!item || typeof item !== 'object') return null;

    // GroupItem (Mobile Top 10, Web Top 10)
    if (item.contextValue === 'securityGroup') {
        const label = typeof item.label === 'string'
            ? item.label : (item.label as { label: string })?.label ?? '';
        return {
            type: 'securityGroup',
            label,
            data: {
                categoryType: item.categoryType,
                totalCount: item.totalCount,
            },
        };
    }

    // CategoryItem (M1, A01, etc.)
    if (item.contextValue === 'securityCategory') {
        return {
            type: 'securityCategory',
            label: item.categoryLabel ?? '',
            data: {
                categoryType: item.categoryType,
                count: item.count,
                rules: item.rules,
            },
        };
    }

    return null;
}

// ─── File Risk Tree ───────────────────────────────────────────────────────────

/** Serialize a File Risk tree node. */
export function serializeFileRiskNode(node: unknown): JsonNode | null {
    const n = node as { kind?: string; label?: string; description?: string; risk?: {
        filePath: string; total: number; critical: number; high: number; riskScore: number;
    } };
    if (!n || typeof n !== 'object' || !('kind' in n)) return null;

    if (n.kind === 'summary') {
        return {
            type: 'fileRiskSummary',
            label: n.label ?? '',
            description: n.description,
        };
    }

    if (n.kind === 'file' && n.risk) {
        return {
            type: 'fileRiskFile',
            label: n.risk.filePath.split('/').pop() ?? n.risk.filePath,
            description: n.risk.filePath,
            data: {
                filePath: n.risk.filePath,
                total: n.risk.total,
                critical: n.risk.critical,
                high: n.risk.high,
                riskScore: n.risk.riskScore,
            },
        };
    }

    return null;
}

// ─── Overview Tree ────────────────────────────────────────────────────────────

/** Serialize an Overview tree node (intro rows, section parents, toggles, embedded config nodes). */
export function serializeOverviewNode(node: unknown): JsonNode | null {
    if (node && typeof node === 'object' && 'kind' in node) {
        const embedded = serializeConfigNode(node);
        if (embedded) return embedded;
    }
    const cv = (node as { contextValue?: string }).contextValue;
    if (cv === 'overviewSettingsSection') {
        return { type: 'overviewSettingsSection', label: 'Settings' };
    }
    if (cv === 'overviewIssuesSection') {
        return { type: 'overviewIssuesSection', label: 'Issues' };
    }
    if (cv === 'overviewSidebarSection') {
        return { type: 'overviewSidebarSection', label: 'Sidebar' };
    }
    return serializeTreeItemNode(node, 'overviewItem');
}

// ─── Suggestions Tree ─────────────────────────────────────────────────────────

/** Serialize a Suggestions tree node. Leaf-only — uses TreeItem label/description. */
export function serializeSuggestionNode(node: unknown): JsonNode | null {
    return serializeTreeItemNode(node, 'suggestionItem');
}

// ─── Vibrancy Packages Tree ──────────────────────────────────────────────────
// Matchers run in `serializeVibrancyNode` top-to-bottom; keep that list aligned with helpers here.

/** Loose shape of vibrancy tree items for JSON copy (mirrors package vibrancy tree nodes). */
type VibrancyTreeItem = {
    contextValue?: string;
    result?: Record<string, unknown>;
    section?: string;
    results?: Array<{ package: { name: string } }>;
    summary?: Record<string, unknown>;
    analyses?: unknown[];
    analysis?: Record<string, unknown>;
    insights?: unknown[];
    insight?: Record<string, unknown>;
    budgetResults?: unknown[];
    budgetResult?: Record<string, unknown>;
    children?: unknown[];
    packageName?: string;
    prereleaseVersion?: string;
    prereleaseTag?: string | null;
    url?: string;
    label?: string | TreeItemLabel;
    description?: string;
    split?: Record<string, unknown>;
    problem?: Record<string, unknown>;
    action?: Record<string, unknown>;
    unlocksPackages?: string[];
};

function vibrancyLabelOf(item: VibrancyTreeItem): string {
    return typeof item.label === 'string'
        ? item.label : (item.label as { label: string })?.label ?? '';
}

function vibrancyDescription(item: VibrancyTreeItem): string | undefined {
    return typeof item.description === 'string' ? item.description : undefined;
}

function vibrancyAsPackage(item: VibrancyTreeItem, label: string, cv: string): JsonNode | null {
    if (!cv.startsWith('vibrancyPackage') || !item.result) return null;
    return {
        type: 'vibrancyPackage',
        label,
        description: vibrancyDescription(item),
        data: item.result,
    };
}

function vibrancyAsSectionGroup(item: VibrancyTreeItem, label: string, cv: string): JsonNode | null {
    if (cv !== 'vibrancySectionGroup') return null;
    return {
        type: 'vibrancySectionGroup',
        label,
        data: {
            section: item.section,
            packageCount: item.results?.length ?? 0,
            packages: item.results?.map(r => r.package.name) ?? [],
        },
    };
}

function vibrancyAsSuppressedGroup(label: string, cv: string): JsonNode | null {
    if (cv !== 'vibrancySuppressedGroup') return null;
    return { type: 'vibrancySuppressedGroup', label };
}

function vibrancyAsDepGraphSummary(item: VibrancyTreeItem, label: string, cv: string): JsonNode | null {
    if (cv !== 'vibrancyDepGraphSummary') return null;
    return {
        type: 'vibrancyDepGraphSummary',
        label,
        data: item.summary ? { summary: item.summary } : undefined,
    };
}

function vibrancyAsOverridesGroup(item: VibrancyTreeItem, label: string, cv: string): JsonNode | null {
    if (cv !== 'vibrancyOverridesGroup') return null;
    return {
        type: 'vibrancyOverridesGroup',
        label,
        data: { overrideCount: item.analyses?.length ?? 0 },
    };
}

function vibrancyAsOverride(item: VibrancyTreeItem, label: string, cv: string): JsonNode | null {
    if (cv !== 'vibrancyOverrideStale' && cv !== 'vibrancyOverrideActive') return null;
    return {
        type: 'vibrancyOverride',
        label,
        description: vibrancyDescription(item),
        data: item.analysis ? { analysis: item.analysis } : undefined,
    };
}

function vibrancyAsActionItemsGroup(item: VibrancyTreeItem, label: string, cv: string): JsonNode | null {
    if (cv !== 'vibrancyActionItemsGroup') return null;
    return {
        type: 'vibrancyActionItemsGroup',
        label,
        data: { insightCount: item.insights?.length ?? 0 },
    };
}

function vibrancyAsInsight(item: VibrancyTreeItem, label: string, cv: string): JsonNode | null {
    if (cv !== 'vibrancyInsight') return null;
    return {
        type: 'vibrancyInsight',
        label,
        description: vibrancyDescription(item),
        data: item.insight ? { insight: item.insight } : undefined,
    };
}

function vibrancyAsBudgetGroup(item: VibrancyTreeItem, label: string, cv: string): JsonNode | null {
    if (cv !== 'vibrancyBudgetGroup') return null;
    return {
        type: 'vibrancyBudgetGroup',
        label,
        data: { budgetCount: item.budgetResults?.length ?? 0 },
    };
}

function vibrancyAsBudgetItem(item: VibrancyTreeItem, label: string, cv: string): JsonNode | null {
    if (cv !== 'vibrancyBudgetItem') return null;
    return {
        type: 'vibrancyBudgetItem',
        label,
        description: vibrancyDescription(item),
        data: item.budgetResult ? { budget: item.budgetResult } : undefined,
    };
}

function vibrancyAsPrerelease(item: VibrancyTreeItem, label: string, cv: string): JsonNode | null {
    if (cv !== 'vibrancyPrerelease') return null;
    return {
        type: 'vibrancyPrerelease',
        label,
        data: {
            packageName: item.packageName,
            prereleaseVersion: item.prereleaseVersion,
            prereleaseTag: item.prereleaseTag,
        },
    };
}

function vibrancyAsDetail(item: VibrancyTreeItem, label: string, cv: string): JsonNode | null {
    if (cv !== 'vibrancyDetailLink' && item.url === undefined) return null;
    return {
        type: 'vibrancyDetail',
        label,
        description: vibrancyDescription(item),
        data: item.url ? { url: item.url } : undefined,
    };
}

function vibrancyAsChildrenGroup(item: VibrancyTreeItem, label: string): JsonNode | null {
    if (!Array.isArray(item.children)) return null;
    return { type: 'vibrancyGroup', label };
}

function vibrancyAsFamily(item: VibrancyTreeItem, label: string, cv: string): JsonNode | null {
    if (cv !== 'vibrancyFamilyConflictGroup' && !item.split) return null;
    return {
        type: cv || 'vibrancyFamilySplit',
        label,
        data: item.split ? { split: item.split } : undefined,
    };
}

function vibrancyAsProblem(item: VibrancyTreeItem, label: string, cv: string): JsonNode | null {
    if (!cv.startsWith('vibrancyProblem.') || !item.problem) return null;
    const p = item.problem;
    return {
        type: 'vibrancyProblem',
        label,
        description: vibrancyDescription(item),
        data: {
            problemType: p.type,
            severity: p.severity,
            packageName: item.packageName,
        },
    };
}

function vibrancyAsSuggestion(item: VibrancyTreeItem, label: string, cv: string): JsonNode | null {
    if (!cv.startsWith('vibrancySuggestion.') || !item.action) return null;
    return {
        type: 'vibrancyProblemSuggestion',
        label,
        data: {
            action: item.action,
            unlocksPackages: item.unlocksPackages,
        },
    };
}

function vibrancyFallback(item: VibrancyTreeItem, label: string, cv: string): JsonNode | null {
    if (!label) return null;
    return {
        type: cv || 'vibrancyItem',
        label,
        description: vibrancyDescription(item),
    };
}

/** Serialize a Vibrancy tree node. Handles all 14+ node types. */
export function serializeVibrancyNode(node: unknown): JsonNode | null {
    const item = node as VibrancyTreeItem;
    if (!item || typeof item !== 'object') return null;
    const label = vibrancyLabelOf(item);
    const cv = item.contextValue ?? '';

    return (
        vibrancyAsPackage(item, label, cv)
        ?? vibrancyAsSectionGroup(item, label, cv)
        ?? vibrancyAsSuppressedGroup(label, cv)
        ?? vibrancyAsDepGraphSummary(item, label, cv)
        ?? vibrancyAsOverridesGroup(item, label, cv)
        ?? vibrancyAsOverride(item, label, cv)
        ?? vibrancyAsActionItemsGroup(item, label, cv)
        ?? vibrancyAsInsight(item, label, cv)
        ?? vibrancyAsBudgetGroup(item, label, cv)
        ?? vibrancyAsBudgetItem(item, label, cv)
        ?? vibrancyAsPrerelease(item, label, cv)
        ?? vibrancyAsDetail(item, label, cv)
        ?? vibrancyAsChildrenGroup(item, label)
        ?? vibrancyAsFamily(item, label, cv)
        ?? vibrancyAsProblem(item, label, cv)
        ?? vibrancyAsSuggestion(item, label, cv)
        ?? vibrancyFallback(item, label, cv)
    );
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Generic serializer for simple TreeItem-based nodes (label + description only). */
function serializeTreeItemNode(node: unknown, type: string): JsonNode | null {
    const item = node as { label?: string | TreeItemLabel; description?: string };
    if (!item || typeof item !== 'object') return null;
    const label = typeof item.label === 'string'
        ? item.label : (item.label as { label: string })?.label ?? '';
    if (!label) return null;
    return {
        type,
        label,
        description: typeof item.description === 'string' ? item.description : undefined,
    };
}

function capitalize(s: string): string {
    return s.charAt(0).toUpperCase() + s.slice(1);
}

