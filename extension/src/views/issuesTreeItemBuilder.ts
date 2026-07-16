/**
 * Renders a single Issues-tree node into a vscode.TreeItem.
 *
 * Extracted verbatim from IssuesTreeProvider.getTreeItem so the provider class
 * stays a thin data/state holder. This builder is a pure function of the node
 * plus a small render context (workspace root, collapse state, fix-availability
 * set, hotspot-review service); it reads no provider state directly, which is
 * what makes the extraction behavior-identical. See issuesTree.ts.
 */

import * as vscode from 'vscode';
import * as path from 'path';

import { cachedFileExists } from '../pathUtils';
import { getRelatedRules, getRuleDescription, getRuleDocUrl } from '../ruleMetadata';
import { Violation } from '../violationsReader';
import {
  SecurityHotspotReviewStateService,
  isSecurityHotspotViolation,
} from '../securityHotspotReviewState';
import { IssueTreeNode } from './issuesTreeTypes';

const MESSAGE_LABEL_LEN = 56;

const STALE_ICON = new vscode.ThemeIcon(
  'warning',
  new vscode.ThemeColor('problemsWarningIcon.foreground'),
);
const STALE_LABEL = '(file moved or deleted)';

/** Map a severity string to a colored ThemeIcon matching VS Code's diagnostic palette. */
function severityThemeIcon(severity: string): vscode.ThemeIcon {
  const name = severity === 'error' ? 'error' : severity === 'warning' ? 'warning' : 'info';
  const color = severity === 'error'
    ? 'list.errorForeground'
    : severity === 'warning'
      ? 'list.warningForeground'
      : 'editorInfo.foreground';
  return new vscode.ThemeIcon(name, new vscode.ThemeColor(color));
}

function violationLabel(v: Violation): string {
  const msg = (v.message ?? '').slice(0, MESSAGE_LABEL_LEN);
  return `L${v.line}: [${v.rule}] ${msg}${msg.length >= MESSAGE_LABEL_LEN ? '…' : ''}`;
}

/**
 * Render context supplied by the provider. Carries the provider state the
 * builder needs without coupling the builder to the class:
 * - wsRoot: workspace root for resolving absolute file paths.
 * - collapsedOrExpanded: collapse state (respects the provider's expand-all override).
 * - rulesWithFixesSet: rules that have quick-fix generators; null = unknown (older
 *   analyzer), treat all as fixable.
 * - hotspotReviewState: resolves the effective review state for hotspot violations.
 */
export interface IssueTreeItemContext {
  wsRoot: string;
  collapsedOrExpanded: vscode.TreeItemCollapsibleState;
  rulesWithFixesSet: Set<string> | null;
  hotspotReviewState: SecurityHotspotReviewStateService;
}

export function buildIssueTreeItem(
  element: IssueTreeNode,
  ctx: IssueTreeItemContext,
): vscode.TreeItem {
  const wsRoot = ctx.wsRoot;
  if (element.kind === 'placeholder') {
    const item = new vscode.TreeItem(
      element.label,
      vscode.TreeItemCollapsibleState.None,
    );
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
    const item = new vscode.TreeItem(
      label,
      ctx.collapsedOrExpanded,
    );
    item.iconPath = severityThemeIcon(element.severity);
    item.tooltip = `${element.count} ${element.severity}(s)`;
    item.contextValue = 'severity';
    item.accessibilityInformation = { label: `${element.severity}, ${element.count} issues`, role: 'treeitem' };
    return item;
  }
  if (element.kind === 'folder') {
    const item = new vscode.TreeItem(
      element.segmentName,
      ctx.collapsedOrExpanded,
    );
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
    const absPath = path.join(wsRoot, element.filePath);
    const exists = cachedFileExists(absPath);
    const item = new vscode.TreeItem(
      `${base} (${element.violations.length})`,
      // Still collapsible so users can see which violations existed.
      ctx.collapsedOrExpanded,
    );
    if (exists) {
      item.resourceUri = vscode.Uri.file(absPath);
      item.iconPath = new vscode.ThemeIcon('document');
      item.description = element.filePath;
      // D10: When grouped by file/impact/rule/owasp, severity is empty — use generic label.
      item.tooltip = element.severity
        ? `${element.filePath} — ${element.violations.length} ${element.severity}(s)`
        : `${element.filePath} — ${element.violations.length} violation${element.violations.length === 1 ? '' : 's'}`;
      // Clicking the file row opens the file. The expand/collapse triangle
      // still toggles children; this matches VS Code's standard tree behavior
      // where a collapsible node with a command both expands and invokes.
      item.command = {
        command: 'vscode.open',
        title: 'Open File',
        arguments: [item.resourceUri],
      };
    } else {
      // File was moved or deleted since last analysis — show warning instead of broken link.
      item.iconPath = STALE_ICON;
      item.description = STALE_LABEL;
      item.tooltip = `File not found: ${element.filePath}\nRe-run analysis to update.`;
    }
    item.contextValue = 'file';
    item.accessibilityInformation = {
      label: `${base}, ${element.violations.length} issues`,
      role: 'treeitem',
    };
    return item;
  }
  if (element.kind === 'violation') {
    const v = element.violation;
    const absPath = path.join(wsRoot, v.file);
    const exists = cachedFileExists(absPath);
    const hotspot = isSecurityHotspotViolation(v);
    const hotspotState = hotspot
      ? ctx.hotspotReviewState.getEffective(v)
      : undefined;
    const item = new vscode.TreeItem(
      violationLabel(v),
      vscode.TreeItemCollapsibleState.None,
    );
    if (exists) {
      item.resourceUri = vscode.Uri.file(absPath);
      item.command = {
        command: 'vscode.open',
        title: 'Open',
        arguments: [
          item.resourceUri,
          { selection: new vscode.Range(v.line - 1, 0, v.line - 1, 0) },
        ],
      };
    }
    // else: file moved/deleted — no command, so clicking does nothing instead of "file not found".
    const tooltip = new vscode.MarkdownString();
    if (!exists) {
      tooltip.appendMarkdown('**File not found** — re-run analysis to update.\n\n---\n\n');
    }
    tooltip.appendMarkdown((v.message ?? '').replace(/]/g, '\\]'));
    if (hotspot && hotspotState) {
      tooltip.appendMarkdown('\n\n**Hotspot review:** `' + hotspotState + '`');
    }
    if (v.correction) {
      tooltip.appendMarkdown('\n\n**Fix:** ');
      tooltip.appendMarkdown(v.correction.replace(/]/g, '\\]'));
    }
    const ruleName = v.rule ?? '';
    if (ruleName) {
      tooltip.appendMarkdown('\n\n**Rule:** `' + ruleName.replace(/`/g, '\\`') + '`');
      const desc = getRuleDescription(ruleName);
      if (desc) {
        tooltip.appendMarkdown('\n\n' + desc.replace(/]/g, '\\]'));
      }
      const related = getRelatedRules(ruleName).filter((r) => r !== ruleName);
      if (related.length > 0) {
        tooltip.appendMarkdown('\n\n**See also:** ');
        tooltip.appendMarkdown(
          related
            .slice(0, 3)
            .map((r) => '`' + r.replace(/`/g, '\\`') + '`')
            .join(', '),
        );
        if (related.length > 3) {
          tooltip.appendMarkdown(`, +${related.length - 3} more`);
        }
      }
      tooltip.appendMarkdown('\n\n[More](' + getRuleDocUrl(ruleName) + ')');
    }
    item.tooltip = tooltip;
    // Mark fixable violations so "Apply fix" is enabled; null set = unknown,
    // default to fixable for backward compat with older analyzer output.
    // Stale violations are not fixable — the file no longer exists.
    const hasFix = exists && (ctx.rulesWithFixesSet === null || ctx.rulesWithFixesSet.has(v.rule));
    if (hotspot) {
      item.description = hotspotState;
    }
    if (hotspot && hasFix) {
      item.contextValue = 'violationHotspotFixable';
    } else if (hotspot) {
      item.contextValue = 'violationHotspot';
    } else {
      item.contextValue = hasFix ? 'violationFixable' : 'violation';
    }
    item.accessibilityInformation = {
      label: `Line ${v.line} ${v.rule}, ${(v.message ?? '').slice(0, 40)}`,
      role: 'button',
    };
    return item;
  }
  if (element.kind === 'overflow') {
    const absPath = path.join(wsRoot, element.filePath);
    const exists = cachedFileExists(absPath);
    const item = new vscode.TreeItem(
      `and ${element.count} more…`,
      vscode.TreeItemCollapsibleState.None,
    );
    if (exists) {
      item.iconPath = new vscode.ThemeIcon('ellipsis');
      item.tooltip = 'Open file or use Problems view to see all';
      item.resourceUri = vscode.Uri.file(absPath);
      item.command = {
        command: 'vscode.open',
        title: 'Open file',
        arguments: [item.resourceUri],
      };
    } else {
      // File moved/deleted — don't attempt to open.
      item.iconPath = STALE_ICON;
      item.tooltip = `File not found: ${element.filePath}\nRe-run analysis to update.`;
    }
    item.contextValue = 'overflow';
    return item;
  }
  // D10: Generic group item for impact/rule/owasp grouping.
  if (element.kind === 'group') {
    const item = new vscode.TreeItem(
      `${element.label} (${element.count})`,
      ctx.collapsedOrExpanded,
    );
    // Mode-aware icon — reads from element.mode (snapshot at creation) so
    // `this.groupBy` changing mid-render doesn't mismatch the icon.
    // Three-bucket severity model (was 5 buckets pre-2026-05-03).
    if (element.mode === 'impact') {
      const k = element.groupKey;
      item.iconPath = new vscode.ThemeIcon(
        k === 'error' ? 'error' : k === 'warning' ? 'warning' : k === 'info' ? 'info' : 'circle-outline',
      );
    } else if (element.mode === 'owasp') {
      item.iconPath = new vscode.ThemeIcon('shield');
    } else if (element.mode === 'ruleStatus') {
      item.iconPath = new vscode.ThemeIcon('versions');
    } else if (element.mode === 'ruleType') {
      item.iconPath = new vscode.ThemeIcon('symbol-property');
    } else {
      item.iconPath = new vscode.ThemeIcon('symbol-method');
    }
    item.tooltip = `${element.count} violation${element.count === 1 ? '' : 's'}`;
    item.contextValue = 'group';
    return item;
  }
  // Exhaustiveness guard: every IssueTreeNode kind is handled above, so `element`
  // is `never` here. If a new kind is added to the union without a branch, this
  // stops compiling — converting "silently renders a blank row" into a build error.
  return assertUnhandledNode(element);
}

/** Compile-time exhaustiveness check; preserves the original blank-row fallback at runtime. */
function assertUnhandledNode(element: never): vscode.TreeItem {
  void element;
  return new vscode.TreeItem('', vscode.TreeItemCollapsibleState.None);
}
