# Bug: Package Vibrancy reports "stale" / "Review (0/10)" for dependencies overridden by path or git

**Status:** Fixed  
**Date:** 2026-03-17  
**Fixed:** 2026-03-17 — Skip main vibrancy diagnostic when `result.package.source` is `path` or `git` in `extension/src/vibrancy/providers/diagnostics.ts`; unit tests added.  
**Component:** VS Code extension — Saropa Package Vibrancy (dependency vibrancy diagnostics)  
**Severity:** Medium — false positive; user is not consuming the pub.dev package at runtime  
**Source:** User report from contacts app; repro with any path- or git-overridden dependency that scores low on pub.dev

---

## Summary

When a dependency declared in `dependencies` (or `dev_dependencies`) is **overridden** via `dependency_overrides` or `pubspec_overrides.yaml` with a **path** or **git** source, the resolved dependency at build/runtime is the local or git copy — not the pub.dev package. Package Vibrancy still scores the **pub.dev package by name**, classifies it (e.g. as `stale` when score &lt; 10), and emits an inline diagnostic on the dependency line in `pubspec.yaml` (e.g. "Review toggle_switch (0/10)" with code `stale`). That warning is a **false positive** for the project: the maintainer has explicitly taken ownership of the dependency via the override, and the upstream package’s vibrancy is irrelevant to what is actually used.

---

## Environment / repro

- **Extension:** Saropa Package Vibrancy (VS Code extension, part of saropa_lints ecosystem)
- **Repro project:** Any Flutter/Dart project that:
  1. Declares a direct dependency in `pubspec.yaml` (e.g. `toggle_switch: ^2.2.3`)
  2. Overrides that dependency with a path or git source (e.g. in `pubspec_overrides.yaml` or `dependency_overrides:` in `pubspec.yaml`)

### Concrete example (contacts app)

- **pubspec.yaml** (excerpt):

  ```yaml
  dependencies:
    toggle_switch: ^2.2.3
  ```

- **pubspec_overrides.yaml** (or `dependency_overrides:` in pubspec):

  ```yaml
  dependency_overrides:
    toggle_switch:
      path: dependency_overrides/toggle_switch
  ```

- **pubspec.lock:** After `flutter pub get`, the lock file resolves `toggle_switch` with `source: path` (or equivalent).

- **Observed diagnostic** (inline on the `toggle_switch` line in pubspec.yaml):
  - **Message:** `Review toggle_switch (0/10)`
  - **Code:** `stale`
  - **Source:** Saropa Package Vibrancy  
  - **Severity:** Information (severity 2)

The pub.dev package `toggle_switch` may legitimately be classified as stale (e.g. low GitHub activity, "Published 24 months ago"). The bug is that the extension shows this **on the dependency declaration** even though the project does **not** use the pub.dev package at runtime — it uses the local path override.

---

## Root cause

1. **Dependency list:** The extension builds the list of packages to scan from the lock file (and pubspec) via `parsePubspecLock` / `findAndParseDeps`. When `includeOverriddenPackages` is true, packages with `source === 'path'` or `source === 'git'` are **included** in the scan (`scan-helpers.ts`: `isScannableSource`, `findAndParseDeps`).

2. **Scoring:** For every such package, `analyzePackage` in `scan-orchestrator.ts` looks up the package **by name** on pub.dev and GitHub (`fetchPackageInfoWithPrerelease`, `fetchPackageMetrics`, `fetchPublisher`, etc.). It does **not** treat path/git-overridden packages differently: it always scores the **upstream** pub.dev package.

3. **Diagnostics:** In `providers/diagnostics.ts`, `VibrancyDiagnostics.update()` iterates over all `VibrancyResult[]` and, for any result with `result.category !== 'vibrant'`, emits a diagnostic (e.g. "Review {name} ({score}/10)" with `code: result.category`). There is **no check** for whether the dependency is overridden by path or git. So a path-overridden package that scores as `stale` (or `legacy-locked`, or `end-of-life`) still gets the same warning as if the project were using the pub.dev version.

4. **Override diagnostics:** The extension already has separate logic for **override** entries (e.g. "No version conflict detected — remove from dependency_overrides if unneeded") in `_addOverrideDiagnostics`, and it **does** skip path/git there (`if (analysis.entry.isPathDep || analysis.entry.isGitDep) { continue; }`). The main vibrancy diagnostic, however, is emitted per **dependency** result and does not consider resolved source.

**Conclusion:** The vibrancy diagnostic is correct about the **pub.dev** package’s status but is a **practical false positive** for projects that resolve the dependency via a path or git override, because the resolved artifact is not the pub.dev package.

---

## Expected behavior

- **Option A (recommended):** For dependencies whose **resolved** source is `path` or `git` (i.e. `result.package.source === 'path'` or `'git'`), **do not emit** the main vibrancy diagnostic (stale / legacy-locked / end-of-life / monitor). The project has taken ownership of the dependency; the upstream score is not actionable.

- **Option B:** Emit a **different**, softer diagnostic for path/git-overridden packages when the upstream would be stale/legacy/eol, e.g. "Local override — upstream pub.dev package is stale (0/10)" with lower severity or a distinct code (e.g. `stale-overridden`), so users can still see the fact without it being a call-to-action on the dependency line.

- **Option C:** Add a setting (e.g. under `saropaLints.packageVibrancy`) to "Suppress vibrancy diagnostics for path/git-overridden packages" (default true to match Option A).

---

## Suggested fix (implementation)

**Location:** `extension/src/vibrancy/providers/diagnostics.ts`, in `VibrancyDiagnostics.update()`, where the main vibrancy diagnostic is pushed for non-vibrant results (lines ~59–71).

**Change:** Before emitting the vibrancy diagnostic for a result with `result.category !== 'vibrant'`, skip when the resolved dependency is a path or git override:

- `VibrancyResult.package` is a `PackageDependency`, which has `source: string` (from the lock file, e.g. `'hosted'`, `'path'`, `'git'`).
- If `result.package.source === 'path'` or `result.package.source === 'git'`, skip adding the main category diagnostic (stale/legacy/eol/monitor). Optionally, still emit unused-dependency, family-conflict, vulnerability, or update-available diagnostics if desired.

**Pseudocode:**

```ts
// In update(), when iterating over results:
if (result.category !== 'vibrant') {
    const isPathOrGitOverride = result.package.source === 'path' || result.package.source === 'git';
    if (!isPathOrGitOverride) {
        const shouldSkip = result.category === 'end-of-life' && eolSetting === 'none';
        if (!shouldSkip) {
            // ... existing severity/message/diag push
        }
    }
}
```

**Tests:** Add a test that, for a mock pubspec.yaml + lock where a direct dependency is overridden by path and scores as stale, the vibrancy diagnostic for that package is **not** present (or is the softer variant if Option B is chosen).

---

## Impact

- **Who is affected:** Any user of the Saropa Package Vibrancy extension who uses `dependency_overrides` (or `pubspec_overrides.yaml`) with **path** or **git** for one or more direct dependencies. Common for maintained forks, local patches, or abandoned pub packages that are kept in-tree.
- **Consequence:** Noisy, misleading "Review X (0/10)" / "stale" on dependency lines that are intentionally overridden. Users may waste time "reviewing" or trying to "fix" a dependency they have already taken ownership of, or may suppress/suppress-by-ignore the extension for that file.

---

## Related

- **BUG_stale_vs_end_of_life_classification.md** (2026-03-16): Introduced the `stale` category for low-score packages; did not address path/git overrides.
- **Override handling:** The extension already parses `dependency_overrides` and has override-specific diagnostics (`_addOverrideDiagnostics`, `stale-override`); the gap is only in the **main** vibrancy diagnostic not considering resolved source for dependencies.

---

## Verification (after fix)

1. Open a workspace where a direct dependency is overridden by path (e.g. `toggle_switch` → `path: dependency_overrides/toggle_switch`).
2. Run Package Vibrancy scan; ensure the lock file has that package with `source: path`.
3. Confirm that the dependency line in `pubspec.yaml` **does not** show "Review toggle_switch (0/10)" / code `stale` (Option A) or shows the softer message (Option B).
4. Confirm that a non-overridden dependency that is genuinely stale still shows the diagnostic as before.
