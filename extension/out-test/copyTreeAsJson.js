"use strict";
/**
 * Shared utility for copying tree nodes (with recursive children) as structured JSON.
 * Used by all tree views in the extension to support "Copy as JSON" context menu actions.
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
exports.copyTreeNodesToClipboard = copyTreeNodesToClipboard;
const vscode = __importStar(require("vscode"));
/**
 * Recursively serialize a tree node and its children into a JsonNode.
 * @param node - The tree node to serialize.
 * @param serialize - View-specific function that converts a node to a JsonNode (without children).
 * @param getChildren - The provider's getChildren bound to resolve child nodes.
 */
async function serializeNode(node, serialize, getChildren) {
    const json = serialize(node);
    if (!json)
        return null;
    const children = await getChildren(node);
    if (children.length > 0) {
        const serializedChildren = [];
        for (const child of children) {
            const childJson = await serializeNode(child, serialize, getChildren);
            if (childJson)
                serializedChildren.push(childJson);
        }
        if (serializedChildren.length > 0) {
            json.children = serializedChildren;
        }
    }
    return json;
}
/**
 * Copy one or more tree nodes (with children) to the clipboard as structured JSON.
 * Handles both single-click and multi-select via the VS Code command argument convention:
 * first arg is the clicked item, second arg is the full selection array (if multi-select).
 *
 * @param item - The right-clicked tree item (first command arg).
 * @param selectedItems - All selected items (second command arg, when multi-select is active).
 * @param serialize - View-specific serializer (node → JsonNode without children).
 * @param getChildren - The provider's getChildren method.
 * @param viewLabel - Human-readable view name for the info message.
 */
async function copyTreeNodesToClipboard(item, selectedItems, serialize, getChildren, viewLabel) {
    // Resolve the set of nodes: prefer multi-select array, fall back to single item.
    const nodes = Array.isArray(selectedItems) && selectedItems.length > 0
        ? selectedItems
        : (item ? [item] : []);
    if (nodes.length === 0) {
        vscode.window.showWarningMessage('No tree item selected.');
        return;
    }
    const results = [];
    for (const node of nodes) {
        const json = await serializeNode(node, serialize, getChildren);
        if (json)
            results.push(json);
    }
    if (results.length === 0) {
        vscode.window.showWarningMessage('Could not serialize the selected item(s).');
        return;
    }
    // Single node → object; multiple nodes → array.
    const output = results.length === 1 ? results[0] : results;
    const json = JSON.stringify(output, null, 2);
    await vscode.env.clipboard.writeText(json);
    const count = results.length;
    const noun = count === 1 ? 'node' : 'nodes';
    vscode.window.showInformationMessage(`Copied ${count} ${viewLabel} ${noun} to clipboard as JSON`);
}
//# sourceMappingURL=copyTreeAsJson.js.map