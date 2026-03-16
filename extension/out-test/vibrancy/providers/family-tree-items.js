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
exports.FamilySplitItem = exports.FamilyConflictGroupItem = void 0;
exports.buildFamilySplitDetails = buildFamilySplitDetails;
const vscode = __importStar(require("vscode"));
const tree_items_1 = require("./tree-items");
class FamilyConflictGroupItem extends vscode.TreeItem {
    splits;
    constructor(splits) {
        super(`Family Conflicts (${splits.length})`, vscode.TreeItemCollapsibleState.Expanded);
        this.splits = splits;
        this.iconPath = new vscode.ThemeIcon('warning', new vscode.ThemeColor('editorWarning.foreground'));
        this.contextValue = 'vibrancyFamilyConflictGroup';
    }
}
exports.FamilyConflictGroupItem = FamilyConflictGroupItem;
class FamilySplitItem extends vscode.TreeItem {
    split;
    constructor(split) {
        super(`${split.familyLabel} — version split`, vscode.TreeItemCollapsibleState.Collapsed);
        this.split = split;
        this.iconPath = new vscode.ThemeIcon('git-compare', new vscode.ThemeColor('editorWarning.foreground'));
    }
}
exports.FamilySplitItem = FamilySplitItem;
/** Build detail items for a family split node. */
function buildFamilySplitDetails(split) {
    const items = [];
    for (const group of split.versionGroups) {
        items.push(new tree_items_1.DetailItem(`Major v${group.majorVersion}`, group.packages.join(', ')));
    }
    items.push(new tree_items_1.DetailItem('💡 Suggestion', split.suggestion));
    return items;
}
//# sourceMappingURL=family-tree-items.js.map