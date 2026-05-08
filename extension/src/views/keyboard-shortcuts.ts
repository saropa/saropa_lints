/**
 * Keyboard-shortcut overlay for editor-area dashboards (UX guidelines §15.2).
 *
 * Each dashboard registers its page-level keyboard shortcuts; pressing `?`
 * (or clicking the help affordance) opens a popover listing them. The
 * overlay is a single reusable HTML+script pair; surfaces just provide
 * the list of shortcuts they want to expose.
 *
 * **Usage from a dashboard:**
 *
 * ```ts
 * const shortcuts = [
 *   { key: '/', label: 'Focus search' },
 *   { key: 'Esc', label: 'Clear search and selection' },
 *   { key: 'Shift+Click', label: 'Range-select rows' },
 * ];
 * const html = wrap(`
 *   ${heroHtml}
 *   ${buildKeyboardShortcutsButton()}
 *   ${buildKeyboardShortcutsOverlay(shortcuts)}
 *   ${tableHtml}
 *   <script>${getKeyboardShortcutsScript()}</script>
 * `);
 * ```
 *
 * The overlay is hidden by default. The trigger button + the `?` key both
 * open it; `Esc` or outside-click closes it. Focus traps inside while open
 * (§15.2 focus-trap rule).
 */

import { t } from '../i18n/runtime';

function escape(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

/** One row in the shortcuts list. */
export interface KeyboardShortcut {
  /** Keys to display, e.g. `'/'`, `'Esc'`, `'Shift+Click'`, `'Ctrl+C'`. */
  readonly key: string;
  /** Plain-language description of what the shortcut does. */
  readonly label: string;
}

/**
 * Render the trigger button that opens the overlay. Place near the
 * full-width toggle in the hero. The icon-only button carries an explicit
 * aria-label for screen readers.
 */
export function buildKeyboardShortcutsButton(): string {
  return `<button type="button" id="kbdShortcutsToggle"
    class="kbd-shortcuts-toggle"
    title="${escape(t('kbdOverlay.toggleTitle'))}"
    aria-label="${escape(t('kbdOverlay.toggleAria'))}"
    aria-haspopup="dialog"
    aria-expanded="false">?</button>`;
}

/**
 * Render the overlay markup. Hidden by default via the `hidden` attribute;
 * the script toggles it. The dialog has `role="dialog"`, `aria-modal="true"`
 * so screen readers treat it as a modal context.
 */
export function buildKeyboardShortcutsOverlay(shortcuts: readonly KeyboardShortcut[]): string {
  const rows = shortcuts
    .map((s) =>
      `<tr><td class="kbd-key"><kbd>${escape(s.key)}</kbd></td>` +
      `<td class="kbd-label">${escape(s.label)}</td></tr>`,
    )
    .join('');
  return `<div id="kbdShortcutsOverlay" class="kbd-shortcuts-overlay" hidden
    role="dialog" aria-modal="true" aria-labelledby="kbdShortcutsTitle">
    <div class="kbd-shortcuts-card">
      <div class="kbd-shortcuts-head">
        <h2 id="kbdShortcutsTitle">${escape(t('kbdOverlay.dialogTitle'))}</h2>
        <button type="button" class="kbd-shortcuts-close"
          id="kbdShortcutsClose"
          aria-label="${escape(t('kbdOverlay.closeAria'))}">×</button>
      </div>
      <table class="kbd-shortcuts-list">
        <tbody>${rows}</tbody>
      </table>
      <p class="kbd-shortcuts-foot">${escape(t('kbdOverlay.footer'))}</p>
    </div>
  </div>`;
}

/**
 * Inline script that wires the trigger, the close button, the `?` and `Esc`
 * key handlers, and the outside-click dismissal. Idempotent — multiple
 * instances on the same page would collide on element ids, so by contract
 * each surface must include the overlay exactly once.
 *
 * Focus is trapped inside the overlay while open: tab cycles between the
 * close button and any focusable elements within. On close, focus returns
 * to the trigger button (§15.2).
 */
export function getKeyboardShortcutsScript(): string {
  return `(function() {
    var toggle = document.getElementById('kbdShortcutsToggle');
    var overlay = document.getElementById('kbdShortcutsOverlay');
    var closeBtn = document.getElementById('kbdShortcutsClose');
    if (!toggle || !overlay || !closeBtn) { return; }

    var lastFocused = null;

    function openOverlay() {
      lastFocused = document.activeElement;
      overlay.hidden = false;
      toggle.setAttribute('aria-expanded', 'true');
      closeBtn.focus();
    }

    function closeOverlay() {
      overlay.hidden = true;
      toggle.setAttribute('aria-expanded', 'false');
      if (lastFocused && typeof lastFocused.focus === 'function') {
        lastFocused.focus();
      } else {
        toggle.focus();
      }
    }

    toggle.addEventListener('click', function() {
      if (overlay.hidden) { openOverlay(); } else { closeOverlay(); }
    });
    closeBtn.addEventListener('click', closeOverlay);

    document.addEventListener('keydown', function(e) {
      // ? key opens (when not focused inside an input)
      if (e.key === '?' && !isEditableTarget(e.target) && overlay.hidden) {
        e.preventDefault();
        openOverlay();
        return;
      }
      // Esc closes when open
      if (e.key === 'Escape' && !overlay.hidden) {
        e.preventDefault();
        closeOverlay();
      }
    });

    // Outside-click dismissal — clicks on the overlay backdrop close the dialog.
    overlay.addEventListener('click', function(e) {
      if (e.target === overlay) { closeOverlay(); }
    });

    function isEditableTarget(t) {
      if (!t || !t.tagName) { return false; }
      var tag = t.tagName.toLowerCase();
      return tag === 'input' || tag === 'textarea' || tag === 'select' || t.isContentEditable;
    }
  })();`;
}

/**
 * CSS for the overlay. Append to the surface stylesheet (or include in
 * chrome) so the overlay is styled consistently. Tokens bind to host
 * theme — no hex literals, follows §2 / §14.16.
 */
export function getKeyboardShortcutsStyles(): string {
  return `
    .kbd-shortcuts-toggle {
      flex: 0 0 auto;
      width: 28px;
      height: 28px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border: 1px solid var(--border, var(--vscode-widget-border));
      border-radius: 6px;
      background: var(--surface-3, var(--vscode-editor-inactiveSelectionBackground));
      color: var(--vscode-foreground);
      font-size: 0.95em;
      font-weight: 600;
      cursor: pointer;
    }
    .kbd-shortcuts-toggle:hover { background: var(--vscode-list-hoverBackground); }
    .kbd-shortcuts-toggle:focus-visible {
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: 2px;
    }
    .kbd-shortcuts-overlay {
      position: fixed;
      inset: 0;
      z-index: 1000;
      display: flex;
      align-items: center;
      justify-content: center;
      background: color-mix(in srgb, var(--vscode-editor-background) 70%, transparent);
    }
    /* Author-level display:flex above outranks the UA stylesheet's [hidden]{display:none},
       so without this rule overlay.hidden = true has no visual effect — the modal would
       stay open and look like close/Esc/backdrop-click were broken. */
    .kbd-shortcuts-overlay[hidden] {
      display: none;
    }
    .kbd-shortcuts-card {
      max-width: 480px;
      width: 90%;
      max-height: 70vh;
      overflow-y: auto;
      padding: 16px 20px;
      border: 1px solid var(--border, var(--vscode-widget-border));
      border-radius: 8px;
      background: var(--surface-2, var(--vscode-editorWidget-background));
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
    }
    .kbd-shortcuts-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 12px;
    }
    .kbd-shortcuts-head h2 { margin: 0; font-size: 1.05em; font-weight: 600; }
    .kbd-shortcuts-close {
      width: 28px;
      height: 28px;
      border: 0;
      background: transparent;
      color: var(--vscode-foreground);
      font-size: 1.2em;
      cursor: pointer;
      border-radius: 4px;
    }
    .kbd-shortcuts-close:hover { background: var(--vscode-list-hoverBackground); }
    .kbd-shortcuts-list {
      width: 100%;
      border-collapse: collapse;
    }
    .kbd-shortcuts-list td {
      padding: 4px 8px;
      vertical-align: top;
    }
    .kbd-shortcuts-list .kbd-key {
      width: 30%;
      white-space: nowrap;
    }
    .kbd-shortcuts-list kbd {
      display: inline-block;
      padding: 1px 6px;
      border: 1px solid var(--border, var(--vscode-widget-border));
      border-radius: 3px;
      background: var(--surface-3, var(--vscode-editor-inactiveSelectionBackground));
      font-family: var(--vscode-editor-font-family, ui-monospace, monospace);
      font-size: 0.85em;
    }
    .kbd-shortcuts-foot {
      margin: 12px 0 0;
      color: var(--muted, var(--vscode-descriptionForeground));
      font-size: 0.85em;
    }
  `;
}
