# Full Audit Sidebar Button Missing

The v15.2.5 changelog documented a "Full Audit sidebar button" in the extension sidebar, but the implementation was incomplete. The `saropaLints.fullAudit` command was registered in `package.json` and wired in `extension.ts`, but no `LeafItem` was added to `buildEditorDashboardItems()` in `sectionedSidebar.ts`. The button was only accessible via the Command Palette.

## Finish Report (2026-08-30)

### Changes

- **`extension/src/views/sectionedSidebar.ts`** — added a `LeafItem` for "Full Audit" between Findings Dashboard and Command Catalog. Uses `l10n()` for label and description. Shield icon with `charts.red` theme color.
- **`extension/src/i18n/locales/en.json`** — added `fullAudit.sidebar.label` ("Full Audit") and `fullAudit.sidebar.description` ("All rules · scope picker · filterable report") keys.
- **`CHANGELOG.md`** — created `[15.2.6] — Unreleased` section with the fix entry.

- **`extension/package.json`** — added `saropaLints.fullAudit` to the `view/title` menu for `saropaLints.editorDashboards`, gated on `saropaLints.isDartProject`. Provides a one-click shield icon in the view header.

### Not Changed

- Translation catalogs not regenerated — requires interactive `generate_translations.py` run.

### Verification

- Code review (low): clean, no findings.
- No TypeScript test suite exists for sidebar tree items.
