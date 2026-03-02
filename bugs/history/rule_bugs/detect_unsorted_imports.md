2 new rules:

1. comprehensive rule: detect if import section is unsorted (A-Z) and offer quick fix to sort

2. stylistic rule: detect if imports are not grouped (with a newline gap). if not, offer a quick fix to group like imports (with /// code comment separator heading)

---

**Resolved:** Both rules implemented with quick fixes in v5.0.0-beta.12+.

- `prefer_sorted_imports` (Comprehensive tier) — detects unsorted imports within groups, quick fix sorts A-Z
- `prefer_import_group_comments` (Stylistic tier) — detects missing `///` section headers, quick fix adds headers and blank-line separators
- Shared `ImportGroup` utility extracted to `lib/src/import_utils.dart`
- Fixes bail out safely when comments exist between imports
