# Flutter Versions: Should You Upgrade If You Can?

**Yes, absolutely.** If your project's dependencies allow for an SDK upgrade without breaking the build, you should always stay as current as possible. 

The benefits are heavily weighted toward upgrading. Newer Flutter and Dart versions include major rendering engine upgrades (like Impeller) and compilation targets (like WebAssembly) that make your app physically faster and smoother without you changing a single line of code. Furthermore, delaying an upgrade creates massive technical debt. Jumping from 3.3 to 3.4 is painless; jumping from an abandoned 2.19 to 3.10 can take weeks of painful refactoring. **If you can upgrade, do it.**

---

## Dart & Flutter Version History, Impact & Package Minimums

Here is the updated table combining the timeline, the impact of the release, and real-world examples of major packages that use that specific version as their absolute floor.

| Version  | Release Date | Key Feature / Major Addition                        | Impact & Focus                   | Packages Requiring This Minimum |
| :------- | :----------- | :-------------------------------------------------- | :------------------------------- | :------------------------------ |
| **3.0**  | May 10, 2023 | 100% sound null safety required, records, patterns. | Forced ecosystem modernization   | `provider`, `go_router`, `dio`  |
| **3.1**  | Aug 16, 2023 | `NativeCallable.listener` for C FFI.                | Smoother native C-bindings       | `url_launcher`                  |
| **3.2**  | Nov 15, 2023 | Non-null type promotion for private final fields.   | Less boilerplate null-checking   | `uuid`, `connectivity_plus`     |
| **3.3**  | Feb 15, 2024 | Extension types and revamped JS interop.            | Zero-cost wrapper objects        | `drift`, `saropa_drift_advisor` |
| **3.4**  | May 14, 2024 | Wasm compilation and experimental macros.           | Faster web app load times        | `image_picker`                  |
| **3.5**  | Aug 6, 2024  | Stable Web/JS interop (required for Wasm).          | Full Wasm readiness              | `firebase_core`                 |
| **3.6**  | Dec 11, 2024 | Digit separators (`1_000`) and pub workspaces.      | Lower IDE memory usage           | `sqflite`                       |
| **3.7**  | Feb 12, 2025 | Wildcard variables (`_`) and new formatter style.   | Cleaner code & strict formatting | **`riverpod`**                  |
| **3.8**  | May 20, 2025 | Null-aware collection elements.                     | Safer, cleaner UI collections    | `freezed`                       |
| **3.9**  | Aug 13, 2025 | Null safety assumed for reachability.               | Stricter dependency resolution   | **`shared_preferences`**        |
| **3.10** | Nov 12, 2025 | Dot shorthands for enums and statics.               | Faster typing for UI widgets     | `flutter_animate`               |
| **3.11** | Feb 11, 2026 | Purely focused on IDE support and analyzer fixes.   | Improved code completion         | *(Most haven't bumped yet)*     |

---

## Upgrade Blast Radius: Why Is "Newer Version Available" Missing?

pub.dev's latest version is not always one you can adopt. Before Package Vibrancy nudges you to upgrade a package, it checks what that upgrade would break. Each package gets one verdict; when several apply, the first in this list wins.

| Verdict                | Meaning                                                                                                   |
| :--------------------- | :-------------------------------------------------------------------------------------------------------- |
| `held-back`            | The target version is on the curated held-back list (see below).                                          |
| `sdk-blocked`          | The target version needs a dependency version that the Flutter SDK pins to something else.               |
| `dependency-held-back` | The target version needs a dependency range that only a held-back version of that dependency can satisfy. |
| `breaks-dependents`    | One or more packages that depend on it declare a version range that excludes the target.                 |
| `safe`                 | Nothing found; the upgrade is offered as normal.                                                          |

Any verdict other than `safe` replaces the plain "newer version available" nudge with a one-line explanation of what blocks it (for example, "analyzer 13.1.0 needs meta ^1.18.3; Flutter pins meta 1.18.0").

### How the checks are derived

- **SDK pins.** The extension reads the Flutter SDK's own package pubspecs (for example, `flutter` depends on `meta: 1.18.0`) and cross-checks them against the version locked in `pubspec.lock`. Only if nothing can be derived (no Flutter SDK found, or a non-Flutter project) does it fall back to a built-in table of known pins.
- **Target-version dependencies.** The dependency ranges of the version you would upgrade to are fetched, then compared with the SDK pins and with the full lock file, so a transitive dependency you already satisfy is not reported as a blocker.
- **Dependents.** The ranges that your other packages declare on the package are compared with the target version.

### The held-back list

Some upgrades are known to break this kind of project even though pub.dev offers them. `extension/src/vibrancy/scoring/held-back-upgrades.ts` lists each package, the range of target versions to avoid, and the reason shown to you. For example, `analyzer >=13.0.0` is held back because it needs `meta ^1.18.3` while Flutter stable pins `meta 1.18.0`.

### Bulk updates

**Update All** skips every package whose verdict is not `safe`. Skipped packages are listed with the blast-radius explanation as the reason, so nothing is silently left behind. Upgrade them individually once the blocker is resolved.

### Refreshing the known issues data

The built-in known issues library (`extension/src/vibrancy/data/known_issues.json`) can be refreshed from pub.dev with `scripts/pubdev_snapshot.py`:

```
python scripts/pubdev_snapshot.py snapshot          # fetch pub.dev facts (network)
python scripts/pubdev_snapshot.py apply --dry-run   # preview the offline update
python scripts/pubdev_snapshot.py apply
```

`apply` only refreshes machine-derivable fields (last updated, pub points, archive size, verified publisher, platforms, and the `as_of` date). Hand-written text, `status` and `replacement` are never rewritten; changes that matter for those (discontinued, replaced, license drift) are printed as a flagged report for you to review. `--only NAME` limits a run to specific packages.
