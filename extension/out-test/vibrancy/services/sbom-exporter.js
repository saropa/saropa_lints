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
exports.exportSbomReport = exportSbomReport;
const vscode = __importStar(require("vscode"));
const sbom_generator_1 = require("./sbom-generator");
const report_utils_1 = require("./report-utils");
/** Export SBOM to a timestamped file in the report/ directory. */
async function exportSbomReport(results, extensionVersion) {
    const folder = await (0, report_utils_1.resolveReportFolder)();
    if (!folder) {
        return null;
    }
    const meta = await readProjectMeta(extensionVersion);
    const bom = (0, sbom_generator_1.generateSbom)(results, meta);
    const content = (0, sbom_generator_1.serializeSbom)(bom);
    const timestamp = (0, report_utils_1.formatTimestamp)(new Date());
    const uri = vscode.Uri.joinPath(folder, `${timestamp}_sbom.cdx.json`);
    await vscode.workspace.fs.writeFile(uri, Buffer.from(content, 'utf-8'));
    return uri.fsPath;
}
async function readProjectMeta(extensionVersion) {
    const files = await vscode.workspace.findFiles('**/pubspec.yaml', '**/.*/**', 1);
    if (files.length === 0) {
        return {
            projectName: 'unknown',
            projectVersion: '0.0.0',
            extensionVersion,
        };
    }
    const bytes = await vscode.workspace.fs.readFile(files[0]);
    const text = Buffer.from(bytes).toString('utf-8');
    return {
        projectName: extractYamlField(text, 'name') ?? 'unknown',
        projectVersion: extractYamlField(text, 'version') ?? '0.0.0',
        extensionVersion,
    };
}
function extractYamlField(text, field) {
    const re = new RegExp(`^${field}:\\s*(.+)$`, 'm');
    const match = re.exec(text);
    if (!match) {
        return null;
    }
    return match[1].trim().replace(/^(['"])(.+)\1$/, '$2');
}
//# sourceMappingURL=sbom-exporter.js.map