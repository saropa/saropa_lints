/**
 * Pure selection logic for **Copy as JSON** tree commands.
 *
 * Kept separate from `copyTreeAsJson.ts` so unit tests run under Node without the `vscode` module
 * (Mocha uses plain Node; only `@types/vscode` exists at compile time).
 *
 * Mirrors VS Code’s tree command arguments: `(clickedItem, selectedItems?)`. When the TreeView has
 * `canSelectMany: true`, `selectedItems` contains every highlighted row; it must win over `clickedItem`
 * whenever it is a non-empty array.
 */

/**
 * Returns the list of tree nodes to serialize for clipboard export.
 *
 * - Non-empty `selectedItems` → use it (multi-select).
 * - Otherwise → `[item]` if `item` is truthy, else `[]`.
 */
export function resolveNodesForJsonExport(
    item: unknown,
    selectedItems: unknown[] | undefined,
): unknown[] {
    if (Array.isArray(selectedItems) && selectedItems.length > 0) {
        return selectedItems;
    }
    return item ? [item] : [];
}
