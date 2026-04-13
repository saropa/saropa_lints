# Extension Command Discoverability

> **Created:** 2026-04-13
> **Status:** ✅ IMPLEMENTED
> **Scope:** Entire VS Code extension (all 115+ commands, all feature areas)

## Problem

The extension has 115+ registered commands. The VS Code command palette presents them as a flat, unsearchable-by-category list. Users who type "Saropa" see a wall of entries with no grouping, no descriptions beyond the title, and no indication of which commands are available in their current state.

Consequences:
- **Features go unused.** Cross-file analysis, OWASP export, package comparison, SBOM export, and many other commands are effectively invisible unless users already know they exist.
- **New features are dead on arrival.** Every new command added to the extension (cross-file, future phases) inherits this invisibility problem.
- **Support burden.** Users ask "how do I do X?" when the command already exists — they just can't find it.

This is not a cross-file-specific problem. It affects every feature area: analysis, reporting, package vibrancy, security, filtering, configuration, and views.

---

## Current UX Surface Inventory

The extension already has rich interaction surfaces — the problem is not a lack of UI, but a lack of a central place that ties them together.

| Surface | Count | Purpose |
|---------|-------|---------|
| Command palette entries | 115+ | Flat list, no categories, no descriptions |
| Tree views (sidebar) | 10 | Overview, Issues, Summary, Config, Suggestions, Security Posture, File Risk, TODOs, Drift Advisor, Package Vibrancy |
| Webview panels | 7 | About, Rule Explain, Vibrancy Report, Package Comparison, Known Issues, Package Detail, Rule Packs |
| Walkthrough steps | 6 | Health Score, Violations, Security, Triage, Trends, About |
| Status bar items | 1 unified | Score, tier, delta |
| Context menus | 80+ entries | Across view/title, view/item/context, editor/title, editor/context |
| Code lens providers | 2 | Dart file violations, pubspec vibrancy badges |
| Welcome views | 2 | Non-Dart project intro, no-analysis-yet prompt |

---

## Solution 1: Command Catalog Webview

A searchable, categorized webview that lists every command the extension offers.

### Command

`saropaLints.showCommandCatalog` / "Saropa Lints: Browse All Commands"

### Design

- **Full-screen webview panel** (singleton pattern, like About or Vibrancy Report panels)
- **Categorized sections** with collapsible headers:
  - Setup & Configuration
  - Analysis
  - Cross-File Analysis
  - Violations & Filtering
  - Rules & Fixes
  - Reporting & Export
  - Security Posture
  - Package Vibrancy
  - TODOs & Hacks
  - Drift Advisor
  - Views & Navigation
- **Each command entry shows**:
  - Icon (codicon)
  - Title (human-readable, not the command ID)
  - Description (one-liner explaining what it does and when to use it)
  - Keyboard shortcut (if bound)
  - State indicator: enabled or disabled with reason
- **Search/filter bar** at top — filters by title or description as user types
- **Click to execute** — each entry is a button that runs the command via `postMessage` → `vscode.commands.executeCommand()`
- **Disabled entries show why** — tooltip with human-readable prerequisite (e.g., "Run analysis first", "Open a Dart project", "Run a vibrancy scan first") instead of the raw context key expression

### Data Source

Static TypeScript registry — not scraped from package.json at runtime. Each entry:

```typescript
interface CatalogEntry {
  /** VS Code command ID, e.g., 'saropaLints.crossFile.graph' */
  command: string;

  /** Human-readable title, e.g., 'Export Import Graph (DOT)' */
  title: string;

  /** One-liner explaining what this does and when to use it */
  description: string;

  /** Category for grouping in the catalog */
  category: CatalogCategory;

  /** Codicon name, e.g., 'type-hierarchy' */
  icon: string;

  /**
   * Runtime check — returns true if the command can run right now.
   * When false, the entry appears grayed out with disabledReason as tooltip.
   */
  enabledWhen?: () => boolean;

  /** Human-readable explanation shown when the command is disabled */
  disabledReason?: string;
}

type CatalogCategory =
  | 'Setup & Configuration'
  | 'Analysis'
  | 'Cross-File Analysis'
  | 'Violations & Filtering'
  | 'Rules & Fixes'
  | 'Reporting & Export'
  | 'Security Posture'
  | 'Package Vibrancy'
  | 'TODOs & Hacks'
  | 'Drift Advisor'
  | 'Views & Navigation';
```

### Why a Webview, Not a Tree View

Tree views are the right choice for data (violations, packages, files). They are wrong for a command catalog because:
- No inline search/filter
- No multi-line descriptions
- No click-to-execute with visual feedback
- No flexible layout (icons + title + description + shortcut in one row)

A webview with HTML/CSS provides all of these.

### Why Not a Quick Pick

A quick pick (`showQuickPick`) could work for a flat list with search, but:
- No categories/grouping — it's still a flat list
- No persistent view — disappears after selection
- No disabled-with-reason entries
- No rich layout (icon + description + shortcut)

The catalog is meant to be browsable, not just searchable.

### Implementation Files

| File | Purpose |
|------|---------|
| `extension/src/views/commandCatalogView.ts` | Webview provider, HTML generation, postMessage handler for command execution |
| `extension/src/views/commandCatalogRegistry.ts` | Static catalog data — all 120+ entries with categories, descriptions, enablement |
| `extension/package.json` | Register `saropaLints.showCommandCatalog` command |
| `extension/src/extension.ts` | Register catalog command in `activate()` |

### Maintenance

The catalog registry is a static file that must be updated when commands are added or removed. To prevent staleness:

- Add a test that compares `commandCatalogRegistry.ts` entries against `package.json` `contributes.commands` — fail if any command is missing from the registry or if the registry references a command that doesn't exist in package.json.
- Document in CONTRIBUTING.md: "When adding a new command, add it to the command catalog registry."

---

## Solution 2: Enablement Over Hiding

**Principle**: Never use `when` clauses to hide commands from the command palette. Use `enablement` conditions instead, so the command is always visible but grayed out when prerequisites aren't met.

### Why This Matters

- `when: false` makes the command invisible — the user doesn't know it exists
- `enablement: "saropaLints.isDartProject"` makes the command visible but grayed out — the user sees it exists and learns what it needs
- This is the difference between "this extension can't do that" and "this extension can do that once I open a Dart project"

### Current State

8 commands currently use `when: false` to hide from the command palette. These should be audited:

- If internal-only (never user-facing): keep `when: false`
- If user-facing but conditional: convert to `enablement` with a descriptive context key

### Enablement Tooltip Quality

VS Code shows the raw enablement expression as a tooltip (e.g., `saropaLints.isDartProject`). These context key names should be human-readable enough that users understand them. Current context keys to review:

| Context Key | User Sees | Clear Enough? |
|-------------|-----------|---------------|
| `saropaLints.isDartProject` | "saropaLints.isDartProject" | Passable — "is Dart project" is understandable |
| `saropaLints.hasViolations` | "saropaLints.hasViolations" | Passable |
| `saropaLints.packageVibrancy.hasResults` | "saropaLints.packageVibrancy.hasResults" | Okay — "has results" implies "run scan first" |

VS Code does not support custom tooltip text for enablement — only the expression itself. This is a limitation. The command catalog webview (Solution 1) solves this by showing custom `disabledReason` strings.

---

## Solution 3: Walkthrough Expansion

The current walkthrough has 6 steps covering: Health Score, Violations, Security, Triage, Trends, About.

### Missing Coverage

These feature areas have no walkthrough steps:
- **Cross-file analysis** — unused files, circular deps, import graph
- **Package vibrancy** — dependency health scanning, SBOM, upgrade planning
- **Command catalog** — how to find and browse all commands
- **TODOs & Hacks** — workspace-wide TODO/HACK scanning
- **Reporting** — OWASP export, JSON export, HTML reports

### Proposed New Steps

Add after the existing steps (keeping the current 6 intact):

| Step | Title | Completion Event | Description |
|------|-------|-----------------|-------------|
| 7 | Package Health | `onCommand:saropaLints.packageVibrancy.scan` | Scan dependencies for health, version gaps, known issues. Export SBOM. |
| 8 | Cross-File Analysis | `onCommand:saropaLints.crossFile.unusedFiles` | Find unused files, circular dependencies, and export import graphs across the whole project. |
| 9 | Browse All Commands | `onCommand:saropaLints.showCommandCatalog` | 115+ commands organized by category with search. Find any feature instantly. |

Each step needs a `media/walkthrough-*.md` file with:
- What the feature does and why it matters
- How to invoke it (command palette search term, or "click here" link)
- Screenshot or example output

---

## Solution 4: Welcome View Enhancement

The existing welcome views show when no Dart project is open or no analysis has run. Add a link to the command catalog:

```
No analysis results yet.

[Run Analysis](command:saropaLints.runAnalysis)
[Browse All Commands](command:saropaLints.showCommandCatalog)
[Getting Started](command:saropaLints.openWalkthrough)
```

This gives new users a path to discover features before they've run anything.

---

## Implementation Priority

1. **Command catalog webview** — highest impact; makes all commands discoverable in one place
2. **Enablement audit** — convert hidden commands to disabled-with-reason
3. **Walkthrough expansion** — guided onboarding for major feature areas
4. **Welcome view links** — low effort, connects new users to the catalog

---

## Deliverables

- [x] `extension/src/views/commandCatalogView.ts` — webview provider with search, categories, click-to-execute
- [x] `extension/src/views/commandCatalogRegistry.ts` — static catalog data for all 117 commands
- [x] `extension/package.json` — register `saropaLints.showCommandCatalog` command
- [x] `extension/src/extension.ts` — register catalog in `activate()`
- [ ] Test: catalog registry vs package.json sync check
- [x] Audit `when: false` commands — 7 copy-as-JSON converted to `saropaLints.isDartProject`, 6 truly internal kept hidden
- [x] 3 new walkthrough steps (Package Health, TODOs & Hacks, Browse Commands) + media markdown files
- [x] Welcome view update — add command catalog link to both welcome views
- [ ] CONTRIBUTING.md update — document catalog registry maintenance requirement

---

## References

- [VS Code Webview API](https://code.visualstudio.com/api/extension-guides/webview)
- [VS Code Walkthrough API](https://code.visualstudio.com/api/references/contribution-points#contributes.walkthroughs)
- [VS Code enablement vs when](https://code.visualstudio.com/api/references/when-clause-contexts)
- Cross-file commands that depend on this plan: [cross_file_cli_design.md Phase 5](cross_file_cli_design.md)
