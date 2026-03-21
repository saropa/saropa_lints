/**
 * Allowlist of `ConfigTreeNode.kind` values that may appear inside the Overview tree
 * when embedding `ConfigTreeProvider` children under Overview. Used to avoid sending arbitrary
 * `{ kind: string }` objects to `renderTreeItem` (which assumes a closed union).
 */

export const OVERVIEW_EMBEDDED_CONFIG_KINDS = new Set<string>([
    'configSetting',
    'triageGroup',
    'triageRule',
    'triageInfo',
]);
