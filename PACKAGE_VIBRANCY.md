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

| Verdict                | Meaning                                                                                                                                 |
| :--------------------- | :-------------------------------------------------------------------------------------------------------------------------------------- |
| `held-back`            | The target version is on the curated held-back list (fallback; see below).                                                              |
| `sdk-blocked`          | The target version needs a dependency version that the Flutter SDK pins to something else.                                              |
| `dependency-capped`    | The target needs a dependency version your lock file does not have, and another package in your project caps that dependency below it. The message names the capper. |
| `dependency-held-back` | Same need, but decided only by the curated list because lock or range data was unavailable.                                             |
| `breaks-dependents`    | One or more packages that depend on it declare a version range that excludes the target.                                                |
| `safe`                 | Nothing found; the upgrade is offered as normal.                                                                                        |

Any verdict other than `safe` replaces the plain "newer version available" nudge with a one-line explanation of what blocks it (for example, "analyzer 13.1.0 needs meta ^1.18.3; Flutter pins meta 1.18.0"). When the latest version is blocked, the newest version you can still take is suggested as **Newest compatible**. Retracted releases are never offered.

### How the checks are derived

- **SDK pins.** The extension reads the installed Flutter SDK's own package pubspecs (for example, `flutter` depends on `meta: 1.18.0`). Only exact pins count; a caret range such as `^1.2.0` is a range, not a pin. Only if the SDK cannot be inspected does it fall back to a built-in table of known pins.
- **Full lock file.** All of `pubspec.lock`, including transitive packages, is read, so a dependency you already satisfy is not reported as a blocker.
- **Target-version dependencies.** The dependency ranges of the version you would upgrade to come from pub.dev per version and are cached, then compared with the SDK pins and the lock file.
- **Dependents.** The ranges that your other packages declare on the package are compared with the target version.

### The held-back list (fallback only)

`extension/src/vibrancy/scoring/held-back-upgrades.ts` lists packages and target-version ranges known to break this kind of project (for example `analyzer >=13.0.0`, which needs `meta ^1.18.3` while Flutter stable pins `meta 1.18.0`). It is used only when lock and range data cannot decide. When they can, they win: if the needed version is not capped by anything in your project, the upgrade is not blocked whatever the list says.

### Bulk updates

**Update All** skips every package whose verdict is not `safe`. Skipped packages are listed with the blocker as the reason, so nothing is silently left behind. Upgrade them individually once the blocker is resolved.

## Known-Issue Statuses

Curated entries in the known-issues library drive the status shown for a package.

| Status             | Shown as / meaning                                                                                   |
| :----------------- | :--------------------------------------------------------------------------------------------------- |
| `end_of_life`      | The package itself is dead. Replace it.                                                              |
| `upgrade_required` | The package is alive but your installed old major is known-broken (shown as **Upgrade Required**). The fix is to upgrade. |
| `maintenance_mode` | Note only: the package receives little more than fixes.                                              |
| `caution`          | Note only: use with care; see the reason.                                                            |

Notes are also shown for unlisted packages and when a status "may be outdated".

**Version bounds.** An entry with `appliesToMinVersion` / `appliesToMaxVersion` applies only to installed versions in `[min, max)`: min is inclusive, max is exclusive. Outside that window the entry is ignored.

**Vulnerabilities.** With the vulnerability scan enabled, each installed package version is checked against OSV (optionally merged with GitHub advisories) and shown with a severity.

## Maintaining the known-issues data

The data lives in `extension/src/vibrancy/data/known_issues.json`, validated by `known_issues_schema.json` in the same folder. Each entry needs `name`, `status` and `as_of`.

Rule of thumb for `status`: package dead, no fix except replacing it, use `end_of_life`; package alive but an old major is broken, use `upgrade_required` with version bounds; slow but usable, `maintenance_mode`; risky or contested, `caution`.

`scripts/pubdev_snapshot.py` refreshes the machine-derivable facts from pub.dev:

```
python3 scripts/pubdev_snapshot.py snapshot            # fetch pub.dev facts (network)
python3 scripts/pubdev_snapshot.py apply --dry-run     # preview the offline update
python3 scripts/pubdev_snapshot.py apply
python3 scripts/pubdev_snapshot.py selftest            # built-in flag self-test
```

`apply` only refreshes last updated, pub points, archive size, verified publisher, platforms and `as_of`. Hand-written text, `status` and `replacement` are never rewritten; changes that matter for them are printed as flags for you to review. `--only NAME` limits a run; `--strict` fails when un-refreshed entries have an `as_of` older than 90 days.

| Flag                                                                                                             | Meaning                                                              |
| :--------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------- |
| `revived`                                                                                                        | An unbounded `end_of_life` package released within 12 months.        |
| `stale`                                                                                                          | An `active` package 12+ months old with corroborating weak signals.  |
| `bounded-includes-latest`, `bounded-min-gt-max`, `bounded-above-all`, `bounded-template-reason`, `bounded-recent-release` | Sanity checks on version-bounded entries.                            |
| `replacement-404`, `replacement-discontinued`, `replacement-chain`, `replacement-cycle`                          | The named replacement is missing, discontinued or circular.          |
| `retracted-latest`                                                                                               | The latest release was retracted.                                    |
| `advisories`                                                                                                     | pub.dev lists security advisories.                                   |
| `dead-data`                                                                                                      | Informational: a tracked name that 404s or is not a real package.    |
| `stale-as-of`                                                                                                    | Entry not refreshed and its `as_of` is over 90 days old.             |
