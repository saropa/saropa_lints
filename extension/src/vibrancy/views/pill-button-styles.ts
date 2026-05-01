/**
 * Reusable pill-shaped button styles for editor-area dashboards.
 *
 * Class names this helper defines:
 *   .saropa-pill-button         — pill body (secondary-button tokens, rounded full)
 *   .saropa-pill-button-icon    — inner icon circle (primary-button tokens, 22x22)
 *   .saropa-pill-button-title   — single-line label with ellipsis fallback
 *
 * Token rationale: the secondary-button + primary-button token PAIRS are spec-
 * guaranteed to contrast in light, dark, and high-contrast themes. The previous
 * pattern of `editor-inactiveSelectionBackground` body + inherited `foreground`
 * text is meant for editor text selections, not interactive surfaces, and goes
 * unreadable in some color schemes. See the gold-standard guideline §2.1.
 *
 * Usage in HTML:
 *   <button type="button" class="saropa-pill-button">
 *     <span class="saropa-pill-button-icon" aria-hidden="true">
 *       <span class="codicon codicon-refresh"></span>
 *     </span>
 *     <span class="saropa-pill-button-title">Refresh</span>
 *   </button>
 *
 * Concatenate the returned string with the panel's own CSS. Safe to include
 * more than once — pure CSS class definitions, no global side effects.
 *
 * Reduced-motion users get instant transitions automatically.
 */
export function getPillButtonStyles(): string {
    return `
    .saropa-pill-button {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 12px 6px 8px;
      border-radius: 999px;
      border: 1px solid var(--vscode-button-border, transparent);
      background: var(--vscode-button-secondaryBackground);
      color: var(--vscode-button-secondaryForeground);
      cursor: pointer;
      font-family: var(--vscode-font-family);
      font-size: 0.88em;
      max-width: 100%;
      transition: background 0.12s ease, border-color 0.12s ease;
    }

    .saropa-pill-button:hover {
      background: var(--vscode-button-secondaryHoverBackground, var(--vscode-button-secondaryBackground));
      border-color: color-mix(in srgb, var(--vscode-focusBorder) 55%, var(--vscode-button-border, transparent));
    }

    .saropa-pill-button:focus-visible {
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: 2px;
    }

    .saropa-pill-button:disabled,
    .saropa-pill-button[aria-disabled="true"] {
      opacity: 0.55;
      cursor: not-allowed;
    }

    .saropa-pill-button-icon {
      width: 22px;
      height: 22px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 50%;
      background: var(--vscode-button-background);
      color: var(--vscode-button-foreground);
      flex-shrink: 0;
    }

    .saropa-pill-button-icon .codicon {
      color: inherit;
      font-size: 13px;
    }

    .saropa-pill-button-title {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    @media (prefers-reduced-motion: reduce) {
      .saropa-pill-button { transition: none; }
    }
  `;
}
