import * as vscode from 'vscode';
import { FamilySplit } from '../types';
import { DetailItem } from './tree-items';

export class FamilyConflictGroupItem extends vscode.TreeItem {
    constructor(public readonly splits: readonly FamilySplit[]) {
        super(
            `Family Conflicts (${splits.length})`,
            vscode.TreeItemCollapsibleState.Expanded,
        );
        this.iconPath = new vscode.ThemeIcon(
            'warning',
            new vscode.ThemeColor('editorWarning.foreground'),
        );
        this.contextValue = 'vibrancyFamilyConflictGroup';
    }
}

export class FamilySplitItem extends vscode.TreeItem {
    constructor(public readonly split: FamilySplit) {
        super(
            `${split.familyLabel} — version split`,
            vscode.TreeItemCollapsibleState.Collapsed,
        );
        this.iconPath = new vscode.ThemeIcon(
            'git-compare',
            new vscode.ThemeColor('editorWarning.foreground'),
        );
    }
}

/** Build detail items for a family split node. */
export function buildFamilySplitDetails(split: FamilySplit): DetailItem[] {
    const items: DetailItem[] = [];
    for (const group of split.versionGroups) {
        items.push(new DetailItem(
            `Major v${group.majorVersion}`,
            group.packages.join(', '),
        ));
    }
    items.push(new DetailItem('💡 Suggestion', split.suggestion));
    return items;
}
