import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { formatBytes, queryDartProcesses, buildSnapshot, killProcess } from './processQuery';

export function registerCleanupCommand(
  context: vscode.ExtensionContext,
): void {
  context.subscriptions.push(
    vscode.commands.registerCommand(
      'saropaLints.killOrphanedDaemons',
      async () => {
        // Always re-query live to avoid stale-PID kills.
        const processes = await queryDartProcesses();
        const snapshot = await buildSnapshot(processes);

        // Combine Flutter daemon and scan daemon orphans into one cleanup.
        const pids = [
          ...snapshot.orphanedDaemonPids,
          ...snapshot.orphanedScanDaemonPids,
        ];
        if (pids.length === 0) {
          void vscode.window.showInformationMessage(
            l10n('systemHealth.cleanup.noOrphans'),
          );
          return;
        }

        const size = formatBytes(snapshot.totalRssBytes);
        const count = String(pids.length);

        const confirmMsg = l10n('systemHealth.cleanup.confirm', { count, size });
        const killLabel = l10n('systemHealth.cleanup.killButton');
        const cancelLabel = l10n('systemHealth.cleanup.cancelButton');

        const choice = await vscode.window.showInformationMessage(
          confirmMsg,
          { modal: true },
          killLabel,
          cancelLabel,
        );

        if (choice !== killLabel) return;

        let killed = 0;
        for (const pid of pids) {
          if (await killProcess(pid)) killed++;
        }

        const resultMsg = l10n('systemHealth.notification.result', {
          count: String(killed),
          size,
        });
        void vscode.window.showInformationMessage(resultMsg);
      },
    ),
  );
}
