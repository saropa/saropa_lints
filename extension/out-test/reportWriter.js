"use strict";
/**
 * Extension report writer — persists an audit trail of extension actions
 * to reports/YYYYMMDD/YYYYMMDD_HHMMSS_saropa_extension.md.
 *
 * Mirrors the Dart init log writer pattern: accumulate lines, flush to file.
 * Report files are written to date-stamped folders under reports/ for external inspection.
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
exports.logReport = logReport;
exports.logSection = logSection;
exports.clearReport = clearReport;
exports.flushReport = flushReport;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
/** Module-level buffer — lines accumulate across logReport() calls until flushed. */
const reportLines = [];
/** Captured on first logReport() call; ensures filename + date folder stay consistent through the session. */
let sessionTimestamp;
function pad2(n) {
    return String(n).padStart(2, '0');
}
function makeTimestamp() {
    const d = new Date();
    return `${d.getFullYear()}${pad2(d.getMonth() + 1)}${pad2(d.getDate())}_${pad2(d.getHours())}${pad2(d.getMinutes())}${pad2(d.getSeconds())}`;
}
/** Extract YYYYMMDD date portion from a YYYYMMDD_HHMMSS timestamp. */
function dateFolderFromTimestamp(ts) {
    return ts.slice(0, 8);
}
/**
 * Append a line to the current report buffer.
 * Lazily captures the session timestamp on first call so the report
 * filename reflects when logging started, not when it was flushed.
 */
function logReport(line) {
    if (!sessionTimestamp)
        sessionTimestamp = makeTimestamp();
    reportLines.push(line);
}
/** Append a markdown section heading. */
function logSection(title) {
    logReport('');
    logReport(`## ${title}`);
}
/** Reset the report buffer. */
function clearReport() {
    reportLines.length = 0;
    sessionTimestamp = undefined;
}
/**
 * Write the accumulated report to disk and clear the buffer.
 * Returns the file path on success, undefined on failure or empty buffer.
 */
function flushReport(root) {
    if (reportLines.length === 0)
        return undefined;
    const ts = sessionTimestamp ?? makeTimestamp();
    // Derive date folder from the session timestamp to avoid midnight boundary mismatch
    // (session started at 23:59 but flushed at 00:01 would write to a different date folder).
    const folder = path.join(root, 'reports', dateFolderFromTimestamp(ts));
    const header = [
        '# Saropa Lints Extension Report',
        `**Date:** ${new Date().toISOString()}`,
        `**Workspace:** ${root}`,
    ];
    const content = [...header, '', ...reportLines, ''].join('\n');
    const filePath = path.join(folder, `${ts}_saropa_extension.md`);
    try {
        // mkdirSync can throw on permission errors or read-only filesystems;
        // recursive:true only suppresses "already exists". Keep both operations
        // in one try block so any disk failure returns undefined gracefully.
        fs.mkdirSync(folder, { recursive: true });
        fs.writeFileSync(filePath, content, 'utf-8');
        clearReport();
        return filePath;
    }
    catch {
        return undefined;
    }
}
//# sourceMappingURL=reportWriter.js.map