# Deferred: Framework Limitations

> **Last reviewed:** 2026-04-13

## Why these optimizations cannot be implemented

The analyzer plugin runs inside the Dart analysis server. It has **no access to IDE events** (keystrokes, file opens, editor focus) and **no control over rule execution order or scheduling**. These optimizations require hooks that neither the Dart analysis server nor the `custom_lint` framework expose.

The extension listens to `onDidSaveTextDocument` and `onDidChangeActiveTextEditor` for its own UI, but these events are not available to the Dart-side rules during analysis.

### What would unblock these

1. **Analysis server API changes**: If the analysis server exposed file-open events, edit events, or rule scheduling hooks, some of these would become possible. No timeline for this.
2. **custom_lint framework changes**: If `custom_lint` supported batch rule execution, rule prioritization, or edit debouncing. No timeline for this.
3. **Separate analysis process**: A standalone analysis daemon (not inside the analysis server) could implement its own scheduling. This is a different architecture than the current plugin model.

---

## Blocked: Requires IDE Events (3 optimizations)

| Optimization | What IDE event it needs | Why the event is unavailable |
|-------------|------------------------|------------------------------|
| `ThrottledAnalysis.recordEdit()` | Keystroke/edit events | Analysis server does not forward editor change events to plugins. The extension receives `onDidChangeTextDocument` but cannot pass it to the Dart-side plugin. |
| `SpeculativeAnalysis.recordFileOpened()` | File-open events | Analysis server does not notify plugins when users open files. The extension knows, but cannot inject this into the plugin's analysis cycle. |
| `RuleGroupExecutor` batch execution | Control over rule scheduling | `custom_lint` runs each rule independently. Plugins cannot group rules or control execution order. |

## Blocked: Requires Persistent State Across Runs (6 optimizations)

These optimizations need to track statistics across many analysis runs and persist them between IDE sessions. The analyzer plugin has no persistent storage API.

| Optimization | What it needs to persist |
|-------------|--------------------------|
| Rule Hit Rate Decay | Violation count per rule across 50+ file analyses. Rules with 0% hits get deprioritized. |
| Auto-Disable Inactive Rules | Hit rates over 100+ files. Rules with 0% violations are candidates for disabling. |
| Violation Locality Heuristic | Violation locations (imports, class bodies, etc.) across files. Focus analysis on high-violation regions. |
| Co-Edit Prediction | Git history patterns of which files are edited together. Pre-warm caches for predicted files. |
| Cache Warming on Startup | Knowledge of which files are open or recently edited. Pre-analyze them on IDE start. |
| Semantic Similarity Skip | Structure hashes for all analyzed files. Skip re-analysis on structurally identical files. |

## Blocked: Requires Expensive Infrastructure (3 optimizations)

| Optimization | Why it is impractical |
|-------------|------------------------|
| Result Memoization by AST Hash | Requires efficient AST hashing, careful invalidation logic, and significant memory management. The cache could grow unbounded. |
| Type Resolution Batching | Requires grouping rules by type resolution needs and sharing resolver setup. Would need changes to how rules are instantiated and run. |
| Memory Pooling | Reusable visitor/reporter objects require resettable design and pool management. Current `const` list approach has low overhead already. |

## Explicitly Rejected (1 optimization)

| Optimization | Why rejected |
|-------------|--------------|
| Negative Pattern Index | **Safety risk.** At startup, scan for patterns that never appear and skip rules globally. If a developer adds a pattern after IDE startup, rules would be incorrectly skipped until restart. Trades correctness for speed — violates the principle that optimizations must never miss actual violations. |

## Not Controllable from This Package (2 items)

| Element | Current | Desired | Why not possible |
|---------|---------|---------|------------------|
| VSCode status bar "Lints" label | "Lints" | "Analyze" | Hardcoded in Dart-Code extension. File issue at [Dart-Code/Dart-Code](https://github.com/Dart-Code/Dart-Code/issues). |
| VSCode status bar icon | Magnifying glass | Bug icon | Hardcoded in Dart-Code extension. |

**Total: 15 items**
