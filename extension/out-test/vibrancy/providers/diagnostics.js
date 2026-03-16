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
exports.VibrancyDiagnostics = void 0;
const vscode = __importStar(require("vscode"));
const pubspec_parser_1 = require("../services/pubspec-parser");
const status_classifier_1 = require("../scoring/status-classifier");
const config_service_1 = require("../services/config-service");
const budget_checker_1 = require("../scoring/budget-checker");
const vuln_classifier_1 = require("../scoring/vuln-classifier");
const known_issues_1 = require("../scoring/known-issues");
const SEVERITY_MAP = {
    1: vscode.DiagnosticSeverity.Warning,
    2: vscode.DiagnosticSeverity.Information,
    3: vscode.DiagnosticSeverity.Hint,
};
class VibrancyDiagnostics {
    _collection;
    _splitsByPackage = new Map();
    _overrideAnalyses = [];
    _budgetResults = [];
    constructor(_collection) {
        this._collection = _collection;
    }
    /** Update detected family splits for diagnostic generation. */
    updateFamilySplits(splits) {
        this._splitsByPackage.clear();
        for (const split of splits) {
            for (const group of split.versionGroups) {
                for (const pkg of group.packages) {
                    this._splitsByPackage.set(pkg, split);
                }
            }
        }
    }
    /** Update override analyses for diagnostic generation. */
    updateOverrideAnalyses(analyses) {
        this._overrideAnalyses = analyses;
    }
    /** Update budget check results. */
    updateBudgetResults(results) {
        this._budgetResults = [...results];
    }
    /** Update diagnostics for a pubspec.yaml document. */
    update(uri, content, results) {
        const diagnostics = [];
        const eolSetting = (0, config_service_1.getEndOfLifeDiagnostics)();
        for (const result of results) {
            const range = (0, pubspec_parser_1.findPackageRange)(content, result.package.name);
            if (!range) {
                continue;
            }
            const vscodeRange = new vscode.Range(range.line, range.startChar, range.line, range.endChar);
            if (result.category !== 'vibrant') {
                const shouldSkip = result.category === 'end-of-life' && eolSetting === 'none';
                if (!shouldSkip) {
                    const severity = computeSeverity(result, eolSetting);
                    const message = buildMessage(result);
                    const diag = new vscode.Diagnostic(vscodeRange, message, severity);
                    diag.source = 'Saropa Package Vibrancy';
                    diag.code = result.category;
                    diagnostics.push(diag);
                }
            }
            if (result.isUnused) {
                const unusedMsg = `Unused dependency — no imports found for ${result.package.name} in lib/, bin/, or test/`;
                const unusedDiag = new vscode.Diagnostic(vscodeRange, unusedMsg, vscode.DiagnosticSeverity.Hint);
                unusedDiag.source = 'Saropa Package Vibrancy';
                unusedDiag.code = 'unused-dependency';
                diagnostics.push(unusedDiag);
            }
            const split = this._splitsByPackage.get(result.package.name);
            if (split) {
                const msg = buildFamilyConflictMessage(result.package.name, split);
                const splitDiag = new vscode.Diagnostic(vscodeRange, msg, vscode.DiagnosticSeverity.Warning);
                splitDiag.source = 'Saropa Package Vibrancy';
                splitDiag.code = 'family-conflict';
                diagnostics.push(splitDiag);
            }
            const threshold = (0, config_service_1.getVulnSeverityThreshold)();
            const filteredVulns = (0, vuln_classifier_1.filterBySeverity)(result.vulnerabilities, threshold);
            for (const vuln of filteredVulns) {
                const vulnDiag = buildVulnDiagnostic(vscodeRange, vuln);
                diagnostics.push(vulnDiag);
            }
            // Vibrant packages skip the vibrancy diagnostic above,
            // so show a standalone Hint when an update is available.
            if (result.category === 'vibrant'
                && result.updateInfo
                && result.updateInfo.updateStatus !== 'up-to-date') {
                const updateMsg = `${result.package.name} — Update available: ${result.updateInfo.currentVersion} → ${result.updateInfo.latestVersion} (${result.updateInfo.updateStatus})`;
                const updateDiag = new vscode.Diagnostic(vscodeRange, updateMsg, vscode.DiagnosticSeverity.Hint);
                updateDiag.source = 'Saropa Package Vibrancy';
                updateDiag.code = 'update-available';
                diagnostics.push(updateDiag);
            }
        }
        this._addOverrideDiagnostics(content, diagnostics);
        this._addBudgetDiagnostics(results, diagnostics);
        this._collection.set(uri, diagnostics);
    }
    _addBudgetDiagnostics(results, diagnostics) {
        const messages = (0, budget_checker_1.buildExceededDiagnostics)(results, this._budgetResults);
        if (messages.length === 0) {
            return;
        }
        const range = new vscode.Range(0, 0, 0, 0);
        for (const message of messages) {
            const diag = new vscode.Diagnostic(range, message, vscode.DiagnosticSeverity.Warning);
            diag.source = 'Saropa Package Vibrancy';
            diag.code = 'budget-exceeded';
            diagnostics.push(diag);
        }
    }
    _addOverrideDiagnostics(content, diagnostics) {
        const lines = content.split('\n');
        for (const analysis of this._overrideAnalyses) {
            if (analysis.status !== 'stale') {
                continue;
            }
            if (analysis.entry.isPathDep || analysis.entry.isGitDep) {
                continue;
            }
            const lineNum = analysis.entry.line;
            if (lineNum < 0 || lineNum >= lines.length) {
                continue;
            }
            const line = lines[lineNum];
            const match = line.match(/^\s{2}(\w[\w_]*)/);
            if (!match) {
                continue;
            }
            const startChar = line.indexOf(match[1]);
            const endChar = startChar + match[1].length;
            const vscodeRange = new vscode.Range(lineNum, startChar, lineNum, endChar);
            const msg = `No version conflict detected for ${analysis.entry.name} — remove from dependency_overrides if unneeded.`;
            const diag = new vscode.Diagnostic(vscodeRange, msg, vscode.DiagnosticSeverity.Warning);
            diag.source = 'Saropa Package Vibrancy';
            diag.code = 'stale-override';
            diagnostics.push(diag);
        }
    }
    clear() {
        this._collection.clear();
    }
}
exports.VibrancyDiagnostics = VibrancyDiagnostics;
function computeSeverity(result, eolSetting) {
    if (result.category === 'end-of-life') {
        const displayReplacement = result.knownIssue?.replacement
            ? (0, known_issues_1.getReplacementDisplayText)(result.knownIssue.replacement, result.package.version, result.knownIssue.replacementObsoleteFromVersion)
            : undefined;
        if (eolSetting === 'smart' && displayReplacement) {
            return vscode.DiagnosticSeverity.Warning;
        }
        return vscode.DiagnosticSeverity.Hint;
    }
    const sevValue = (0, status_classifier_1.categoryToSeverity)(result.category);
    return SEVERITY_MAP[sevValue] ?? vscode.DiagnosticSeverity.Hint;
}
function buildMessage(result) {
    const score = Math.round(result.score / 10);
    const name = result.package.name;
    const replacement = result.knownIssue?.replacement;
    const displayReplacement = replacement
        ? (0, known_issues_1.getReplacementDisplayText)(replacement, result.package.version, result.knownIssue?.replacementObsoleteFromVersion)
        : undefined;
    let msg;
    if (displayReplacement && (0, known_issues_1.isReplacementPackageName)(displayReplacement)) {
        msg = `Replace ${name} with ${displayReplacement}`;
    }
    else if (displayReplacement) {
        msg = `Deprecated: ${name} — ${displayReplacement}`;
    }
    else if (result.category === 'end-of-life') {
        msg = `Deprecated: ${name}`;
    }
    else if (result.category === 'stale' || result.category === 'legacy-locked') {
        // Stale and legacy-locked both warrant review, not deprecation
        msg = `Review ${name}`;
    }
    else {
        msg = `Monitor ${name}`;
    }
    if (result.knownIssue?.reason) {
        msg += ` — ${result.knownIssue.reason}`;
    }
    if (result.updateInfo
        && result.updateInfo.updateStatus !== 'up-to-date') {
        msg += ` | Update: ${result.updateInfo.currentVersion} → ${result.updateInfo.latestVersion}`;
    }
    if (result.blocker) {
        const bScore = result.blocker.blockerVibrancyScore;
        const scoreStr = bScore !== null
            ? ` (${Math.round(bScore / 10)}/10)` : '';
        msg += ` | Blocked: ${result.blocker.blockerPackage}${scoreStr}`;
    }
    const flaggedCount = result.github?.flaggedIssues?.length ?? 0;
    if (flaggedCount > 0) {
        msg += ` | ${flaggedCount} flagged issue(s)`;
    }
    return `${msg} (${score}/10)`;
}
function buildFamilyConflictMessage(packageName, split) {
    const ownGroup = split.versionGroups.find(g => g.packages.includes(packageName));
    const otherVersions = split.versionGroups
        .filter(g => g !== ownGroup)
        .map(g => `v${g.majorVersion}`)
        .join(', ');
    const ownVersion = ownGroup ? `v${ownGroup.majorVersion}` : '?';
    return `Family conflict: ${packageName} is in the ${split.familyLabel} family on major ${ownVersion}, but other members use major ${otherVersions}`;
}
const VULN_SEVERITY_MAP = {
    'critical': vscode.DiagnosticSeverity.Error,
    'high': vscode.DiagnosticSeverity.Warning,
    'medium': vscode.DiagnosticSeverity.Information,
    'low': vscode.DiagnosticSeverity.Hint,
};
function buildVulnDiagnostic(range, vuln) {
    const fixInfo = vuln.fixedVersion
        ? `. Fixed in ${vuln.fixedVersion}`
        : '';
    const msg = `Security: ${vuln.id} — ${vuln.summary}${fixInfo}`;
    const severity = VULN_SEVERITY_MAP[vuln.severity];
    const diag = new vscode.Diagnostic(range, msg, severity);
    diag.source = 'Saropa Package Vibrancy';
    diag.code = {
        value: vuln.id,
        target: vscode.Uri.parse(vuln.url),
    };
    return diag;
}
//# sourceMappingURL=diagnostics.js.map