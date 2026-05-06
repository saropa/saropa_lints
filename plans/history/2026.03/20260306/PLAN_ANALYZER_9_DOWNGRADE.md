**Resolved in: 8.0.0** — Shipped as v8.0.0 (analyzer 9, Flutter-compatible) with all rules/fixes from 7.x. 7.x retracted.

---

# Plan: Downgrade to Analyzer 9 (Flutter-compatible)

**Goal:** Make saropa_lints usable in Flutter projects again by downgrading to analyzer 9. Keep every rule and quick fix from v7; only change dependency constraints and AST API usage.

**Reason:** Analyzer 10+ (and saropa_lints 7.x) requires `meta ^1.18.0`. The Flutter SDK pins `meta` to `1.17.0`, so the solver never picks analyzer 10+ in Flutter apps/packages. Downgrading to analyzer 9 restores compatibility without losing any v7 content.

---

## 1. Dependencies (pubspec.yaml)

| Package | Current (v7) | Target (analyzer 9) |
|---------|--------------|---------------------|
| **analyzer** | ^10.0.0 | ^9.0.0 |
| **analysis_server_plugin** | ^0.3.10 | ^0.3.4 (last version that supports analyzer 9) |
| **analyzer_plugin** | ^0.14.0 | Resolve by `dart pub get` with analyzer 9; 0.3.4's pubspec will constrain it |
| **SDK** | >=3.10.0 <4.0.0 | Relax to match analyzer 9 / Flutter (e.g. >=3.6.0 <4.0.0) |
| **collection** | ^1.18.0 | Keep or relax if SDK is lowered |
| **meta** | (transitive) | Will resolve to 1.17.x in Flutter |

**Steps:**
- Set `analyzer: ^9.0.0`, `analysis_server_plugin: ^0.3.4`.
- Run `dart pub get` and fix any analyzer_plugin version conflict (use the version required by analysis_server_plugin 0.3.4).
- Lower SDK constraint if needed for analyzer 9 (e.g. `>=3.6.0 <4.0.0`).

---

*(Rest of plan content unchanged — see doc/PLAN_ANALYZER_9_DOWNGRADE.md in git history if needed.)*
