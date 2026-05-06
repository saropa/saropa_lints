# Bug: Package Vibrancy marks federated platform plugins with non-standard suffixes as "unused"

**Status:** Fixed  
**Date:** 2026-03-18  
**Fixed:** 2026-03-18 — Extended `isPlatformPlugin` in `extension/src/vibrancy/scoring/unused-detector.ts` with a parent-package heuristic: treat a package as a platform plugin when its name starts with an imported (non-SDK) package name plus `_` and has extra characters (e.g. `google_maps_flutter_ios_sdk10` when `google_maps_flutter` is in dependencies). Unit tests added.  
**Component:** VS Code extension — Package Vibrancy (unused dependency detection)  
**Severity:** Medium — false positive for packages like `google_maps_flutter_ios_sdk10`  
**Source:** Discussion; non-standard platform suffixes beyond the seven hard-coded ones

---

## Summary

Unused-package detection treated only packages whose names ended with one of seven hard-coded platform suffixes (e.g. `_android`, `_ios`, `_web`) as platform plugins. Federated plugins that use non-standard suffixes (e.g. `google_maps_flutter_ios_sdk10`) were reported as unused when the parent package was in dependencies. The fix adds a heuristic: if the package name starts with `parent_` for some imported (non-SDK) package `parent` and has more than `parent.length + 1` characters, it is treated as a platform plugin and not reported as unused.
