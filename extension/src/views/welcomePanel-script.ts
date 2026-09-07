/**
 * Returned as a raw string, not a .js file — injected inline into the webview's
 * <script nonce="..."> tag, matching the pattern every other dashboard uses
 * (see healthPanel-script.ts). Owns the panel's single acquireVsCodeApi() call.
 *
 * The "Show this next time" checkbox is deliberately hard to opt out of: it starts
 * checked and disabled, and only becomes interactive once the user has scrolled the
 * body to the bottom — proof they at least passed the critical engine-change card
 * rather than closing the tab in the first second. Once enabled, any change is
 * reported immediately so the extension host persists it as the user toggles it,
 * not only on close (a webview tab can be closed without a dedicated close event).
 */
export function getWelcomePanelScript(): string {
  return `
const vscode = acquireVsCodeApi();

document.addEventListener('click', function(e) {
  const btn = e.target.closest('button[data-action]');
  if (!btn) return;
  vscode.postMessage({ type: btn.dataset.action });
});

const checkbox = document.getElementById('showNextTime');
const hint = document.getElementById('showNextTimeHint');

// The page itself scrolls (no fixed-height inner container), so this reads the
// document's own scroll position rather than a specific element's.
function maybeEnableCheckbox() {
  if (!checkbox || !checkbox.disabled) return;
  const doc = document.documentElement;
  const scrolledToBottom = window.scrollY + window.innerHeight >= doc.scrollHeight - 16;
  if (scrolledToBottom) {
    checkbox.disabled = false;
    if (hint) hint.textContent = hint.dataset.enabledText || '';
  }
}

window.addEventListener('scroll', maybeEnableCheckbox);
window.addEventListener('resize', maybeEnableCheckbox);
// The content may already fit without scrolling on a tall window — check once on load too.
maybeEnableCheckbox();

if (checkbox) {
  checkbox.addEventListener('change', function() {
    vscode.postMessage({ type: 'setShowNextTime', value: checkbox.checked });
  });
}
`;
}
