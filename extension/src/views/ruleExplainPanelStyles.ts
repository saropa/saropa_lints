/** CSS for the **Rule explain** editor webview (`ruleExplainView.ts`). */
export function getRuleExplainPanelStyles(): string {
    return `
    body {
      font-family: var(--vscode-font-family);
      font-size: var(--vscode-font-size);
      color: var(--vscode-foreground);
      background: var(--vscode-editor-background);
      padding: 1rem 1.5rem;
      line-height: 1.5;
      margin: 0;
    }
    h1 {
      font-size: 1.25rem;
      font-weight: 600;
      margin: 0 0 0.5rem 0;
      word-break: break-all;
    }
    h2, h3 {
      font-size: 0.9rem;
      font-weight: 600;
      margin: 1rem 0 0.4rem 0;
      color: var(--vscode-descriptionForeground);
    }
    .meta {
      display: flex;
      flex-wrap: wrap;
      gap: 0.75rem 1.5rem;
      margin-bottom: 1rem;
      font-size: 0.85rem;
      color: var(--vscode-descriptionForeground);
    }
    .meta span {
      display: inline-flex;
      align-items: center;
      gap: 0.25rem;
    }
    .meta .badge {
      padding: 0.15rem 0.5rem;
      border-radius: 4px;
      background: var(--vscode-badge-background);
      color: var(--vscode-badge-foreground);
    }
    section.block {
      margin-top: 1rem;
      padding-top: 1rem;
      border-top: 1px solid var(--vscode-widget-border);
    }
    section.block p {
      margin: 0.25rem 0 0 0;
      white-space: pre-wrap;
      word-break: break-word;
    }
    a {
      color: var(--vscode-textLink-foreground);
    }
    a:hover {
      color: var(--vscode-textLink-activeForeground);
    }
    .empty {
      color: var(--vscode-descriptionForeground);
      font-style: italic;
    }
    @media (prefers-reduced-motion: reduce) {
      a { transition: none; }
    }
  `;
}
