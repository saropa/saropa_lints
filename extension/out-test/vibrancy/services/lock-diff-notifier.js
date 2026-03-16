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
exports.snapshotVersions = snapshotVersions;
exports.notifyLockDiff = notifyLockDiff;
const vscode = __importStar(require("vscode"));
const lock_diff_1 = require("./lock-diff");
const diff_narrator_1 = require("../scoring/diff-narrator");
let diffOutputChannel = null;
/** Capture current package versions for later comparison. */
function snapshotVersions(results) {
    return new Map(results.map(r => [r.package.name, r.package.version]));
}
/** Show notification if lock versions changed between scans. */
function notifyLockDiff(oldVersions, results) {
    if (oldVersions.size === 0) {
        return;
    }
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    if (!config.get('showLockDiffNotifications', true)) {
        return;
    }
    const newVersions = snapshotVersions(results);
    const diff = (0, lock_diff_1.diffVersionMaps)(oldVersions, newVersions);
    const totalChanges = diff.added.length + diff.removed.length
        + diff.upgraded.length + diff.downgraded.length;
    if (totalChanges === 0) {
        return;
    }
    const summary = (0, diff_narrator_1.summarizeDiff)(diff);
    vscode.window.showInformationMessage(summary, 'View Details')
        .then(choice => {
        if (choice !== 'View Details') {
            return;
        }
        if (!diffOutputChannel) {
            diffOutputChannel = vscode.window.createOutputChannel('Saropa Lock Diff');
        }
        diffOutputChannel.clear();
        diffOutputChannel.appendLine((0, diff_narrator_1.narrateDiff)(diff));
        diffOutputChannel.show(true);
    });
}
//# sourceMappingURL=lock-diff-notifier.js.map