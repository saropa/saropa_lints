"use strict";
/**
 * Code Lens provider for Dart files: shows "Saropa Lints: N issues — Show in Saropa"
 * above the first line when the file has violations. Click focuses the Issues view filtered to this file.
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
exports.invalidateCodeLenses = invalidateCodeLenses;
exports.registerCodeLensProvider = registerCodeLensProvider;
const vscode = __importStar(require("vscode"));
const path = __importStar(require("path"));
const pathUtils_1 = require("./pathUtils");
const violationsReader_1 = require("./violationsReader");
const projectRoot_1 = require("./projectRoot");
let codeLensChangeEmitter;
/** Call when violations.json changes so Code Lenses refresh. */
function invalidateCodeLenses() {
    codeLensChangeEmitter?.fire();
}
function registerCodeLensProvider(context) {
    codeLensChangeEmitter = new vscode.EventEmitter();
    context.subscriptions.push(codeLensChangeEmitter);
    const provider = {
        onDidChangeCodeLenses: codeLensChangeEmitter.event,
        provideCodeLenses(document, _token) {
            const root = (0, projectRoot_1.getProjectRoot)();
            if (!root || document.languageId !== 'dart')
                return [];
            const data = (0, violationsReader_1.readViolations)(root);
            if (!data?.violations?.length)
                return [];
            const docPath = document.uri.fsPath;
            const relativePath = (0, pathUtils_1.normalizePath)(path.relative(root, docPath));
            const fileViolations = data.violations.filter((v) => (0, pathUtils_1.normalizePath)(v.file) === relativePath);
            const count = fileViolations.length;
            if (count === 0)
                return [];
            // H4: Show critical count when present.
            const critical = fileViolations.filter((v) => v.impact === 'critical').length;
            const suffix = critical > 0 ? ` (${critical} critical)` : '';
            const issueText = count === 1 ? '1 issue' : `${count} issues`;
            const lens = new vscode.CodeLens(new vscode.Range(0, 0, 0, 0), {
                title: `Saropa: ${issueText}${suffix} \u2014 Show in Saropa`,
                command: 'saropaLints.focusIssuesForFile',
                arguments: [relativePath],
            });
            return [lens];
        },
    };
    context.subscriptions.push(vscode.languages.registerCodeLensProvider({ language: 'dart' }, provider));
}
//# sourceMappingURL=codeLensProvider.js.map