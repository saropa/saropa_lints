# Package Replacement Complexity — Implementation Plan

## Problem

Users keep stale/unmaintained dependencies because they don't know how trivial the replacement would be. A package with 25 lines of source code could be inlined in minutes, but vibrancy currently only shows archive size (compressed tarball bytes) — which says nothing about actual code complexity.

## Feature: Replacement Complexity Metric

Analyze the **local pub cache copy** of each dependency to measure how much real code it contains, then classify how hard it would be to replace, fork, or inline.

---

## Data Model

### New type: `PackageCodeMetrics`

```typescript
interface PackageCodeMetrics {
  /** Lines of actual Dart code in lib/ (excludes comments and blanks). */
  readonly libCodeLines: number;
  /** Lines of comments/documentation in lib/. */
  readonly libCommentLines: number;
  /** Number of .dart files in lib/. */
  readonly libFileCount: number;
  /** Lines of code in example/ (if present). */
  readonly exampleCodeLines: number;
  /** Whether native platform dirs exist (ios/, android/, etc.). */
  readonly hasNativeCode: boolean;
  /** Detected native platform dirs. */
  readonly nativePlatforms: readonly string[];
}
```

### New type: `ReplacementComplexity`

```typescript
type ReplacementLevel = 'trivial' | 'small' | 'moderate' | 'large' | 'native';

interface ReplacementComplexity {
  readonly level: ReplacementLevel;
  readonly metrics: PackageCodeMetrics;
  /** Human-readable summary, e.g. "25 lines of Dart in 2 files". */
  readonly summary: string;
}
```

### Classification thresholds (initial, calibrated)

| lib code lines | hasNativeCode | Level | Label |
|---|---|---|---|
| < 100 | no | `trivial` | "Trivial — N lines, could inline" |
| 100–499 | no | `small` | "Small — N lines across M files" |
| 500–1999 | no | `moderate` | "Moderate — N lines across M files" |
| 2000+ | no | `large` | "Large — N lines across M files" |
| any | yes | `native` | "Contains native code (ios, android, ...)" |

Native code is the dominant signal — a 50-LOC Dart wrapper around a native plugin is NOT trivial to replace.
These thresholds are intentionally pragmatic and should be rechecked after sampling real packages.

---

## Implementation: 6 Files

### 1. NEW: `services/package-code-analyzer.ts`

**Purpose:** Read local package source and count lines.

**Approach:**
- Read `.dart_tool/package_config.json` from the workspace root (already available as `workspaceRoot` in the scan pipeline)
- Parse it to get `rootUri` for each package → resolves to local package path
- For each package, glob `lib/**/*.dart` and count lines using a simple regex classifier:
  - **Code line:** has non-whitespace content that isn't a comment
  - **Comment line:** first non-whitespace is `//`, `///`, `/*`, or `*` (block comment continuation)
  - **Blank line:** whitespace only (not counted)
- Check for native dirs: `ios/`, `android/`, `macos/`, `linux/`, `windows/`, `web/` (presence heuristic)
- Optionally count `example/**/*.dart` lines

**Key functions:**
```typescript
/** Parse .dart_tool/package_config.json → Map<packageName, { rootUri, source }>. */
export async function resolvePackagePaths(
    workspaceRoot: vscode.Uri,
): Promise<ReadonlyMap<string, PackagePathInfo>>

/** Analyze a single package's source code from its local cache path. */
export async function analyzePackageCode(
    packageRoot: vscode.Uri,
): Promise<PackageCodeMetrics>

/** Classify replacement complexity from metrics. */
export function classifyReplacement(
    metrics: PackageCodeMetrics,
): ReplacementComplexity
```

**Pattern:** Follows `import-scanner.ts` — uses `vscode.workspace.fs.readFile()` and `vscode.workspace.findFiles()` with `RelativePattern`.

**Caching:** Cache only `hosted` packages by `packageName@version` (immutable per version). Do **not** cache `path`/`git` packages long-term because contents can change in-place without version bumps.

### 2. MODIFY: `types.ts`

Add to `VibrancyResult`:
```typescript
readonly replacementComplexity: ReplacementComplexity | null;
```

Add `PackageCodeMetrics`, `ReplacementComplexity`, and `ReplacementLevel` type exports.

### 3. MODIFY: `extension-activation.ts` (enrichment step)

Add a post-scan enrichment step in `extension-activation.ts`, similar to how `isUnused` is enriched after the main scan. This keeps the main scan pipeline (which is network-bound) separate from the local filesystem analysis.

```typescript
// After scan completes, enrich with local code metrics:
const packagePaths = await resolvePackagePaths(workspaceRoot);
for (const result of results) {
    const localPath = packagePaths.get(result.package.name);
    if (!localPath) continue;
    const metrics = await analyzePackageCode(localPath);
    result.replacementComplexity = classifyReplacement(metrics);
}
```

**Why enrichment, not inline scan:** The main scan pipeline is network-I/O bound (pub.dev + GitHub API). Local filesystem reads are fast and independent. Running them in a separate enrichment pass (like unused detection) keeps the scan orchestrator focused on its job.

### 4. MODIFY: `providers/tree-item-builders.ts`

Add replacement complexity to the **Size group** (group 4), which already shows archive size and bloat rating:

```
📦 Size
  ├─ 1.2 MB (3/10 bloat)
  └─ Trivial — 25 lines in 2 files    ← NEW
```

For `native` level, show platforms:
```
  └─ Contains native code (ios, android)
```

### 5. MODIFY: `views/detail-view-html.ts`

Add a row in the VERSION section (alongside existing size/bloat display):

```html
<div class="detail-row">
  <span class="label">Source:</span>
  <span>25 code lines · 12 comment lines · 2 files</span>
</div>
<div class="detail-row">
  <span class="label">Replace:</span>
  <span class="trivial">Trivial — could inline</span>
</div>
```

### 6. MODIFY: `scoring/codelens-formatter.ts`

In `full` detail mode, append replacement complexity for `abandoned` / `end-of-life` packages:

```
3/10 Stale · Update 1.0 → 2.0 · Trivial to replace (25 LOC)
```

Only shown when `category` is `abandoned` or `end-of-life` AND level is not `large`/`native` — the point is to nudge action on feasible wins.

---

## What This Does NOT Change

- **Vibrancy score calculation** — replacement complexity is informational, not a scoring input. It answers "how hard to replace?" not "how healthy is this package?"
- **Problem types / diagnostics** — no new warnings. The data appears in tree, hover, detail, and codelens only. A future iteration could add a problem type like "trivially-replaceable-stale-dependency" but that's scope creep for now.
- **Bloat rating** — remains based on archive size. Replacement complexity is orthogonal (a 5 MB package with 25 LOC of Dart + 4.9 MB of assets has high bloat but trivial replacement complexity).

---

## Edge Cases

1. **Path dependencies** — `package_config.json` resolves these too. Analyze normally, but do not long-cache.
2. **Git dependencies** — Resolved via `package_config.json`. Analyze normally, but do not long-cache.
3. **SDK packages** (flutter, dart) — Skip explicitly using dependency source metadata (`source: sdk`).
4. **Packages with no lib/** — `libCodeLines: 0`, classified as `trivial`. Correct — if it has no library code, it's trivially replaceable (or it's a tool/executable).
5. **Packages with only generated code** — We count lines, not intent. A generated 5000-line file is still 5000 lines to replace. This is honest.
6. **Monorepo / nested pubspec** — `package_config.json` is per-project. We read the one next to the pubspec we found.

---

## Testing

### Unit tests (new file: `test/vibrancy/services/package-code-analyzer.test.ts`):

1. **Line counting:** Code vs comment vs blank classification
2. **Native detection:** Presence of ios/, android/ dirs
3. **Classification thresholds:** Each level boundary
4. **Summary formatting:** Human-readable output
5. **package_config.json parsing:** Valid and malformed input

### Manual validation:

- Run scan on a project with known small packages (e.g., `tuple`, `characters`)
- Verify LOC counts match manual inspection of pub cache
- Verify native detection for packages like `url_launcher`

---

## File Summary

| File | Action | Purpose |
|------|--------|---------|
| `services/package-code-analyzer.ts` | NEW | Core logic: resolve paths, count lines, classify |
| `types.ts` | MODIFY | Add `ReplacementComplexity` to `VibrancyResult` |
| `extension-activation.ts` | MODIFY | Add enrichment step after scan |
| `providers/tree-item-builders.ts` | MODIFY | Show in Size group |
| `views/detail-view-html.ts` | MODIFY | Show in detail sidebar |
| `scoring/codelens-formatter.ts` | MODIFY | Show for stale/EOL in full mode |
| `test/.../package-code-analyzer.test.ts` | NEW | Unit tests |
