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
exports.VibrancyCodeLensProvider = void 0;
exports.setCodeLensToggle = setCodeLensToggle;
exports.setPrereleaseToggle = setPrereleaseToggle;
const vscode = __importStar(require("vscode"));
const pubspec_parser_1 = require("../services/pubspec-parser");
const prerelease_toggle_1 = require("../ui/prerelease-toggle");
const indicator_config_1 = require("../services/indicator-config");
const status_classifier_1 = require("../scoring/status-classifier");
const prerelease_classifier_1 = require("../scoring/prerelease-classifier");
const known_issues_1 = require("../scoring/known-issues");
let globalToggle = null;
let globalPrereleaseToggle = null;
/** Set the global toggle instance (called from extension-activation). */
function setCodeLensToggle(toggle) {
    globalToggle = toggle;
}
/** Set the global prerelease toggle instance (called from extension-activation). */
function setPrereleaseToggle(toggle) {
    globalPrereleaseToggle = toggle;
}
class VibrancyCodeLensProvider {
    _results = new Map();
    _onDidChange = new vscode.EventEmitter();
    onDidChangeCodeLenses = this._onDidChange.event;
    updateResults(results) {
        this._results.clear();
        for (const r of results) {
            this._results.set(r.package.name, r);
        }
        this._onDidChange.fire();
    }
    /** Refresh CodeLens display (called when toggle changes). */
    refresh() {
        this._onDidChange.fire();
    }
    provideCodeLenses(document) {
        if (!isEnabled()) {
            return [];
        }
        if (!document.fileName.endsWith('pubspec.yaml')) {
            return [];
        }
        if (this._results.size === 0) {
            return [];
        }
        const content = document.getText();
        const detail = readDetailLevel();
        const pubspecPath = document.uri.fsPath;
        return buildLenses(content, this._results, detail, pubspecPath);
    }
    dispose() {
        this._onDidChange.dispose();
    }
}
exports.VibrancyCodeLensProvider = VibrancyCodeLensProvider;
function buildLenses(content, results, detail, pubspecPath) {
    const lenses = [];
    for (const [name, result] of results) {
        const pkgRange = (0, pubspec_parser_1.findPackageRange)(content, name);
        if (!pkgRange) {
            continue;
        }
        const range = new vscode.Range(pkgRange.line, pkgRange.startChar, pkgRange.line, pkgRange.endChar);
        lenses.push(...buildLensesForPackage(result, range, detail, pubspecPath));
    }
    return lenses;
}
function buildLensesForPackage(result, range, detail, pubspecPath) {
    const lenses = [];
    const name = result.package.name;
    lenses.push(new vscode.CodeLens(range, {
        title: formatStatusTitle(result, detail),
        command: 'saropaLints.packageVibrancy.focusPackageInTree',
        arguments: [name],
    }));
    const latestVersion = result.updateInfo?.latestVersion;
    const hasUpdate = latestVersion
        && result.updateInfo?.updateStatus !== 'up-to-date';
    if (hasUpdate) {
        const args = {
            packageName: name,
            targetVersion: latestVersion,
            pubspecPath,
        };
        lenses.push(new vscode.CodeLens(range, {
            title: `→ ${latestVersion}`,
            command: 'saropaLints.packageVibrancy.updateFromCodeLens',
            arguments: [args],
        }));
    }
    if (isPrereleaseEnabled() && result.latestPrerelease) {
        const tagFilter = (0, prerelease_toggle_1.getPrereleaseTagFilter)();
        const tag = result.prereleaseTag;
        const passesFilter = tagFilter.length === 0
            || (tag && tagFilter.some(f => f.toLowerCase() === tag.toLowerCase()));
        if (passesFilter) {
            const displayTag = (0, prerelease_classifier_1.formatPrereleaseTag)(tag);
            const args = {
                packageName: name,
                targetVersion: result.latestPrerelease,
                pubspecPath,
            };
            lenses.push(new vscode.CodeLens(range, {
                title: `🧪 ${result.latestPrerelease} (${displayTag})`,
                command: 'saropaLints.packageVibrancy.updateFromCodeLens',
                arguments: [args],
            }));
        }
    }
    return lenses;
}
function isPrereleaseEnabled() {
    if (globalPrereleaseToggle) {
        return globalPrereleaseToggle.isEnabled;
    }
    return (0, prerelease_toggle_1.arePrereleasesEnabled)();
}
function formatStatusTitle(result, detail) {
    const indicator = (0, indicator_config_1.getCategoryIndicator)(result.category);
    const displayScore = Math.round(result.score / 10);
    const label = (0, status_classifier_1.categoryLabel)(result.category);
    let title = `${indicator} ${displayScore}/10 ${label}`;
    if (detail === 'minimal') {
        return title;
    }
    if (result.isUnused) {
        title += ` · ${(0, indicator_config_1.getIndicator)('unused')} Unused`;
    }
    if (detail === 'full') {
        const replacement = result.knownIssue?.replacement;
        const displayReplacement = replacement
            ? (0, known_issues_1.getReplacementDisplayText)(replacement, result.package.version, result.knownIssue?.replacementObsoleteFromVersion)
            : undefined;
        if (displayReplacement) {
            const label = (0, known_issues_1.isReplacementPackageName)(displayReplacement)
                ? `Replace with ${displayReplacement}`
                : `Consider: ${displayReplacement}`;
            title += ` · ${(0, indicator_config_1.getIndicator)('warning')} ${label}`;
        }
        else if (result.knownIssue?.reason) {
            title += ` · ${(0, indicator_config_1.getIndicator)('warning')} Known issue`;
        }
    }
    return title;
}
function isEnabled() {
    if (globalToggle) {
        return globalToggle.isEnabled;
    }
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    return config.get('enableCodeLens', true);
}
function readDetailLevel() {
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const level = config.get('codeLensDetail', 'standard');
    if (level === 'minimal' || level === 'full') {
        return level;
    }
    return 'standard';
}
//# sourceMappingURL=codelens-provider.js.map