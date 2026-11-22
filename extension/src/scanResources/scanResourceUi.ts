/**
 * Renders {@link Notice}s as VS Code notifications and carries out the
 * one-click fixes they offer (switch profile, open settings, turn off type
 * resolution). Decisions live in `scanResourceNotices.ts`; this is the thin,
 * VS Code–specific shell.
 */
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import type { Notice, NoticeActionId } from './scanResourceNotices';

/** Memento key remembering "don't offer the deep scan after a fast scan". */
export const NEVER_OFFER_DEEP_KEY = 'saropaLints.scanResources.neverOfferDeep';

export class ScanResourceUi {
  constructor(private readonly _state: vscode.Memento) {}

  /** True when the user chose "don't offer again" for the deep-scan prompt. */
  get neverOfferDeep(): boolean {
    return this._state.get<boolean>(NEVER_OFFER_DEEP_KEY, false) === true;
  }

  /**
   * Shows [notice] and applies the standard actions. Returns the id of the
   * action the user picked (so the caller can handle scan-specific ones such
   * as `runFast`), or undefined when dismissed.
   */
  async show(notice: Notice): Promise<NoticeActionId | undefined> {
    const message = l10n(notice.messageKey, { ...notice.params });
    const labels = notice.actions.map((a) => l10n(a.labelKey));
    const show =
      notice.severity === 'warning'
        ? vscode.window.showWarningMessage
        : vscode.window.showInformationMessage;
    const picked = await show(message, ...labels);
    if (picked === undefined) return undefined;
    const action = notice.actions.find((a) => l10n(a.labelKey) === picked);
    if (!action) return undefined;
    await this._applyStandard(action.id);
    return action.id;
  }

  /** Effects shared by every entry point; scan-specific actions are no-ops here. */
  private async _applyStandard(id: NoticeActionId): Promise<void> {
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    switch (id) {
      case 'gentleProfile':
        await cfg.update('scan.performanceProfile', 'gentle', vscode.ConfigurationTarget.Global);
        break;
      case 'turnOffTypeResolution':
        await cfg.update('scanOnSave.resolveTypes', false, vscode.ConfigurationTarget.Global);
        break;
      case 'openSettings':
        await vscode.commands.executeCommand(
          'workbench.action.openSettings',
          'saropaLints.scan',
        );
        break;
      case 'neverAskDeep':
        await this._state.update(NEVER_OFFER_DEEP_KEY, true);
        break;
      default:
        break;
    }
  }
}
