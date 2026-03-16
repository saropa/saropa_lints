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
exports.AdoptionGateProvider = void 0;
exports.findCandidates = findCandidates;
const vscode = __importStar(require("vscode"));
const pubspec_parser_1 = require("../services/pubspec-parser");
const pub_dev_api_1 = require("../services/pub-dev-api");
const known_issues_1 = require("../scoring/known-issues");
const adoption_classifier_1 = require("../scoring/adoption-classifier");
const extension_activation_1 = require("../extension-activation");
const DEBOUNCE_MS = 1500;
const TIER_COLORS = {
    healthy: 'green',
    caution: 'orange',
    warning: 'red',
    unknown: 'gray',
};
class AdoptionGateProvider {
    _cache;
    _decorationTypes = new Map();
    _disposables = [];
    _debounceTimer = null;
    _pendingNames = new Set();
    constructor(_cache) {
        this._cache = _cache;
        for (const tier of Object.keys(TIER_COLORS)) {
            this._decorationTypes.set(tier, createDecorationType(tier));
        }
    }
    /** Register listeners and push subscriptions to context. */
    register(context) {
        this._disposables.push(vscode.workspace.onDidChangeTextDocument(e => {
            if (isPubspecYaml(e.document)) {
                this._scheduleCheck(e.document);
            }
        }), vscode.window.onDidChangeActiveTextEditor(editor => {
            if (!editor || !isPubspecYaml(editor.document)) {
                this.clearDecorations();
            }
        }));
        context.subscriptions.push(this);
    }
    /** Clear all adoption gate decorations. */
    clearDecorations() {
        const editor = vscode.window.activeTextEditor;
        if (!editor) {
            return;
        }
        for (const dt of this._decorationTypes.values()) {
            editor.setDecorations(dt, []);
        }
    }
    dispose() {
        if (this._debounceTimer) {
            clearTimeout(this._debounceTimer);
        }
        for (const dt of this._decorationTypes.values()) {
            dt.dispose();
        }
        for (const d of this._disposables) {
            d.dispose();
        }
    }
    _scheduleCheck(document) {
        if (!isEnabled()) {
            return;
        }
        if (this._debounceTimer) {
            clearTimeout(this._debounceTimer);
        }
        this._debounceTimer = setTimeout(() => this._runCheck(document), DEBOUNCE_MS);
    }
    async _runCheck(document) {
        const candidates = findCandidates(document.getText());
        if (candidates.length === 0) {
            this.clearDecorations();
            return;
        }
        const results = await Promise.all(candidates.map(name => this._classifyCandidate(name)));
        this._applyDecorations(document, candidates, results);
    }
    async _classifyCandidate(name) {
        if (this._pendingNames.has(name)) {
            return { tier: 'unknown', badgeText: '...', detail: 'Checking...' };
        }
        this._pendingNames.add(name);
        try {
            return await fetchAndClassify(name, this._cache);
        }
        finally {
            this._pendingNames.delete(name);
        }
    }
    _applyDecorations(document, candidates, results) {
        const editor = vscode.window.activeTextEditor;
        if (!editor || editor.document !== document) {
            return;
        }
        const grouped = groupByTier(candidates, results, document);
        for (const [tier, dt] of this._decorationTypes) {
            editor.setDecorations(dt, grouped.get(tier) ?? []);
        }
    }
}
exports.AdoptionGateProvider = AdoptionGateProvider;
function createDecorationType(tier) {
    return vscode.window.createTextEditorDecorationType({
        after: {
            margin: '0 0 0 2em',
            color: new vscode.ThemeColor(tier === 'healthy' ? 'charts.green'
                : tier === 'caution' ? 'charts.yellow'
                    : tier === 'warning' ? 'charts.red'
                        : 'disabledForeground'),
        },
        isWholeLine: false,
    });
}
/** Find package names in yaml that are not yet in scan results. */
function findCandidates(content) {
    const parsed = (0, pubspec_parser_1.parsePubspecYaml)(content);
    const allNames = [...parsed.directDeps, ...parsed.devDeps];
    const resolved = new Set((0, extension_activation_1.getLatestResults)().map(r => r.package.name));
    return allNames.filter(name => !resolved.has(name));
}
async function fetchAndClassify(name, cache) {
    const [info, metrics, publisher] = await Promise.all([
        (0, pub_dev_api_1.fetchPackageInfo)(name, cache),
        (0, pub_dev_api_1.fetchPackageMetrics)(name, cache),
        (0, pub_dev_api_1.fetchPublisher)(name, cache),
    ]);
    const knownIssue = (0, known_issues_1.findKnownIssue)(name);
    return (0, adoption_classifier_1.classifyAdoption)({
        pubPoints: metrics.pubPoints,
        verifiedPublisher: publisher !== null,
        isDiscontinued: info?.isDiscontinued ?? false,
        knownIssueStatus: knownIssue?.status ?? null,
        knownIssueReason: knownIssue?.reason ?? null,
        exists: info !== null,
    });
}
function groupByTier(candidates, results, document) {
    const grouped = new Map();
    const content = document.getText();
    const lines = content.split('\n');
    for (let i = 0; i < candidates.length; i++) {
        const lineIdx = findPackageLine(lines, candidates[i]);
        if (lineIdx < 0) {
            continue;
        }
        const result = results[i];
        const lineEnd = lines[lineIdx].length;
        const range = new vscode.Range(lineIdx, 0, lineIdx, lineEnd);
        const decoration = {
            range,
            renderOptions: {
                after: { contentText: `  ${result.badgeText}` },
            },
            hoverMessage: new vscode.MarkdownString(result.detail),
        };
        const list = grouped.get(result.tier) ?? [];
        list.push(decoration);
        grouped.set(result.tier, list);
    }
    return grouped;
}
function findPackageLine(lines, name) {
    const pattern = new RegExp(`^\\s{2}${name}\\s*:`);
    return lines.findIndex(line => pattern.test(line));
}
function isPubspecYaml(document) {
    return document.fileName.endsWith('pubspec.yaml');
}
function isEnabled() {
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    return config.get('enableAdoptionGate', true);
}
//# sourceMappingURL=adoption-gate.js.map