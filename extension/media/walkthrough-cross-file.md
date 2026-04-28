# Cross-File Analysis

Project-wide checks catch issues that single-file linting cannot:

- Find unused Dart files.
- Detect circular import chains.
- Review import graph statistics.
- Review feature-to-feature dependencies.
- Find likely dead relative imports.
- Find likely unused top-level symbols.
- Export the dependency graph as DOT.
- Generate an HTML report for CI and sharing.

Run from the command palette:

- `Saropa Lints: Cross-File — Find Unused Files`
- `Saropa Lints: Cross-File — Detect Circular Dependencies`
- `Saropa Lints: Cross-File — Show Import Statistics`
- `Saropa Lints: Cross-File — Show Feature Dependencies`
- `Saropa Lints: Cross-File — Find Dead Imports`
- `Saropa Lints: Cross-File — Find Unused Symbols`
- `Saropa Lints: Cross-File — Export Import Graph (DOT)`
- `Saropa Lints: Cross-File — Generate HTML Report`
