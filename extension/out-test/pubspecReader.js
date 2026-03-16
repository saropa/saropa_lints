"use strict";
/**
 * Read pubspec.yaml for platform and package detection.
 * Used to show "Detected: Riverpod, Flutter" in Config and for triage.
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
exports.hasSaropaLintsDep = hasSaropaLintsDep;
exports.readPubspec = readPubspec;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
/** Package names saropa_lints knows about (matches lib/src/tiers.dart allPackages). */
const KNOWN_PACKAGES = [
    'bloc',
    'provider',
    'riverpod',
    'getx',
    'flutter_hooks',
    'equatable',
    'freezed',
    'firebase',
    'isar',
    'hive',
    'shared_preferences',
    'sqflite',
    'drift',
    'dio',
    'graphql',
    'supabase',
    'get_it',
    'workmanager',
    'url_launcher',
    'geolocator',
    'qr_scanner',
    'flame',
];
/** Pubspec dependency name → saropa_lints package name. */
const DEP_ALIASES = {
    bloc: 'bloc',
    flutter_bloc: 'bloc',
    get: 'getx',
    getx: 'getx',
    firebase_core: 'firebase',
    firebase_auth: 'firebase',
    cloud_firestore: 'firebase',
    firebase_storage: 'firebase',
    firebase_messaging: 'firebase',
    firebase_analytics: 'firebase',
    mobile_scanner: 'qr_scanner',
    qr_code_scanner: 'qr_scanner',
};
/**
 * Check whether saropa_lints appears in pubspec.yaml dependencies or
 * dev_dependencies. Used to auto-enable the extension when the package
 * is already present — no files are modified.
 */
function hasSaropaLintsDep(workspaceRoot) {
    const pubspecPath = path.join(workspaceRoot, 'pubspec.yaml');
    if (!fs.existsSync(pubspecPath))
        return false;
    try {
        const content = fs.readFileSync(pubspecPath, 'utf-8');
        // Match "saropa_lints:" as a dependency entry (indented under a deps block).
        return /^\s+saropa_lints:/m.test(content);
    }
    catch {
        return false;
    }
}
/**
 * Read and parse pubspec.yaml in workspace root.
 * Returns default (isFlutter: false, packages: [], platforms: []) if file missing or invalid.
 */
function readPubspec(workspaceRoot) {
    const pubspecPath = path.join(workspaceRoot, 'pubspec.yaml');
    if (!fs.existsSync(pubspecPath)) {
        return { isFlutter: false, packages: [], platforms: [] };
    }
    try {
        const content = fs.readFileSync(pubspecPath, 'utf-8');
        const isFlutter = /flutter:\s*$/m.test(content) ||
            content.includes('sdk: flutter') ||
            content.includes('flutter_test:');
        const depNames = new Set();
        const depRegex = /^\s+(\w+):/gm;
        let m;
        while ((m = depRegex.exec(content)) !== null) {
            depNames.add(m[1]);
        }
        const packages = [];
        const seen = new Set();
        for (const pkg of KNOWN_PACKAGES) {
            if (seen.has(pkg))
                continue;
            const aliases = Object.entries(DEP_ALIASES)
                .filter(([, v]) => v === pkg)
                .map(([k]) => k);
            const names = aliases.length > 0 ? aliases : [pkg];
            if (names.some((name) => depNames.has(name))) {
                packages.push(pkg);
                seen.add(pkg);
            }
        }
        const platforms = isFlutter ? ['ios', 'android'] : [];
        return { isFlutter, packages, platforms };
    }
    catch {
        return { isFlutter: false, packages: [], platforms: [] };
    }
}
//# sourceMappingURL=pubspecReader.js.map