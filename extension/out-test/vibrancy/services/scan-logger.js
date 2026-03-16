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
exports.ScanLogger = void 0;
const vscode = __importStar(require("vscode"));
/** Accumulates timestamped log entries during a scan for writing to disk. */
class ScanLogger {
    _entries = [];
    _startTime = Date.now();
    /** Append a timestamped entry. */
    log(level, message) {
        const ts = new Date().toISOString();
        this._entries.push(`${ts}  [${level.padEnd(5)}]  ${message}`);
    }
    info(message) { this.log('INFO', message); }
    error(message) { this.log('ERROR', message); }
    cacheHit(key) { this.log('CACHE', `HIT  ${key}`); }
    cacheMiss(key) { this.log('CACHE', `MISS ${key}`); }
    apiRequest(method, url) {
        this.log('API', `${method} ${url}`);
    }
    apiResponse(status, statusText, ms) {
        this.log('API', `${status} ${statusText} (${ms}ms)`);
    }
    score(params) {
        const { name, total, category, rv, eg, pop, pt } = params;
        const ptStr = pt !== undefined ? ` pt=${pt}` : '';
        this.log('SCORE', `${name} → ${total} (${category}) [rv=${rv} eg=${eg} pop=${pop}${ptStr}]`);
    }
    /** Produce the full log content. */
    toLogContent() {
        return this._entries.join('\n') + '\n';
    }
    /** Write accumulated log to reports/yyyymmdd/yyyymmdd_HHmmss_pubspec_vibrancy.log. */
    async writeToFile() {
        const folders = vscode.workspace.workspaceFolders;
        if (!folders || folders.length === 0) {
            return null;
        }
        const now = new Date();
        const dateDir = formatDateDir(now);
        const fileName = `${dateDir}_${formatTime(now)}_pubspec_vibrancy.log`;
        const dirUri = vscode.Uri.joinPath(folders[0].uri, 'reports', dateDir);
        await vscode.workspace.fs.createDirectory(dirUri);
        const fileUri = vscode.Uri.joinPath(dirUri, fileName);
        await vscode.workspace.fs.writeFile(fileUri, Buffer.from(this.toLogContent(), 'utf-8'));
        return fileUri.fsPath;
    }
    get elapsedMs() { return Date.now() - this._startTime; }
}
exports.ScanLogger = ScanLogger;
function formatDateDir(date) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}${m}${d}`;
}
function formatTime(date) {
    const h = String(date.getHours()).padStart(2, '0');
    const min = String(date.getMinutes()).padStart(2, '0');
    const s = String(date.getSeconds()).padStart(2, '0');
    return `${h}${min}${s}`;
}
//# sourceMappingURL=scan-logger.js.map