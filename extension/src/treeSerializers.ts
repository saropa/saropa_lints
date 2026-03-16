/**
 * Per-tree-view serializers for the "Copy as JSON" feature.
 * Each serializer converts a view-specific tree node into a uniform JsonNode
 * (without children — the shared utility handles recursion).
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

/** Serialize an Overview tree node. Leaf-only — uses TreeItem label/description. */
export function serializeOverviewNode(node: unknown): JsonNode | null {
    return serializeTreeItemNode(node, 'overviewItem');
}

// ─── Suggestions Tree ─────────────────────────────────────────────────────────

/** Serialize a Suggestions tree node. Leaf-only — uses TreeItem label/description. */
export function serializeSuggestionNode(node: unknown): JsonNode | null {
    return serializeTreeItemNode(node, 'suggestionItem');
}

// ─── Vibrancy Packages Tree ──────────────────────────────────────────────────

/** Serialize a Vibrancy tree node. Handles all 14+ node types. */
export function serializeVibrancyNode(node: unknown): JsonNode | null {
    const item = node as {
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
    if (!item || typeof item !== 'object') return null;

    const label = typeof item.label === 'string'
        ? item.label : (item.label as { label: string })?.label ?? '';
    const cv = item.contextValue ?? '';

    // PackageItem / SuppressedPackageItem
    if (cv.startsWith('vibrancyPackage') && item.result) {
        return {
            type: 'vibrancyPackage',
            label,
            description: typeof item.description === 'string' ? item.description : undefined,
            data: item.result as Record<string, unknown>,
        };
    }

    // SectionGroupItem
    if (cv === 'vibrancySectionGroup') {
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

    // SuppressedGroupItem
    if (cv === 'vibrancySuppressedGroup') {
        return { type: 'vibrancySuppressedGroup', label };
    }

    // DepGraphSummaryItem
    if (cv === 'vibrancyDepGraphSummary') {
        return {
            type: 'vibrancyDepGraphSummary',
            label,
            data: item.summary ? { summary: item.summary } : undefined,
        };
    }

    // OverridesGroupItem
    if (cv === 'vibrancyOverridesGroup') {
        return {
            type: 'vibrancyOverridesGroup',
            label,
            data: { overrideCount: (item.analyses as unknown[])?.length ?? 0 },
        };
    }

    // OverrideItem
    if (cv === 'vibrancyOverrideStale' || cv === 'vibrancyOverrideActive') {
        return {
            type: 'vibrancyOverride',
            label,
            description: typeof item.description === 'string' ? item.description : undefined,
            data: item.analysis ? { analysis: item.analysis } : undefined,
        };
    }

    // ActionItemsGroupItem
    if (cv === 'vibrancyActionItemsGroup') {
        return {
            type: 'vibrancyActionItemsGroup',
            label,
            data: { insightCount: (item.insights as unknown[])?.length ?? 0 },
        };
    }

    // InsightItem
    if (cv === 'vibrancyInsight') {
        return {
            type: 'vibrancyInsight',
            label,
            description: typeof item.description === 'string' ? item.description : undefined,
            data: item.insight ? { insight: item.insight } : undefined,
        };
    }

    // BudgetGroupItem
    if (cv === 'vibrancyBudgetGroup') {
        return {
            type: 'vibrancyBudgetGroup',
            label,
            data: { budgetCount: (item.budgetResults as unknown[])?.length ?? 0 },
        };
    }

    // BudgetItem
    if (cv === 'vibrancyBudgetItem') {
        return {
            type: 'vibrancyBudgetItem',
            label,
            description: typeof item.description === 'string' ? item.description : undefined,
            data: item.budgetResult ? { budget: item.budgetResult } : undefined,
        };
    }

    // PrereleaseItem
    if (cv === 'vibrancyPrerelease') {
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

    // DetailItem (with or without URL)
    if (cv === 'vibrancyDetailLink' || (item.url !== undefined)) {
        return {
            type: 'vibrancyDetail',
            label,
            description: typeof item.description === 'string' ? item.description : undefined,
            data: item.url ? { url: item.url } : undefined,
        };
    }

    // GroupItem (children container like "Version", "Update", "Community", etc.)
    if (Array.isArray(item.children)) {
        return {
            type: 'vibrancyGroup',
            label,
        };
    }

    // FamilyConflictGroupItem / FamilySplitItem
    if (cv === 'vibrancyFamilyConflictGroup' || item.split) {
        return {
            type: cv || 'vibrancyFamilySplit',
            label,
            data: item.split ? { split: item.split } : undefined,
        };
    }

    // ProblemItem (contextValue = "vibrancyProblem.{type}") — problem nodes live in the packages tree.
    if (cv.startsWith('vibrancyProblem.') && item.problem) {
        return {
            type: 'vibrancyProblem',
            label,
            description: typeof item.description === 'string' ? item.description : undefined,
            data: {
                problemType: (item.problem as Record<string, unknown>).type,
                severity: (item.problem as Record<string, unknown>).severity,
                packageName: item.packageName,
            },
        };
    }

    // SuggestionItem (contextValue = "vibrancySuggestion.{type}") — action suggestion nodes.
    if (cv.startsWith('vibrancySuggestion.') && item.action) {
        return {
            type: 'vibrancyProblemSuggestion',
            label,
            data: {
                action: item.action as Record<string, unknown>,
                unlocksPackages: item.unlocksPackages,
            },
        };
    }

    // ProblemSummaryItem
    if (cv === 'vibrancyProblemSummary') {
        return { type: 'vibrancyProblemSummary', label };
    }

    // Fallback for any other vibrancy node
    if (label) {
        return {
            type: cv || 'vibrancyItem',
            label,
            description: typeof item.description === 'string' ? item.description : undefined,
        };
    }

    return null;
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

