# GitHub open issues (bug reports)

Each file in this folder is a local copy of an **open** GitHub issue for [saropa/saropa_lints](https://github.com/saropa/saropa_lints). When an issue corresponds to a rule that is already implemented (or is deferred/not viable), the file is moved to [bugs/history/](../history/) with a **Resolved in:** line and the GitHub issue is closed with the version number when applicable.

**Status (2026-03):** All issues that were tracked here (1–12, 21–54, 76, 92) have been resolved and moved to `bugs/history/`; the corresponding GitHub issues have been closed. This folder currently has no issue files. To track new open issues, refresh from GitHub (see below).

- **Naming:** `issue_NNN_slug_from_title.md` = GitHub issue #NNN plus a short slug from the issue title.
- **Content:** Title, GitHub URL, opened date, and full issue body (Detail).
- **Purpose:** Offline reference and tracking; always check the GitHub URL for latest comments and status.

To refresh from GitHub (requires `gh` CLI):

```bash
gh issue list --repo saropa/saropa_lints --state open --limit 100 --json number,title,body,url,createdAt
```

Then regenerate these files with a script that writes each issue to `issue_XXX.md`.

### Merged roadmap task specs

The following issue files had a corresponding task in `bugs/roadmap/`; that task content has been **merged into this folder's issue file** (GitHub issue as master, full roadmap spec appended under "## Roadmap task spec (merged from bugs/roadmap/...)"). The original task files were removed from `bugs/roadmap/` and their index lines removed from `bugs/roadmap/README.md`.

**Issues with merged roadmap content:** 22, 23, 31, 32, 37, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54.

**No roadmap task in bugs/roadmap/** (content only in this folder): prefer_avatar_loading_placeholder (27, 36), require_snackbar_duration_consideration (39), or the cross-file / “too complex” issues (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12). Issues 76 and 92 are bug reports (require_field_dispose cascade, max_issues config), not rule requests. Issue 21, 30 (avoid_pagination_refetch_all) is documented as not viable in ROADMAP.md § Rules reviewed and not viable.
