/**
 * "Watcher excludes" block of the Rules & Tiers Automation tab: the two scan-limit settings plus
 * the recommended-excludes list, each with a count of what is currently affected and a native
 * `<details>` "List" of the paths. Pure HTML builder so it is unit-testable; the data comes from
 * the hazard scan (`getUncoveredHazards`) and `findMissingExcludes`, so no extra scan pass runs.
 */

import { l10n } from '../i18n/runtime';
import type { HazardFile } from '../systemHealth/workspaceHazardScan';

/** Settings rendered by this block (suffixes after `saropaLints.`). */
export const WATCHER_SETTING_KEYS = [
  'watcherExclude.maxFileKb',
  'watcherExclude.maxFolderFiles',
] as const;

/** Scan results the block renders; `undefined` while the first scan is still running. */
export interface WatcherScanData {
  hazards: readonly HazardFile[];
  missingExcludes: readonly string[];
}

function esc(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function affectedRow(id: string, items: readonly string[]): string {
  const count = l10n('rulesTiers.watcher.affected', { count: String(items.length) });
  const list =
    items.length === 0
      ? ''
      : `<details><summary>${esc(l10n('rulesTiers.watcher.list'))}</summary><ul>${items
          .map((i) => `<li><code>${esc(i)}</code></li>`)
          .join('')}</ul></details>`;
  return `<tr id="watcher-affected-${id}"><td class="settings-label">${esc(count)}</td><td class="settings-control">${list}</td></tr>`;
}

/**
 * @param settingRows pre-rendered settings-grid `<tr>` for each key in {@link WATCHER_SETTING_KEYS}
 *   (same control markup as the generic grid, so edits post the same messages).
 */
export function buildWatcherExcludeSectionHtml(
  settingRows: Readonly<Record<string, string>>,
  scan: WatcherScanData | undefined,
): string {
  const fmtFile = (f: HazardFile): string => f.relative;
  const files = scan?.hazards.filter((h) => h.fileCount === undefined).map(fmtFile) ?? [];
  const folders =
    scan?.hazards
      .filter((h) => h.fileCount !== undefined)
      .map((h) => `${h.relative}/ (${h.fileCount})`) ?? [];
  const missing = scan?.missingExcludes ?? [];
  const status = scan
    ? ''
    : `<p class="hint">${esc(l10n('rulesTiers.watcher.scanning'))}</p>`;
  const rows = [
    settingRows[WATCHER_SETTING_KEYS[0]] ?? '',
    affectedRow('files', files),
    settingRows[WATCHER_SETTING_KEYS[1]] ?? '',
    affectedRow('folders', folders),
    `<tr id="watcher-recommended"><td class="settings-label">${esc(l10n('rulesTiers.watcher.recommended'))}</td><td class="settings-control"></td></tr>`,
    affectedRow('recommended', missing),
  ].join('\n');
  return `<section class="section" aria-label="${esc(l10n('rulesTiers.watcher.title'))}">
  <h3>${esc(l10n('rulesTiers.watcher.title'))}</h3>
  <p class="hint">${esc(l10n('rulesTiers.watcher.hint'))}</p>
  ${status}
  <table class="dash-table settings-table"><tbody>${rows}</tbody></table>
</section>`;
}
