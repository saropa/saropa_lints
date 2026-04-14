/**
 * D1: Security Posture tree — OWASP Top 10 coverage matrix.
 *
 * Two collapsible parents ("Mobile Top 10", "Web Top 10"), each with
 * category rows showing violation counts. Click filters Violations view
 * to rules mapped to that OWASP category.
 *
 * OWASP ID contract: violations.json stores OWASP categories as short-form
 * IDs (e.g. "M1", "A03") in the `owasp.mobile[]` and `owasp.web[]` arrays.
 * The tree matches these against `idPrefix()` of the display labels.
 */

import * as vscode from 'vscode';
import { readViolations, Violation, filterDisabledFromData } from '../violationsReader';
import { getProjectRoot } from '../projectRoot';
import { readDisabledRules } from '../configWriter';

// --- OWASP category labels ---

export const MOBILE_TOP_10: readonly string[] = [
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

export const WEB_TOP_10: readonly string[] = [
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

/**
 * Normalize an OWASP category string to its short-form ID.
 * Handles both "M1" and "M1: Improper Credential Usage" → "M1".
 */
export function normalizeOwaspId(raw: string): string {
  return raw.split(':')[0].trim();
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
      // D1: Click to filter Violations view to rules mapped to this category.
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

/** Per-category counts and rule sets computed from violations data. */
interface OwaspCounts {
  mobileCounts: Map<string, number>;
  mobileCategoryRules: Map<string, string[]>;
  webCounts: Map<string, number>;
  webCategoryRules: Map<string, string[]>;
}

export class SecurityPostureTreeProvider implements vscode.TreeDataProvider<SecurityTreeElement> {
  private _onDidChangeTreeData = new vscode.EventEmitter<SecurityTreeElement | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  // Cache buildCounts result to avoid re-scanning violations on group expand.
  // Invalidated on refresh() so expanding a group reuses the top-level computation.
  private cachedCounts: OwaspCounts | null = null;

  refresh(): void {
    this.cachedCounts = null;
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: SecurityTreeElement): vscode.TreeItem {
    return element;
  }

  getChildren(element?: SecurityTreeElement): SecurityTreeElement[] {
    const root = getProjectRoot();
    if (!root) return [];

    // Compute once and cache for both top-level and group-expand calls.
    // Only read files when the cache is empty (refresh() clears it).
    if (!this.cachedCounts) {
      const rawData = readViolations(root);
      if (!rawData) return [];
      // Filter out violations for rules disabled in config so OWASP
      // counts stay consistent with the Violations view.
      const data = filterDisabledFromData(rawData, readDisabledRules(root));
      this.cachedCounts = buildCounts(data.violations);
    }
    const counts = this.cachedCounts;

    if (!element) {
      // Top-level: two group nodes.
      const mobileTotal = sumValues(counts.mobileCounts);
      const webTotal = sumValues(counts.webCounts);
      return [
        new GroupItem('mobile', 'Mobile Top 10', mobileTotal),
        new GroupItem('web', 'Web Top 10', webTotal),
      ];
    }

    if (element instanceof GroupItem) {
      const categories = element.categoryType === 'mobile' ? MOBILE_TOP_10 : WEB_TOP_10;
      const catCounts = element.categoryType === 'mobile' ? counts.mobileCounts : counts.webCounts;
      const catRules = element.categoryType === 'mobile' ? counts.mobileCategoryRules : counts.webCategoryRules;
      return categories.map((label) => {
        const id = normalizeOwaspId(label);
        return new CategoryItem(
          element.categoryType,
          label,
          catCounts.get(id) ?? 0,
          catRules.get(id) ?? [],
        );
      });
    }

    return [];
  }
}

/** Scan violations for OWASP data and build per-category counts + rule sets. */
function buildCounts(violations: Violation[]): OwaspCounts {
  const mobileCounts = new Map<string, number>();
  const webCounts = new Map<string, number>();
  const mobileRulesSeen = new Map<string, Set<string>>();
  const webRulesSeen = new Map<string, Set<string>>();

  for (const v of violations) {
    if (!v.owasp || typeof v.owasp !== 'object') continue;

    // Guard against malformed JSON: owasp.mobile/web must be arrays of strings.
    if (Array.isArray(v.owasp.mobile)) {
      for (const rawCat of v.owasp.mobile) {
        if (typeof rawCat !== 'string') continue;
        // Normalize to short-form ID in case the Dart side emits full strings.
        const cat = normalizeOwaspId(rawCat);
        mobileCounts.set(cat, (mobileCounts.get(cat) ?? 0) + 1);
        const set = mobileRulesSeen.get(cat) ?? new Set<string>();
        set.add(v.rule);
        mobileRulesSeen.set(cat, set);
      }
    }
    if (Array.isArray(v.owasp.web)) {
      for (const rawCat of v.owasp.web) {
        if (typeof rawCat !== 'string') continue;
        const cat = normalizeOwaspId(rawCat);
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

function sumValues(counts: Map<string, number>): number {
  let total = 0;
  for (const v of counts.values()) total += v;
  return total;
}
