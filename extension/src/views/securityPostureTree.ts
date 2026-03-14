/**
 * D1: Security Posture tree — OWASP Top 10 coverage matrix.
 *
 * Two collapsible parents ("Mobile Top 10", "Web Top 10"), each with
 * category rows showing violation counts. Click filters Issues view
 * to rules mapped to that OWASP category.
 */

import * as vscode from 'vscode';
import { readViolations, Violation } from '../violationsReader';

// --- OWASP category labels ---

const MOBILE_TOP_10: readonly string[] = [
  'M1: Improper Credential Usage',
  'M2: Inadequate Supply Chain Security',
  'M3: Insecure Authentication/Authorization',
  'M4: Insufficient Input/Output Validation',
  'M5: Insecure Communication',
  'M6: Inadequate Privacy Controls',
  'M7: Insufficient Binary Protections',
  'M8: Security Misconfiguration',
  'M9: Insecure Data Storage',
  'M10: Insufficient Cryptography',
];

const WEB_TOP_10: readonly string[] = [
  'A01: Broken Access Control',
  'A02: Cryptographic Failures',
  'A03: Injection',
  'A04: Insecure Design',
  'A05: Security Misconfiguration',
  'A06: Vulnerable and Outdated Components',
  'A07: Identification and Authentication Failures',
  'A08: Software and Data Integrity Failures',
  'A09: Security Logging and Monitoring Failures',
  'A10: Server-Side Request Forgery',
];

type CategoryType = 'mobile' | 'web';

/** Parse the OWASP ID prefix from a label, e.g. "M1" from "M1: Improper...". */
function idPrefix(label: string): string {
  return label.split(':')[0].trim();
}

/** Tree item for a top-level group (Mobile Top 10, Web Top 10). */
class GroupItem extends vscode.TreeItem {
  constructor(
    public readonly categoryType: CategoryType,
    label: string,
    public readonly totalCount: number,
  ) {
    super(label, vscode.TreeItemCollapsibleState.Collapsed);
    this.description = totalCount > 0 ? `${totalCount} issue${totalCount === 1 ? '' : 's'}` : 'No issues';
    this.iconPath = new vscode.ThemeIcon(totalCount > 0 ? 'shield' : 'verified');
    this.contextValue = 'securityGroup';
  }
}

/** Tree item for a single OWASP category row. */
class CategoryItem extends vscode.TreeItem {
  constructor(
    public readonly categoryType: CategoryType,
    public readonly categoryLabel: string,
    public readonly count: number,
    public readonly rules: string[],
  ) {
    super(categoryLabel, vscode.TreeItemCollapsibleState.None);
    this.description = count > 0 ? `${count}` : '';
    this.iconPath = new vscode.ThemeIcon(
      count > 0 ? 'warning' : 'pass',
      count > 0
        ? new vscode.ThemeColor('list.warningForeground')
        : new vscode.ThemeColor('testing.iconPassed'),
    );
    this.contextValue = 'securityCategory';
    if (count > 0 && rules.length > 0) {
      // D1: Click to filter Issues view to rules mapped to this category.
      this.command = {
        command: 'saropaLints.focusIssuesForOwasp',
        title: 'Show issues',
        arguments: [rules],
      };
      this.tooltip = `${count} violation${count === 1 ? '' : 's'} across ${rules.length} rule${rules.length === 1 ? '' : 's'}. Click to show in Issues.`;
    } else {
      this.tooltip = 'No violations mapped to this category.';
    }
  }
}

type SecurityTreeElement = GroupItem | CategoryItem;

export class SecurityPostureTreeProvider implements vscode.TreeDataProvider<SecurityTreeElement> {
  private _onDidChangeTreeData = new vscode.EventEmitter<SecurityTreeElement | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: SecurityTreeElement): vscode.TreeItem {
    return element;
  }

  getChildren(element?: SecurityTreeElement): SecurityTreeElement[] {
    const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
    if (!root) return [];

    const cfg = vscode.workspace.getConfiguration('saropaLints');
    if (!(cfg.get<boolean>('enabled', false) ?? false)) return [];

    const data = readViolations(root);
    if (!data) return [];

    if (!element) {
      // Top-level: two group nodes.
      const { mobileCounts, webCounts } = this.buildCounts(data.violations);
      const mobileTotal = sumCounts(mobileCounts);
      const webTotal = sumCounts(webCounts);
      return [
        new GroupItem('mobile', 'Mobile Top 10', mobileTotal),
        new GroupItem('web', 'Web Top 10', webTotal),
      ];
    }

    if (element instanceof GroupItem) {
      const { mobileCounts, mobileCategoryRules, webCounts, webCategoryRules } = this.buildCounts(data.violations);
      const categories = element.categoryType === 'mobile' ? MOBILE_TOP_10 : WEB_TOP_10;
      const counts = element.categoryType === 'mobile' ? mobileCounts : webCounts;
      const categoryRules = element.categoryType === 'mobile' ? mobileCategoryRules : webCategoryRules;
      return categories.map((label) => {
        const id = idPrefix(label);
        return new CategoryItem(
          element.categoryType,
          label,
          counts.get(id) ?? 0,
          categoryRules.get(id) ?? [],
        );
      });
    }

    return [];
  }

  /** Scan violations for OWASP data and build per-category counts + rule sets. */
  private buildCounts(violations: Violation[]): {
    mobileCounts: Map<string, number>;
    mobileCategoryRules: Map<string, string[]>;
    webCounts: Map<string, number>;
    webCategoryRules: Map<string, string[]>;
  } {
    const mobileCounts = new Map<string, number>();
    const webCounts = new Map<string, number>();
    const mobileRulesSeen = new Map<string, Set<string>>();
    const webRulesSeen = new Map<string, Set<string>>();

    for (const v of violations) {
      if (!v.owasp) continue;

      if (v.owasp.mobile) {
        for (const cat of v.owasp.mobile) {
          mobileCounts.set(cat, (mobileCounts.get(cat) ?? 0) + 1);
          const set = mobileRulesSeen.get(cat) ?? new Set<string>();
          set.add(v.rule);
          mobileRulesSeen.set(cat, set);
        }
      }
      if (v.owasp.web) {
        for (const cat of v.owasp.web) {
          webCounts.set(cat, (webCounts.get(cat) ?? 0) + 1);
          const set = webRulesSeen.get(cat) ?? new Set<string>();
          set.add(v.rule);
          webRulesSeen.set(cat, set);
        }
      }
    }

    // Convert Sets to arrays for the CategoryItem constructor.
    const mobileCategoryRules = new Map<string, string[]>();
    for (const [k, s] of mobileRulesSeen) mobileCategoryRules.set(k, [...s]);
    const webCategoryRules = new Map<string, string[]>();
    for (const [k, s] of webRulesSeen) webCategoryRules.set(k, [...s]);

    return { mobileCounts, mobileCategoryRules, webCounts, webCategoryRules };
  }
}

function sumCounts(counts: Map<string, number>): number {
  let total = 0;
  for (const v of counts.values()) total += v;
  return total;
}
