"use strict";
/**
 * Run history — persists last K analysis snapshots in workspace state.
 * Used by W5 (trends) and W6 (celebration / progress messages).
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadHistory = loadHistory;
exports.appendSnapshot = appendSnapshot;
exports.getTrendSummary = getTrendSummary;
exports.findPreviousScore = findPreviousScore;
exports.getScoreTrendSummary = getScoreTrendSummary;
exports.detectScoreRegression = detectScoreRegression;
exports.detectThresholdCrossing = detectThresholdCrossing;
const healthScore_1 = require("./healthScore");
const HISTORY_KEY = 'saropaLints.runHistory';
const MAX_ENTRIES = 20;
const TREND_DISPLAY_COUNT = 5;
function loadHistory(state) {
    const raw = state.get(HISTORY_KEY);
    return Array.isArray(raw) ? raw : [];
}
function saveHistory(state, history) {
    // Log write failures so silent data loss is detectable in the output channel.
    state.update(HISTORY_KEY, history).then(undefined, (err) => {
        console.error('[saropaLints] Failed to save run history:', err);
    });
}
/**
 * Appends a snapshot from the current violations data.
 * Deduplicates by comparing total, severity breakdown, and score to the
 * last entry — a same-total run with different severity mix is still recorded.
 * Returns the updated history and whether a new entry was actually appended.
 */
function appendSnapshot(state, data) {
    const history = loadHistory(state);
    const total = data.summary?.totalViolations ?? data.violations.length;
    const last = history.length > 0 ? history[history.length - 1] : undefined;
    const errorCount = data.summary?.bySeverity?.error ?? 0;
    const warningCount = data.summary?.bySeverity?.warning ?? 0;
    const infoCount = data.summary?.bySeverity?.info ?? 0;
    const criticalCount = data.summary?.byImpact?.critical ?? 0;
    const healthResult = (0, healthScore_1.computeHealthScore)(data);
    // Skip duplicate — same total, severity breakdown, AND score as last snapshot.
    // A severity shift with the same total still records a new entry.
    if (last &&
        last.total === total &&
        last.error === errorCount &&
        last.warning === warningCount &&
        last.info === infoCount &&
        last.critical === criticalCount &&
        (last.score ?? -1) === (healthResult?.score ?? -1)) {
        return { history, appended: false };
    }
    const snapshot = {
        timestamp: new Date().toISOString(),
        total,
        error: errorCount,
        warning: warningCount,
        info: infoCount,
        critical: criticalCount,
        score: healthResult?.score,
    };
    history.push(snapshot);
    // Cap at MAX_ENTRIES by dropping oldest entries.
    while (history.length > MAX_ENTRIES) {
        history.shift();
    }
    saveHistory(state, history);
    return { history, appended: true };
}
/**
 * Returns a human-readable trend summary for display in Overview.
 * - 0 entries: undefined
 * - 1 entry: "First run: N violations"
 * - 2+ entries: last K totals arrow-separated, e.g. "120 → 115 → 98"
 */
function getTrendSummary(history) {
    if (history.length === 0)
        return undefined;
    if (history.length === 1) {
        const n = history[0].total;
        return `First run: ${n} ${n === 1 ? 'violation' : 'violations'}`;
    }
    const recent = history.slice(-TREND_DISPLAY_COUNT);
    return recent.map((s) => String(s.total)).join(' \u2192 ');
}
/**
 * Find the most recent snapshot that has a score, excluding the last entry.
 * Used to compute the score delta ("▲4") shown in Overview and status bar.
 */
function findPreviousScore(history) {
    for (let i = history.length - 2; i >= 0; i--) {
        if (history[i].score !== undefined)
            return history[i].score;
    }
    return undefined;
}
/**
 * D5: Score-driven trend summary.
 * Returns score arrows with time span, e.g. "62 → 71 → 78 over 2 weeks".
 * Only includes snapshots that have a score. Returns undefined if <1 scored.
 */
function getScoreTrendSummary(history) {
    const scored = history.filter((s) => s.score !== undefined);
    if (scored.length === 0)
        return undefined;
    if (scored.length === 1)
        return `Score: ${scored[0].score}`;
    const recent = scored.slice(-TREND_DISPLAY_COUNT);
    const arrows = recent.map((s) => String(s.score)).join(' \u2192 ');
    const span = formatTimeSpan(recent[0].timestamp, recent[recent.length - 1].timestamp);
    return span ? `${arrows} over ${span}` : arrows;
}
/** Format the time span between two ISO timestamps as a human-readable duration. */
function formatTimeSpan(startIso, endIso) {
    const ms = new Date(endIso).getTime() - new Date(startIso).getTime();
    if (ms <= 0 || !Number.isFinite(ms))
        return undefined;
    const hours = Math.floor(ms / 3_600_000);
    if (hours < 1)
        return undefined;
    if (hours < 24)
        return `${hours}h`;
    const days = Math.floor(hours / 24);
    if (days < 14)
        return `${days} day${days === 1 ? '' : 's'}`;
    const weeks = Math.floor(days / 7);
    return `${weeks} week${weeks === 1 ? '' : 's'}`;
}
/**
 * D5: Detect whether the latest snapshot represents a score regression.
 * Returns undefined when no regression (score stable or improved).
 */
function detectScoreRegression(history) {
    if (history.length < 2)
        return undefined;
    const curr = history[history.length - 1];
    if (curr.score === undefined)
        return undefined;
    const prevScore = findPreviousScore(history);
    if (prevScore === undefined)
        return undefined;
    const drop = prevScore - curr.score;
    if (drop <= 0)
        return undefined;
    return { previousScore: prevScore, currentScore: curr.score, drop };
}
const SCORE_THRESHOLDS = [90, 80, 70, 60, 50];
/**
 * D8: Detect whether the score crossed a milestone threshold.
 * Returns the highest threshold crossed upward, or lowest crossed downward.
 */
function detectThresholdCrossing(current, previous) {
    if (previous === undefined || current === previous)
        return undefined;
    // Upward: find highest threshold where current >= t > previous.
    for (const t of SCORE_THRESHOLDS) {
        if (current >= t && previous < t)
            return { threshold: t, direction: 'up' };
    }
    // Downward: find lowest threshold where current < t <= previous.
    for (let i = SCORE_THRESHOLDS.length - 1; i >= 0; i--) {
        const t = SCORE_THRESHOLDS[i];
        if (current < t && previous >= t) {
            return { threshold: t, direction: 'down' };
        }
    }
    return undefined;
}
//# sourceMappingURL=runHistory.js.map