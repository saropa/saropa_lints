import * as vscode from 'vscode';
import { VibrancyResult, PackageInsight } from '../types';

export class VibrancyStatusBar implements vscode.Disposable {
    private readonly _item: vscode.StatusBarItem;

    constructor() {
        this._item = vscode.window.createStatusBarItem(
            'saropaLints.packageVibrancy.status',
            vscode.StatusBarAlignment.Right,
            50,
        );
        this._item.name = 'Package Vibrancy';
        this._item.command = 'saropaLints.packageVibrancy.showReport';
        this.hide();
    }

    /** Update with scan results and insights. */
    update(results: VibrancyResult[], insights: readonly PackageInsight[] = []): void {
        if (results.length === 0) {
            this.hide();
            return;
        }

        const avg = results.reduce((s, r) => s + r.score, 0) / results.length;
        const rounded = Math.round(avg);
        const icon = rounded >= 70 ? '$(pass)' : rounded >= 40 ? '$(info)' : '$(warning)';

        const updateCount = results.filter(
            r => r.updateInfo && r.updateInfo.updateStatus !== 'up-to-date',
        ).length;

        const actionCount = insights.length;
        const displayScore = Math.round(rounded / 10);

        let text = `${icon} Vibrancy: ${displayScore}/10`;
        if (actionCount > 0) {
            text += ` $(target) ${actionCount}`;
        }
        this._item.text = text;

        let tooltip = `${results.length} packages scanned.`;
        if (updateCount > 0) {
            tooltip += ` ${updateCount} update(s) available.`;
        }
        if (actionCount > 0) {
            tooltip += ` ${actionCount} action item(s).`;
        }
        tooltip += ' Click for report.';
        this._item.tooltip = tooltip;
        this._item.show();
    }

    hide(): void {
        this._item.hide();
    }

    dispose(): void {
        this._item.dispose();
    }
}
