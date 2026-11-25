/**
 * Records the Vibrancy pub guard's decisions so the user can ask WHY a pub
 * query was skipped ("Explain Last Vibrancy Skip") and so a status-bar item can
 * appear on a skip and disappear on the next successful pass.
 *
 * Pure state + formatting only (no `vscode` import) so it is unit-testable;
 * the UI lives in `pub-guard-explain.ts`, which subscribes via [onGuardOutcome].
 * Kept separate from `sdk-toolchain.ts` to avoid an import cycle with the CLI
 * wrapper (explain -> flutter-cli -> sdk-toolchain -> record).
 */

import { l10n } from '../../i18n/runtime';

/** Where the selected SDK was resolved from (mirrors ResolvedDart['source']). */
export type GuardSdkSource = 'dart.sdkPath' | 'dart.flutterSdkPath' | 'fvm' | 'path';

/** Where the project's own SDK version evidence came from. */
export type ProjectVersionSource = 'dartToolVersion' | 'lockConstraint' | 'none';

/** One guard decision with everything needed to explain it. */
export interface GuardDecision {
    /** Epoch ms of the decision. */
    readonly at: number;
    /** Project folder the pub query targeted (also where "pub get" is offered). */
    readonly cwd: string;
    /** Resolved SDK executable path, or the bare name when taken from PATH. */
    readonly sdkCommand: string;
    readonly sdkSource: GuardSdkSource;
    /** Version pub last resolved the project with, when known. */
    readonly projectVersion?: string;
    readonly projectVersionSource: ProjectVersionSource;
    /** `sdks: dart:` constraint from pubspec.lock, when present. */
    readonly lockConstraint?: string;
    /** Version of the selected SDK, when it could be determined. */
    readonly toolVersion?: string;
    /** l10n key of the rule that refused (e.g. `pubGuard.sdkMismatch`); empty when allowed. */
    readonly reasonKey: string;
    readonly reasonParams?: Record<string, string>;
}

type Listener = (safe: boolean, decision: GuardDecision) => void;

/**
 * Refused decisions this session, keyed by project folder. A map (not a single
 * slot) because multi-root workspaces scan several folders: one folder's
 * allowed pass must not hide another folder's skip.
 */
const skips = new Map<string, GuardDecision>();
const listeners = new Set<Listener>();

/**
 * Stores a refused decision under its folder; an allowed outcome removes ONLY
 * that folder's entry. Then notifies subscribers so the UI can show/clear.
 */
export function recordGuardOutcome(safe: boolean, decision: GuardDecision): void {
    if (safe) { skips.delete(decision.cwd); } else { skips.set(decision.cwd, decision); }
    for (const l of listeners) {
        // A broken UI listener must never break the scan that triggered it.
        try { l(safe, decision); } catch { /* listener failure is non-fatal */ }
    }
}

/** All recorded skips, most recent first. Empty when nothing was skipped. */
export function getSkips(): GuardDecision[] {
    return [...skips.values()].sort((a, b) => b.at - a.at);
}

/** Test hook: forget every recorded skip. */
export function clearSkips(): void {
    skips.clear();
}

/** Subscribes to every outcome; returns an unsubscribe function. */
export function onGuardOutcome(listener: Listener): () => void {
    listeners.add(listener);
    return () => { listeners.delete(listener); };
}

/**
 * Short localized rule name for a reason key (`pubGuard.sdkMismatch` ->
 * `pubGuard.rule.sdkMismatch`). Shown in the "Rule:" line instead of the raw key.
 */
export function ruleName(reasonKey: string): string {
    if (!reasonKey) { return l10n('pubGuard.explain.unknown'); }
    return l10n(reasonKey.replace(/^pubGuard\./, 'pubGuard.rule.'));
}

/** Localized label for where the SDK was resolved from. */
export function sourceLabel(source: GuardSdkSource): string {
    return l10n(`pubGuard.source.${source === 'dart.sdkPath' ? 'dartSdkPath'
        : source === 'dart.flutterSdkPath' ? 'flutterSdkPath' : source}`);
}

/**
 * Multi-line, fully localized explanation of a decision. `formatTime` is
 * injectable so tests do not depend on the machine locale/timezone.
 */
export function formatDecision(
    d: GuardDecision,
    formatTime: (ms: number) => string = (ms) => new Date(ms).toLocaleString(),
): string {
    const unknown = l10n('pubGuard.explain.unknown');
    const projectValue = d.projectVersion ?? d.lockConstraint ?? unknown;
    const projectSource = l10n(`pubGuard.projectSource.${d.projectVersionSource}`);
    return [
        l10n('pubGuard.explain.reason', {
            reason: d.reasonKey ? l10n(d.reasonKey, d.reasonParams) : unknown,
        }),
        l10n('pubGuard.explain.rule', { rule: ruleName(d.reasonKey) }),
        l10n('pubGuard.explain.sdk', { path: d.sdkCommand, source: sourceLabel(d.sdkSource) }),
        l10n('pubGuard.explain.toolVersion', { version: d.toolVersion ?? unknown }),
        l10n('pubGuard.explain.project', { value: projectValue, source: projectSource }),
        l10n('pubGuard.explain.folder', { cwd: d.cwd }),
        l10n('pubGuard.explain.time', { time: formatTime(d.at) }),
    ].join('\n');
}

/** What the "Explain Last Vibrancy Skip" command should present. */
export type ExplainModel =
    | { readonly kind: 'none'; readonly message: string }
    | {
        readonly kind: 'skip';
        readonly title: string;
        readonly detail: string;
        readonly actionLabel: string;
    };

/**
 * Pure builder for the command's content: a "nothing recorded" message when no
 * skip happened this session, otherwise the modal title/detail plus the label
 * of the "run pub get with the project SDK" action.
 */
export function buildExplainModel(
    d: GuardDecision | undefined,
    formatTime?: (ms: number) => string,
): ExplainModel {
    if (!d) { return { kind: 'none', message: l10n('pubGuard.explain.none') }; }
    return {
        kind: 'skip',
        title: l10n('pubGuard.explain.title'),
        detail: formatDecision(d, formatTime),
        actionLabel: l10n('pubGuard.explain.runPubGet'),
    };
}

/** One QuickPick row when several project folders were skipped. */
export interface FolderPickItem {
    readonly label: string;
    readonly description: string;
    readonly detail: string;
    readonly decision: GuardDecision;
}

/**
 * Rows for choosing which skipped folder to explain (multi-root workspaces).
 * Label is the folder name, description its full path (disambiguates equal
 * names), detail the localized reason.
 */
export function buildFolderPickItems(list: readonly GuardDecision[]): FolderPickItem[] {
    return list.map((d) => ({
        label: d.cwd.split(/[\/]/).filter(Boolean).pop() ?? d.cwd,
        description: d.cwd,
        detail: d.reasonKey ? l10n(d.reasonKey, d.reasonParams) : '',
        decision: d,
    }));
}
