import { escapeHtml } from '../vibrancy/views/html-utils';
import { l10n } from '../i18n/runtime';
import type { CiPublishPlan } from './ciPublish';

/**
 * The deliberate step between "the workflow file changed on disk" and
 * "a pull request exists".
 *
 * Nothing here happens on its own. Flipping the CI card writes the file and
 * renders this section; the branch is not cut, nothing is committed and
 * nothing is pushed until the button in it is pressed. The reason is that
 * this file governs every contributor's pull requests, and a panel that
 * pushed a branch as a side effect of a toggle would be making a decision on
 * the user's behalf that they may not even have noticed making.
 *
 * The commands are shown, not summarized, and are the literal strings the
 * runner executes (`CiPublishPlan.commands`). Someone who would rather run
 * them in their own terminal — because their push needs a hardware key, or
 * their team signs commits, or they simply do not want an editor touching
 * their git history — copies them and is done. That path is first-class
 * here, not a consolation prize.
 */

/** A small inline clipboard glyph. Inline because the panel's CSP forbids external assets. */
const COPY_ICON = `<svg width="13" height="13" viewBox="0 0 16 16" aria-hidden="true" focusable="false">
  <path fill="currentColor" d="M4 2h7l3 3v7a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1zm6 1H4v9h8V6h-2V3z"/>
  <path fill="currentColor" d="M2 4v9a2 2 0 0 0 2 2h7v-1H4a1 1 0 0 1-1-1V4H2z"/>
</svg>`;

/**
 * Renders the pending-change section, or nothing at all when there is no
 * pending change — the common case, so the panel is not permanently carrying
 * a git widget nobody asked for.
 */
export function buildCiPublishSection(plan: CiPublishPlan | undefined): string {
  if (!plan) return '';

  const heading = escapeHtml(l10n('debug.ci.publish.heading'));
  const intro = escapeHtml(
    l10n(
      plan.direction === 'enable'
        ? 'debug.ci.publish.introEnable'
        : 'debug.ci.publish.introDisable',
      // The workflow file is always first, and is the one the prose names.
      // Any others (pubspec.yaml, when the dependency was just added) are
      // visible in the commands below rather than crammed into a sentence.
      { path: plan.paths[0], branch: plan.branch, base: plan.baseBranch },
    ),
  );

  // No GitHub remote means no pull request we can open. Say so plainly and
  // let the commands carry the whole flow, rather than offering a button
  // that could only fail.
  const canOpenPr = plan.slug !== undefined;
  const primaryLabel = escapeHtml(l10n('debug.ci.publish.createPr'));
  // The running label travels with the button so the webview can switch to it
  // without a round trip — the host is busy running git at that moment, and a
  // button that still reads "Create…" after a click looks like it was missed.
  const runningLabel = escapeHtml(l10n('debug.ci.publish.running'));
  const primary = canOpenPr
    ? `<button class="publish-btn primary" data-action="ciPublish"
      data-label-running="${runningLabel}">${primaryLabel}</button>`
    : '';
  const noRemoteNote = canOpenPr
    ? ''
    : `<p class="publish-note">${escapeHtml(l10n('debug.ci.publish.noGitHubRemote'))}</p>`;

  const dismissLabel = escapeHtml(l10n('debug.ci.publish.notNow'));
  const copyLabel = escapeHtml(l10n('debug.ci.publish.copy'));
  const commandsLabel = escapeHtml(l10n('debug.ci.publish.commandsLabel'));

  // The copy button carries the commands as a data attribute rather than the
  // webview reading them back out of the rendered <pre>: the rendered text is
  // HTML-escaped, so copying the DOM's text would hand the user `&quot;`
  // where they need a quote mark.
  const commandsText = plan.commands.join('\n');

  return `<section class="ci-publish-section" data-direction="${escapeHtml(plan.direction)}">
  <h2 class="section-heading">${heading}</h2>
  <p class="publish-intro">${intro}</p>
  <div class="publish-commands-header">
    <span class="publish-commands-label">${commandsLabel}</span>
    <button class="publish-copy" data-action="ciCopyCommands"
      data-commands="${escapeHtml(commandsText)}" title="${copyLabel}">${COPY_ICON}<span>${copyLabel}</span></button>
  </div>
  <pre class="publish-commands"><code>${escapeHtml(commandsText)}</code></pre>
  ${noRemoteNote}
  <div class="publish-actions">
    ${primary}
    <button class="publish-btn" data-action="ciPublishDismiss">${dismissLabel}</button>
  </div>
</section>`;
}
