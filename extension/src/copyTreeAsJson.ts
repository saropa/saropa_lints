/**
 * Shared utility for copying tree views to the clipboard as formatted JSON.
 *
 * **VS Code command contract:** tree context-menu commands receive `(clickedItem, selectedItems?)`.
 * When the hosting `TreeView` has `canSelectMany: true` and the user selects multiple rows,
 * `selectedItems` is a non-empty array and must take precedence over `clickedItem` alone.
 * The Violations (`saropaLints.issues`) view sets `canSelectMany` in `extension.ts` specifically
 * so this path is reachable from the UI.
 *
 * **Output shape:** one serialized root → a single JSON object; multiple roots → a JSON array.
 * Each node is serialized recursively (see `serializeNode`) so exporting a file row includes its
 * violation children as nested `children` when the provider returns them from `getChildren`.
 *
 * **Scale:** large selections can produce very large clipboard payloads; direct consumers should
 * prefer `reports/.saropa_lints/violations.json` for full-repo exports.
 */

import * as vscode from 'vscode';
import { resolveNodesForJsonExport } from './copyTreeAsJsonSelection';

/** Uniform JSON envelope for any tree node. */
export interface JsonNode {
    type: string;
    label: string;
    description?: string;
    data?: Record<string, unknown>;
    children?: JsonNode[];
}

/**
 * Recursively serialize a tree node and its children into a JsonNode.
 * @param node - The tree node to serialize.
 * @param serialize - View-specific function that converts a node to a JsonNode (without children).
 * @param getChildren - The provider's getChildren bound to resolve child nodes.
 */
async function serializeNode(
    node: unknown,
    serialize: (node: unknown) => JsonNode | null,
    getChildren: (node: unknown) => unknown[] | Promise<unknown[]>,
): Promise<JsonNode | null> {
    const json = serialize(node);
    if (!json) return null;

    const children = await getChildren(node);
    if (children.length > 0) {
        const serializedChildren: JsonNode[] = [];
        for (const child of children) {
            const childJson = await serializeNode(child, serialize, getChildren);
            if (childJson) serializedChildren.push(childJson);
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
export async function copyTreeNodesToClipboard(
    item: unknown,
    selectedItems: unknown[] | undefined,
    serialize: (node: unknown) => JsonNode | null,
    getChildren: (node: unknown) => unknown[] | Promise<unknown[]>,
    viewLabel: string,
): Promise<void> {
    const nodes = resolveNodesForJsonExport(item, selectedItems);

    if (nodes.length === 0) {
        vscode.window.showWarningMessage('No tree item selected.');
        return;
    }

    const results: JsonNode[] = [];
    for (const node of nodes) {
        const json = await serializeNode(node, serialize, getChildren);
        if (json) results.push(json);
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
    vscode.window.showInformationMessage(
        `Copied ${count} ${viewLabel} ${noun} to clipboard as JSON`,
    );
}
