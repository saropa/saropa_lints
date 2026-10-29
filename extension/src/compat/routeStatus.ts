/**
 * Pure text for the persistent, quiet route status (start-up detection,
 * decision 20 of plans/history/2026.10/2026.10.28/PLAN_analyzer_12_to_13_14_upgrade.md): which route the
 * project uses, what that gives, in plain words. No vscode here.
 */
import type { Installed, RouteState, Translate } from './startupDetection';

export interface RouteStatus {
  text: string;
  tooltip: string;
}

export function routeStatus(state: RouteState, installed: Installed, t: Translate): RouteStatus {
  const K = 'compat.status.';
  const { pubspec, plugin } = installed;
  let text: string;
  let tip: string;
  switch (state) {
    case 'pubspecOnly':
      text = pubspec ? t(K + 'pubspec', { version: pubspec }) : t(K + 'pubspecUnlocked');
      tip = t(K + 'tipPubspec');
      break;
    case 'pluginOnly':
      text = t(K + 'plugin', { version: plugin ?? '' });
      tip = t(K + 'tipPlugin');
      break;
    case 'bothAgree':
      text = t(K + 'both', { version: pubspec ?? plugin ?? '' });
      tip = t(K + 'tipBoth');
      break;
    case 'bothDisagree':
      text = t(K + 'disagree', { pubspec: pubspec ?? '', plugin: plugin ?? '' });
      tip = t(K + 'tipDisagree', { pubspec: pubspec ?? '', plugin: plugin ?? '' });
      break;
    case 'localSource':
      text = t(K + 'localSource');
      tip = t(K + 'tipLocalSource');
      break;
    case 'dartTooOld':
      text = t(K + 'dartTooOld');
      tip = t(K + 'tipDartTooOld');
      break;
    default:
      text = t(K + 'neither');
      tip = t(K + 'tipNeither');
  }
  return { text, tooltip: `${tip}\n\n${t(K + 'tipClick')}` };
}
