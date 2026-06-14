# Publish analyze step looped forever on the dogfood plugin-version error

When `saropa_lints` analyzes itself during a release, `dart analyze` reports the
plugin dependency as a version *constraint* (`^14.0.0`) while `pubspec.yaml`
holds the bare version (`14.0.0`). The publish script's mid-publish guard
compared the two values with plain string equality, so the leading caret made
the comparison fail. The guard fell through to the interactive
"[F]ix / [S]kip stale cache" prompt — which cannot resolve in this repo because
the package's own `analysis_options.yaml` carries no plugin `version:` pin to
edit. The "fix" path therefore reported "version field not found", cleared the
plugin-manager cache, retried `dart analyze`, hit the identical resolution error,
and re-presented the same prompt indefinitely. Analysis itself was clean ("No
issues found") the entire time; the loop was purely in the guard's version
comparison.

## Finish Report (2026-06-14)

### Scope
(C) docs/scripts only — publish tooling and changelog. No Dart lint rules,
analyzer plugin, tiers, or `example/` fixtures touched.

### Root cause
`_is_mid_publish_stale_plugin` in `scripts/modules/_publish_steps.py` ended with
`return pubspec_ver == stale_ver`. `pubspec_ver` comes from
`get_version_from_pubspec` as a bare version (`14.0.0`); `stale_ver` comes from
the analyzer error via `_detect_stale_plugin_version`, which captures the
dependency token including its constraint operator (`^14.0.0`). The two never
compared equal whenever the operator was present, so the benign mid-publish
state was misclassified as real drift.

### Fix
The comparison now strips a leading constraint operator before comparing:

```python
bare_stale = stale_ver.lstrip("^~>=< ")
return pubspec_ver == bare_stale
```

`lstrip("^~>=< ")` removes any leading run of `^ ~ > = < space`, normalizing
`^14.0.0`, `>=14.0.0`, `~14.0.0`, and a bare `14.0.0` all to `14.0.0`. The
analyzer error captures a single non-space token (the `(\S+)` group in
`_STALE_PLUGIN_RE`), so a compound range such as `>=14.0.0 <15.0.0` never reaches
this comparison as one token. Genuine drift (e.g. pin `^13.0.0` against pubspec
`14.0.0`) still compares unequal and returns False, preserving the downgrade-fix
path for the real-drift case.

### Behavior after the fix
At the mid-publish moment the guard returns True, the analyze step prints that
the stale pin matches local pubspec and treats analyze as passed, and the publish
proceeds without the un-resolvable interactive prompt. No production lint
behavior changes; this is publish-pipeline tooling only.

### Tests
`scripts/modules/tests/test_mid_publish_stale_plugin.py` (new) pins the
constraint-aware comparison: the caret case (the exact failure), `>=` and `~`
operators, a bare version, genuine drift returning False, a non-`saropa_lints`
plugin returning False, clean analyze output returning False, and a missing
pubspec failing safe to False. The caret assertion fails against the old
string-equality code and passes against the fix.

Command: `python -m unittest scripts.modules.tests.test_mid_publish_stale_plugin -v`
Result: 7 passed.

### Files changed
- `scripts/modules/_publish_steps.py` — constraint-operator strip in
  `_is_mid_publish_stale_plugin`, with a comment naming the loop it prevents.
- `scripts/modules/tests/test_mid_publish_stale_plugin.py` — new regression test.
- `CHANGELOG.md` — Maintenance entry under the Unreleased section (dev-only).
