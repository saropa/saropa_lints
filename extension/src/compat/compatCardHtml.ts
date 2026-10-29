/**
 * "Version compatibility" card for the Health Panel: detected facts, the one
 * recommendation, each blocker with its fix, and Preview diff / Apply buttons.
 * Pure HTML builder; the host owns all actions.
 */
import { escapeHtml } from '../vibrancy/views/html-utils';
import { l10n } from '../i18n/runtime';
import type { ProjectFacts } from './projectFacts';
import type { Msg, Recommendation } from './recommend';

export interface CompatCardState {
  loading?: boolean;
  /** An Apply is running; buttons are disabled. */
  busy?: boolean;
  facts?: ProjectFacts;
  rec?: Recommendation;
  /** True when Apply would change at least one file. */
  hasEdits?: boolean;
  /** Plain-language problem (versions unavailable, apply failed...). */
  error?: string;
}

const fmt = (m: Msg): string => l10n(m.key, m.params);

function fact(labelKey: string, value: string | undefined): string {
  const shown = value ?? l10n('compat.card.notDetected');
  return `<dt>${escapeHtml(l10n(labelKey))}</dt><dd>${escapeHtml(shown)}</dd>`;
}

function list(items: string[]): string {
  return `<ul class="compat-list">${items.map((i) => `<li>${escapeHtml(i)}</li>`).join('')}</ul>`;
}

export function buildCompatSection(state: CompatCardState | undefined): string {
  if (!state) return '';
  const heading = `<h2 class="section-heading">${escapeHtml(l10n('compat.card.heading'))}</h2>`;
  if (state.loading) {
    return `<section class="ci-publish-section compat-section">${heading}
  <p class="publish-intro">${escapeHtml(l10n('compat.card.loading'))}</p></section>`;
  }

  const parts: string[] = [heading];
  const f = state.facts;
  if (f) {
    const locked = f.locked.saropaLints;
    parts.push(`<dl class="compat-facts">
  ${fact('compat.card.dart', f.dartVersion)}
  ${fact('compat.card.flutter', f.flutterVersion)}
  ${fact('compat.card.lockedSaropa', locked ? `${locked.version} (${locked.source})` : undefined)}
  ${fact('compat.card.lockedAnalyzer', f.locked.analyzer)}
  ${fact('compat.card.plugin', f.pluginVersion)}
  ${fact('compat.card.routeLabel', state.rec ? l10n(`compat.card.routes.${state.rec.route}`) : undefined)}
</dl>`);
  }

  const rec = state.rec;
  if (rec) {
    parts.push(`<p class="compat-message">${escapeHtml(fmt({ key: rec.messageKey, params: rec.messageParams }))}</p>`);
    if (rec.blockers.length > 0) {
      parts.push(`<p class="publish-commands-label">${escapeHtml(l10n('compat.card.blockers'))}</p>${list(rec.blockers.map(fmt))}`);
    }
    if (rec.fixes.length > 0) {
      parts.push(`<p class="publish-commands-label">${escapeHtml(l10n('compat.card.fixes'))}</p>${list(rec.fixes.map(fmt))}`);
    }
    if (rec.notes.length > 0) {
      parts.push(`<p class="publish-note">${escapeHtml(rec.notes.map(fmt).join(' '))}</p>`);
    }
  }
  if (state.error) {
    parts.push(`<p class="publish-note publish-blocked compat-error">${escapeHtml(state.error)}</p>`);
  }

  const canAct = !!rec && rec.route !== 'none' && state.hasEdits === true && !state.busy;
  const dis = canAct ? '' : ' disabled';
  const applyRunning = escapeHtml(l10n('compat.card.applying'));
  parts.push(`<div class="publish-actions">
  <button class="publish-btn primary" data-action="compatApply" data-label-running="${applyRunning}"${dis}>${escapeHtml(l10n('compat.card.apply'))}</button>
  <button class="publish-btn" data-action="compatPreview"${dis}>${escapeHtml(l10n('compat.card.preview'))}</button>
  <button class="publish-btn" data-action="compatRefresh"${state.busy ? ' disabled' : ''}>${escapeHtml(l10n('compat.card.refresh'))}</button>
</div>`);
  return `<section class="ci-publish-section compat-section">${parts.join('\n')}</section>`;
}
