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
exports.getGithubToken = getGithubToken;
exports.getCacheTtlHours = getCacheTtlHours;
exports.getScanOnOpen = getScanOnOpen;
exports.getIncludeDevDependencies = getIncludeDevDependencies;
exports.getIncludeOverriddenPackages = getIncludeOverriddenPackages;
exports.getAllowlist = getAllowlist;
exports.getAllowlistSet = getAllowlistSet;
exports.getRepoOverrides = getRepoOverrides;
exports.getScoringWeights = getScoringWeights;
exports.getPublisherTrustBonus = getPublisherTrustBonus;
exports.getEnableCodeLens = getEnableCodeLens;
exports.getEnableAdoptionGate = getEnableAdoptionGate;
exports.getCodeLensDetail = getCodeLensDetail;
exports.getTreeGrouping = getTreeGrouping;
exports.getEndOfLifeDiagnostics = getEndOfLifeDiagnostics;
exports.getSuppressedPackages = getSuppressedPackages;
exports.addSuppressedPackage = addSuppressedPackage;
exports.removeSuppressedPackage = removeSuppressedPackage;
exports.addSuppressedPackages = addSuppressedPackages;
exports.clearSuppressedPackages = clearSuppressedPackages;
exports.getSuppressedSet = getSuppressedSet;
exports.getShowLockDiffNotifications = getShowLockDiffNotifications;
exports.getFreshnessWatchEnabled = getFreshnessWatchEnabled;
exports.getFreshnessWatchIntervalHours = getFreshnessWatchIntervalHours;
exports.getFreshnessWatchFilter = getFreshnessWatchFilter;
exports.getFreshnessWatchCustomPackages = getFreshnessWatchCustomPackages;
exports.getAnnotationWithSectionHeaders = getAnnotationWithSectionHeaders;
exports.getVulnScanEnabled = getVulnScanEnabled;
exports.getVulnSeverityThreshold = getVulnSeverityThreshold;
exports.getGitHubAdvisoryEnabled = getGitHubAdvisoryEnabled;
const vscode = __importStar(require("vscode"));
/**
 * Centralized configuration service.
 * Provides typed access to all extension settings.
 */
const SECTION = 'saropaLints.packageVibrancy';
function getConfig() {
    return vscode.workspace.getConfiguration(SECTION);
}
// --- GitHub & API Settings ---
function getGithubToken() {
    return getConfig().get('githubToken', '');
}
function getCacheTtlHours() {
    return getConfig().get('cacheTtlHours', 24);
}
// --- Scan Settings ---
function getScanOnOpen() {
    return getConfig().get('scanOnOpen', true);
}
function getIncludeDevDependencies() {
    return getConfig().get('includeDevDependencies', true);
}
function getIncludeOverriddenPackages() {
    return getConfig().get('includeOverriddenPackages', true);
}
function getAllowlist() {
    return getConfig().get('allowlist', []);
}
function getAllowlistSet() {
    return new Set(getAllowlist());
}
function getRepoOverrides() {
    return getConfig().get('repoOverrides', {});
}
// --- Scoring Weights ---
function getScoringWeights() {
    const config = getConfig();
    return {
        resolutionVelocity: config.get('weights.resolutionVelocity', 0.5),
        engagementLevel: config.get('weights.engagementLevel', 0.4),
        popularity: config.get('weights.popularity', 0.1),
    };
}
function getPublisherTrustBonus() {
    return getConfig().get('publisherTrustBonus', 15);
}
// --- UI Settings ---
function getEnableCodeLens() {
    return getConfig().get('enableCodeLens', true);
}
function getEnableAdoptionGate() {
    return getConfig().get('enableAdoptionGate', true);
}
function getCodeLensDetail() {
    return getConfig().get('codeLensDetail', 'standard');
}
function getTreeGrouping() {
    return getConfig().get('treeGrouping', 'none');
}
function getEndOfLifeDiagnostics() {
    return getConfig().get('endOfLifeDiagnostics', 'none');
}
// --- Suppression Settings ---
function getSuppressedPackages() {
    return getConfig().get('suppressedPackages', []);
}
async function addSuppressedPackage(packageName) {
    const config = getConfig();
    const current = config.get('suppressedPackages', []);
    if (current.includes(packageName)) {
        return;
    }
    await config.update('suppressedPackages', [...current, packageName], vscode.ConfigurationTarget.Workspace);
}
async function removeSuppressedPackage(packageName) {
    const config = getConfig();
    const current = config.get('suppressedPackages', []);
    await config.update('suppressedPackages', current.filter(n => n !== packageName), vscode.ConfigurationTarget.Workspace);
}
async function addSuppressedPackages(packageNames) {
    const config = getConfig();
    const current = new Set(config.get('suppressedPackages', []));
    const toAdd = packageNames.filter(name => !current.has(name));
    if (toAdd.length === 0) {
        return 0;
    }
    await config.update('suppressedPackages', [...current, ...toAdd], vscode.ConfigurationTarget.Workspace);
    return toAdd.length;
}
async function clearSuppressedPackages() {
    const config = getConfig();
    const current = config.get('suppressedPackages', []);
    const count = current.length;
    if (count === 0) {
        return 0;
    }
    await config.update('suppressedPackages', [], vscode.ConfigurationTarget.Workspace);
    return count;
}
function getSuppressedSet() {
    return new Set(getSuppressedPackages());
}
// --- Notification Settings ---
function getShowLockDiffNotifications() {
    return getConfig().get('showLockDiffNotifications', true);
}
// --- Freshness Watch Settings ---
function getFreshnessWatchEnabled() {
    return getConfig().get('freshnessWatch.enabled', false);
}
function getFreshnessWatchIntervalHours() {
    return getConfig().get('freshnessWatch.intervalHours', 4);
}
function getFreshnessWatchFilter() {
    return getConfig().get('freshnessWatch.filter', 'all');
}
function getFreshnessWatchCustomPackages() {
    return getConfig().get('freshnessWatch.customPackages', []);
}
// --- Annotation Settings ---
function getAnnotationWithSectionHeaders() {
    return getConfig().get('annotateWithSectionHeaders', false);
}
function getVulnScanEnabled() {
    return getConfig().get('enableVulnScan', true);
}
function getVulnSeverityThreshold() {
    return getConfig().get('vulnSeverityThreshold', 'low');
}
function getGitHubAdvisoryEnabled() {
    return getConfig().get('enableGitHubAdvisory', true);
}
//# sourceMappingURL=config-service.js.map