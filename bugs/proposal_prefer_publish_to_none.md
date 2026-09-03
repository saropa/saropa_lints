# PROPOSAL: Flag a Package `pubspec.yaml` Missing `publish_to: none` for a Private/App Package

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `prefer_publish_to_none` to flag a `pubspec.yaml` that describes an application (has a `flutter:` section with app-level keys, or lacks the metadata pub.dev requires — `description`/`homepage`/`repository`) but does not set `publish_to: none`, guarding against an accidental `dart pub publish`/`flutter pub publish` of a private app to the public pub.dev registry.

**Closes gap:** flutter_skill_lints `prefer_publish_to_none`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` flutter_skill_lints Gaps section.

---

## Motivation

`dart pub publish` with no `publish_to` field defaults to publishing to pub.dev. For an internal app (not a reusable package), that is almost always a mistake — and a costly one, since pub.dev publishes are effectively permanent (a version cannot be unpublished after a grace period, and the package name is claimed). `publish_to: none` is the documented, one-line guard against this, and it costs nothing for a project that genuinely has no publishing intent.

---

## Detection / Behavior

This is a project-configuration rule, not an AST rule — it inspects `pubspec.yaml` directly. Flag when: the `pubspec.yaml` has no `publish_to` key, AND the package appears to be an application rather than a library (heuristics: presence of a `flutter:` section with `uses-material-design`/asset declarations typical of an app, OR presence of `lib/main.dart`, OR absence of a `homepage`/`repository` field that pub.dev requires for a real publish to succeed anyway).

### Should flag (bad code)

```yaml
# pubspec.yaml
name: my_internal_app
description: Internal company app.
# LINT — no publish_to: none, and this looks like an app (has lib/main.dart), not a library
```

### Should pass (good code)

```yaml
# pubspec.yaml
name: my_internal_app
description: Internal company app.
publish_to: none # OK
```

```yaml
# pubspec.yaml
name: my_reusable_package
description: A published package.
homepage: https://github.com/org/my_reusable_package
repository: https://github.com/org/my_reusable_package
# OK — has publish metadata and no lib/main.dart; treated as an intentionally-publishable package
```

---

## Proposed Tier

Tier: Recommended
Justification: guards against an effectively-irreversible mistake (accidental public pub.dev publish) at negligible cost to add; the "app vs. package" heuristic risk of a false positive is low-severity (worst case, a one-line unnecessary suggestion), so it fits above the niche/style tiers.

---

## Edge Cases

1. **Melos/monorepo workspace root `pubspec.yaml` with no `lib/`** — should pass; a workspace-root manifest typically isn't a publishable unit itself; scope detection to packages with a `lib/` directory.
2. **A genuine library package under active development, not yet ready to publish, intentionally without `publish_to`** — should flag under the heuristic above only if it also lacks `homepage`/`repository`; a library with those fields present should be treated as intentionally publishable and not flagged. If this proves too noisy in practice, narrow the heuristic to `lib/main.dart` presence alone as the primary signal.
3. **`publish_to` explicitly set to a private pub server URL (not `none`)** — should pass; the author has made a deliberate publishing decision, which is exactly what this rule wants to confirm exists.
4. **Example app under `example/`** — already excluded from analysis project-wide per saropa's `example*/` exclusion convention; no special-casing needed here.

---

## Alternatives Considered

- **Only flag based on `lib/main.dart` presence, skip the metadata heuristic** — simpler and lower false-positive risk; worth strongly considering as the v1 heuristic, with the metadata check added later if `lib/main.dart`-only detection proves too narrow (e.g. misses non-Flutter Dart CLI apps without a conventional `main.dart` name).

---

## Decision

---

## Implementation Notes

---

## Commits
