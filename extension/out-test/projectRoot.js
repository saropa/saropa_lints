"use strict";
/**
 * Centralized project root discovery.
 *
 * The "project root" is the directory containing pubspec.yaml, which may
 * differ from the VS Code workspace root when the Dart project lives in
 * a subdirectory (e.g. `game/pubspec.yaml`).
 *
 * All Dart-related operations (commands, violations, config files) should
 * use getProjectRoot(). Only VS Code-level operations (configuration,
 * workspace state) should use getWorkspaceRoot().
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
exports.getWorkspaceRoot = getWorkspaceRoot;
exports.getProjectRoot = getProjectRoot;
exports.invalidateProjectRoot = invalidateProjectRoot;
const vscode = __importStar(require("vscode"));
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
/**
 * Directories to skip when scanning one level deep for pubspec.yaml.
 * Hidden directories (starting with '.') are skipped separately.
 */
const SKIP_DIRS = new Set([
    'android',
    'build',
    'coverage',
    'doc',
    'docs',
    'example',
    'integration_test',
    'ios',
    'linux',
    'macos',
    'node_modules',
    'reports',
    'scripts',
    'test',
    'web',
    'windows',
]);
// null = not yet searched; undefined = searched, not found; string = found
let cachedProjectRoot = null;
/** Get the VS Code workspace root (first workspace folder). */
function getWorkspaceRoot() {
    return vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
}
/**
 * Discover the Dart project root — the directory containing pubspec.yaml.
 * Checks workspace root first, then immediate subdirectories (one level).
 * Result is cached per session.
 */
function getProjectRoot() {
    if (cachedProjectRoot !== null)
        return cachedProjectRoot;
    const wsRoot = getWorkspaceRoot();
    if (!wsRoot) {
        cachedProjectRoot = undefined;
        return undefined;
    }
    // Common case: pubspec.yaml at workspace root.
    if (fs.existsSync(path.join(wsRoot, 'pubspec.yaml'))) {
        cachedProjectRoot = wsRoot;
        return wsRoot;
    }
    // Search one level deep for a subdirectory containing pubspec.yaml.
    try {
        const entries = fs.readdirSync(wsRoot, { withFileTypes: true });
        for (const entry of entries) {
            if (!entry.isDirectory())
                continue;
            if (entry.name.startsWith('.') || SKIP_DIRS.has(entry.name))
                continue;
            const candidate = path.join(wsRoot, entry.name);
            if (fs.existsSync(path.join(candidate, 'pubspec.yaml'))) {
                cachedProjectRoot = candidate;
                return candidate;
            }
        }
    }
    catch {
        // Permission error or similar — fall through.
    }
    cachedProjectRoot = undefined;
    return undefined;
}
/** Clear cached project root. Call if workspace structure changes. */
function invalidateProjectRoot() {
    cachedProjectRoot = null;
}
//# sourceMappingURL=projectRoot.js.map