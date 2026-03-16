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
exports.readScanConfig = readScanConfig;
exports.scanPackages = scanPackages;
exports.buildScanMeta = buildScanMeta;
exports.findAndParseDeps = findAndParseDeps;
const vscode = __importStar(require("vscode"));
const pubspec_parser_1 = require("./services/pubspec-parser");
const scan_orchestrator_1 = require("./scan-orchestrator");
const sdk_detector_1 = require("./services/sdk-detector");
const config_service_1 = require("./services/config-service");
function readScanConfig() {
    return {
        token: (0, config_service_1.getGithubToken)(),
        allowSet: (0, config_service_1.getAllowlistSet)(),
        weights: (0, config_service_1.getScoringWeights)(),
        repoOverrides: (0, config_service_1.getRepoOverrides)(),
        publisherTrustBonus: (0, config_service_1.getPublisherTrustBonus)(),
    };
}
const CONCURRENCY = 3;
async function scanPackages(deps, cache, scanConfig, progress) {
    const results = new Array(deps.length);
    let completed = 0;
    let cursor = 0;
    async function next() {
        while (cursor < deps.length) {
            const idx = cursor++;
            const dep = deps[idx];
            scanConfig.logger?.info(`[${idx + 1}/${deps.length}] ${dep.name}`);
            results[idx] = await (0, scan_orchestrator_1.analyzePackage)(dep, {
                cache, logger: scanConfig.logger,
                githubToken: scanConfig.token || undefined,
                weights: scanConfig.weights,
                repoOverrides: scanConfig.repoOverrides,
                publisherTrustBonus: scanConfig.publisherTrustBonus,
                flutterReleases: scanConfig.flutterReleases,
            });
            completed++;
            progress.report({
                message: `${dep.name} (${completed}/${deps.length})`,
                increment: 100 / deps.length,
            });
        }
    }
    const workers = Array.from({ length: Math.min(CONCURRENCY, deps.length) }, () => next());
    await Promise.all(workers);
    return results;
}
async function buildScanMeta(startTime) {
    const [flutterVer, dartVer] = await Promise.all([
        (0, sdk_detector_1.detectFlutterVersion)(), (0, sdk_detector_1.detectDartVersion)(),
    ]);
    return {
        flutterVersion: flutterVer,
        dartVersion: dartVer,
        executionTimeMs: Date.now() - startTime,
    };
}
/** Check if a dependency source should be included in the scan. */
function isScannableSource(source, includeOverridden) {
    if (source === 'hosted') {
        return true;
    }
    if (includeOverridden && (source === 'path' || source === 'git')) {
        return true;
    }
    return false;
}
/**
 * Find pubspec.yaml + pubspec.lock, preferring workspace root.
 * Falls back to recursive search for monorepo / nested project layouts.
 */
async function findPubspecPair() {
    const folders = vscode.workspace.workspaceFolders;
    if (folders) {
        for (const folder of folders) {
            const yaml = vscode.Uri.joinPath(folder.uri, 'pubspec.yaml');
            const lock = vscode.Uri.joinPath(folder.uri, 'pubspec.lock');
            try {
                await Promise.all([
                    vscode.workspace.fs.stat(yaml),
                    vscode.workspace.fs.stat(lock),
                ]);
                return { yaml, lock };
            }
            catch {
                continue;
            }
        }
    }
    const [yamlFiles, lockFiles] = await Promise.all([
        vscode.workspace.findFiles('**/pubspec.yaml', '**/.*/**', 1),
        vscode.workspace.findFiles('**/pubspec.lock', '**/.*/**', 1),
    ]);
    if (yamlFiles.length === 0 || lockFiles.length === 0) {
        return null;
    }
    return { yaml: yamlFiles[0], lock: lockFiles[0] };
}
async function findAndParseDeps() {
    const pair = await findPubspecPair();
    if (!pair) {
        return null;
    }
    const [yamlBytes, lockBytes] = await Promise.all([
        vscode.workspace.fs.readFile(pair.yaml),
        vscode.workspace.fs.readFile(pair.lock),
    ]);
    const yamlContent = Buffer.from(yamlBytes).toString('utf8');
    const lockContent = Buffer.from(lockBytes).toString('utf8');
    const includeDevDeps = (0, config_service_1.getIncludeDevDependencies)();
    const includeOverridden = (0, config_service_1.getIncludeOverriddenPackages)();
    const { directDeps, devDeps, constraints } = (0, pubspec_parser_1.parsePubspecYaml)(yamlContent);
    const effectiveDevDeps = includeDevDeps ? devDeps : [];
    const deps = (0, pubspec_parser_1.parsePubspecLock)(lockContent, directDeps, constraints, effectiveDevDeps)
        .filter(d => d.isDirect && isScannableSource(d.source, includeOverridden));
    return { deps, yamlUri: pair.yaml, yamlContent };
}
//# sourceMappingURL=scan-helpers.js.map