# Token coverage matrix

Generated: 2026-05-14T01:32:44.410Z

Scanned 13 surface files; 66 unique tokens referenced.

## Index — surfaces

1. `chart-html`
2. `chart-styles`
3. `commandCatalogWebviewHtml`
4. `comparison-html`
5. `detail-view-styles`
6. `known-issues-html`
7. `package-detail-styles`
8. `pill-button-styles`
9. `report-html`
10. `report-styles`
11. `rulePacksWebviewProvider`
12. `triageDashboardHtml`
13. `violationsDashboardHtml`

## Tokens × surfaces

| Token | Used by (surface index) |
|-------|--------------------------|
| `--accent-` | 13 |
| `--bar-width` | 2 |
| `--border` | 4, 6 |
| `--chart-color-0` | 2 |
| `--chart-color-1` | 2 |
| `--chart-color-10` | 2 |
| `--chart-color-11` | 2 |
| `--chart-color-2` | 2 |
| `--chart-color-3` | 2 |
| `--chart-color-4` | 2 |
| `--chart-color-5` | 2 |
| `--chart-color-6` | 2 |
| `--chart-color-7` | 2 |
| `--chart-color-8` | 2 |
| `--chart-color-9` | 2 |
| `--chart-hue-` | 11 |
| `--link` | 4 |
| `--muted` | 6 |
| `--surface-2` | 6 |
| `--surface-3` | 4 |
| `--vscode-` | 10 |
| `--vscode-badge-background` | 3, 4, 5, 7, 10 |
| `--vscode-badge-foreground` | 3, 4, 5, 7, 10 |
| `--vscode-button-background` | 3, 5, 7, 8 |
| `--vscode-button-border` | 4, 7, 8, 10 |
| `--vscode-button-foreground` | 5, 7, 8 |
| `--vscode-button-hoverBackground` | 5, 7 |
| `--vscode-button-secondaryBackground` | 4, 5, 7, 8, 10 |
| `--vscode-button-secondaryForeground` | 4, 5, 7, 8, 10 |
| `--vscode-button-secondaryHoverBackground` | 4, 5, 7, 8, 10 |
| `--vscode-charts-green` | 3 |
| `--vscode-descriptionForeground` | 2, 3, 5, 6, 7, 9, 10, 13 |
| `--vscode-editor-background` | 1, 2, 3, 7, 9, 10, 12 |
| `--vscode-editor-findMatchHighlightBackground` | 3, 6 |
| `--vscode-editor-font-family` | 3, 5, 7, 10 |
| `--vscode-editor-font-size` | 5, 7 |
| `--vscode-editor-inactiveSelectionBackground` | 2, 3, 4, 7, 10 |
| `--vscode-editor-selectionBackground` | 3, 6 |
| `--vscode-editorError-foreground` | 4, 5, 7, 9, 10 |
| `--vscode-editorHoverWidget-background` | 2 |
| `--vscode-editorHoverWidget-border` | 2 |
| `--vscode-editorHoverWidget-foreground` | 2 |
| `--vscode-editorInfo-foreground` | 4, 5, 7, 9, 10 |
| `--vscode-editorWarning-foreground` | 4, 5, 6, 7, 9, 10 |
| `--vscode-editorWidget-background` | 3, 6, 7, 10 |
| `--vscode-editorWidget-border` | 5 |
| `--vscode-focusBorder` | 2, 3, 5, 6, 7, 8, 10 |
| `--vscode-font-family` | 3, 5, 7, 8, 9, 10 |
| `--vscode-font-size` | 3, 5, 7 |
| `--vscode-foreground` | 2, 3, 5, 6, 7, 9, 10 |
| `--vscode-input-background` | 3, 6, 7, 10 |
| `--vscode-input-border` | 3, 6, 10 |
| `--vscode-input-foreground` | 3, 6, 7, 10 |
| `--vscode-input-placeholderForeground` | 3 |
| `--vscode-list-activeSelectionBackground` | 3, 7, 10 |
| `--vscode-list-activeSelectionForeground` | 3, 7, 10 |
| `--vscode-list-hoverBackground` | 2, 3, 5, 6, 7, 10 |
| `--vscode-list-warningForeground` | 12 |
| `--vscode-sideBar-background` | 3, 5 |
| `--vscode-sideBarSectionHeader-background` | 5, 7, 12 |
| `--vscode-sideBarSectionHeader-foreground` | 5 |
| `--vscode-testing-iconPassed` | 3, 4, 5, 6, 7, 9, 10 |
| `--vscode-textLink-activeForeground` | 5, 7 |
| `--vscode-textLink-foreground` | 3, 4, 5, 6, 7, 10, 12 |
| `--vscode-toolbar-hoverBackground` | 3, 6, 10 |
| `--vscode-widget-border` | 2, 3, 4, 5, 6, 7, 9, 10, 12 |

## How to read this matrix

- Each row pins a CSS variable used somewhere in the webview HTML / CSS.
- The surface index tells you which files reference it. A token with only one or two surfaces using it is a candidate for inlining or chrome consolidation.
- A token used by 5+ surfaces lives in chrome (`dashboardChromeStyles.ts`) by definition; if it appears here referenced from multiple `*-styles.ts` files, those should consume it from chrome rather than redefining.
- When VS Code deprecates a token, this matrix tells you exactly which surfaces need migration.
