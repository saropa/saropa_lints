"use strict";
/**
 * D1: Security Posture tree — OWASP Top 10 coverage matrix.
 *
 * Two collapsible parents ("Mobile Top 10", "Web Top 10"), each with
 * category rows showing violation counts. Click filters Issues view
 * to rules mapped to that OWASP category.
 *
 * OWASP ID contract: violations.json stores OWASP categories as short-form
 * IDs (e.g. "M1", "A03") in the `owasp.mobile[]` and `owasp.web[]` arrays.
 * The tree matches these against `idPrefix()` of the display labels.
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
exports.SecurityPostureTreeProvider = exports.WEB_TOP_10 = exports.MOBILE_TOP_10 = void 0;
exports.normalizeOwaspId = normalizeOwaspId;
const vscode = __importStar(require("vscode"));
const violationsReader_1 = require("../violationsReader");
const projectRoot_1 = require("../projectRoot");
// --- OWASP category labels ---
exports.MOBILE_TOP_10 = [
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
exports.WEB_TOP_10 = [
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
/**
 * Normalize an OWASP category string to its short-form ID.
 * Handles both "M1" and "M1: Improper Credential Usage" → "M1".
 */
function normalizeOwaspId(raw) {
    return raw.split(':')[0].trim();
}
/** Tree item for a top-level group (Mobile Top 10, Web Top 10). */
class GroupItem extends vscode.TreeItem {
    categoryType;
    totalCount;
    constructor(categoryType, label, totalCount) {
        super(label, vscode.TreeItemCollapsibleState.Collapsed);
        this.categoryType = categoryType;
        this.totalCount = totalCount;
        this.description = totalCount > 0 ? `${totalCount} issue${totalCount === 1 ? '' : 's'}` : 'No issues';
        this.iconPath = new vscode.ThemeIcon(totalCount > 0 ? 'shield' : 'verified');
        this.contextValue = 'securityGroup';
    }
}
/** Tree item for a single OWASP category row. */
class CategoryItem extends vscode.TreeItem {
    categoryType;
    categoryLabel;
    count;
    rules;
    constructor(categoryType, categoryLabel, count, rules) {
        super(categoryLabel, vscode.TreeItemCollapsibleState.None);
        this.categoryType = categoryType;
        this.categoryLabel = categoryLabel;
        this.count = count;
        this.rules = rules;
        this.description = count > 0 ? `${count}` : '';
        this.iconPath = new vscode.ThemeIcon(count > 0 ? 'warning' : 'pass', count > 0
            ? new vscode.ThemeColor('list.warningForeground')
            : new vscode.ThemeColor('testing.iconPassed'));
        this.contextValue = 'securityCategory';
        if (count > 0 && rules.length > 0) {
            // D1: Click to filter Issues view to rules mapped to this category.
            this.command = {
                command: 'saropaLints.focusIssuesForOwasp',
                title: 'Show issues',
                arguments: [rules],
            };
            this.tooltip = `${count} violation${count === 1 ? '' : 's'} across ${rules.length} rule${rules.length === 1 ? '' : 's'}. Click to show in Issues.`;
        }
        else {
            this.tooltip = 'No violations mapped to this category.';
        }
    }
}
class SecurityPostureTreeProvider {
    _onDidChangeTreeData = new vscode.EventEmitter();
    onDidChangeTreeData = this._onDidChangeTreeData.event;
    // Cache buildCounts result to avoid re-scanning violations on group expand.
    // Invalidated on refresh() so expanding a group reuses the top-level computation.
    cachedCounts = null;
    refresh() {
        this.cachedCounts = null;
        this._onDidChangeTreeData.fire();
    }
    getTreeItem(element) {
        return element;
    }
    getChildren(element) {
        const root = (0, projectRoot_1.getProjectRoot)();
        if (!root)
            return [];
        const cfg = vscode.workspace.getConfiguration('saropaLints');
        if (!(cfg.get('enabled', false) ?? false))
            return [];
        const data = (0, violationsReader_1.readViolations)(root);
        if (!data)
            return [];
        // Compute once and cache for both top-level and group-expand calls.
        if (!this.cachedCounts) {
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
            const categories = element.categoryType === 'mobile' ? exports.MOBILE_TOP_10 : exports.WEB_TOP_10;
            const catCounts = element.categoryType === 'mobile' ? counts.mobileCounts : counts.webCounts;
            const catRules = element.categoryType === 'mobile' ? counts.mobileCategoryRules : counts.webCategoryRules;
            return categories.map((label) => {
                const id = normalizeOwaspId(label);
                return new CategoryItem(element.categoryType, label, catCounts.get(id) ?? 0, catRules.get(id) ?? []);
            });
        }
        return [];
    }
}
exports.SecurityPostureTreeProvider = SecurityPostureTreeProvider;
/** Scan violations for OWASP data and build per-category counts + rule sets. */
function buildCounts(violations) {
    const mobileCounts = new Map();
    const webCounts = new Map();
    const mobileRulesSeen = new Map();
    const webRulesSeen = new Map();
    for (const v of violations) {
        if (!v.owasp || typeof v.owasp !== 'object')
            continue;
        // Guard against malformed JSON: owasp.mobile/web must be arrays of strings.
        if (Array.isArray(v.owasp.mobile)) {
            for (const rawCat of v.owasp.mobile) {
                if (typeof rawCat !== 'string')
                    continue;
                // Normalize to short-form ID in case the Dart side emits full strings.
                const cat = normalizeOwaspId(rawCat);
                mobileCounts.set(cat, (mobileCounts.get(cat) ?? 0) + 1);
                const set = mobileRulesSeen.get(cat) ?? new Set();
                set.add(v.rule);
                mobileRulesSeen.set(cat, set);
            }
        }
        if (Array.isArray(v.owasp.web)) {
            for (const rawCat of v.owasp.web) {
                if (typeof rawCat !== 'string')
                    continue;
                const cat = normalizeOwaspId(rawCat);
                webCounts.set(cat, (webCounts.get(cat) ?? 0) + 1);
                const set = webRulesSeen.get(cat) ?? new Set();
                set.add(v.rule);
                webRulesSeen.set(cat, set);
            }
        }
    }
    // Convert Sets to arrays for the CategoryItem constructor.
    const mobileCategoryRules = new Map();
    for (const [k, s] of mobileRulesSeen)
        mobileCategoryRules.set(k, [...s]);
    const webCategoryRules = new Map();
    for (const [k, s] of webRulesSeen)
        webCategoryRules.set(k, [...s]);
    return { mobileCounts, mobileCategoryRules, webCounts, webCategoryRules };
}
function sumValues(counts) {
    let total = 0;
    for (const v of counts.values())
        total += v;
    return total;
}
//# sourceMappingURL=securityPostureTree.js.map