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
exports.scanDartImports = scanDartImports;
const vscode = __importStar(require("vscode"));
const IMPORT_PATTERN = /import\s+['"]package:(\w+)\//g;
/**
 * Scan Dart source files for package import statements.
 * Returns the set of package names that appear in any import.
 */
async function scanDartImports(workspaceRoot) {
    const pattern = new vscode.RelativePattern(workspaceRoot, '{lib,bin,test}/**/*.dart');
    const files = await vscode.workspace.findFiles(pattern);
    const imported = new Set();
    const contents = await Promise.all(files.map(f => vscode.workspace.fs.readFile(f)));
    for (const bytes of contents) {
        collectImports(Buffer.from(bytes).toString('utf8'), imported);
    }
    return imported;
}
function collectImports(content, out) {
    const re = new RegExp(IMPORT_PATTERN.source, 'g');
    let match;
    while ((match = re.exec(content)) !== null) {
        out.add(match[1]);
    }
}
//# sourceMappingURL=import-scanner.js.map