# Package Vibrancy — trusted-publisher band promotion symmetry

The Package Vibrancy status classifier promoted a trusted-publisher package one
band only when it landed in the "stable" tier (lifting it to "vibrant"). A mature,
finished first-party package — for example `path_provider`, which publishes rarely
precisely because it is complete — can score into the lower "outdated" band on low
GitHub churn and long release gaps. In that band the trusted-publisher signal was
ignored, so a healthy flutter.dev/dart.dev/google.dev/firebase.google.com package
could read as "outdated" purely on age and churn. The `pubPoints >= 140` floor only
blocks the "abandoned" label, not "outdated", so it did not cover this case.

## Finish Report (2026-06-14)

### Scope

(B) VS Code extension (TypeScript). No Dart lint rules, analyzer plugin, `example/`,
or `analysis_options*.yaml` touched.

### Change

`classifyStatus` in `extension/src/vibrancy/scoring/status-classifier.ts` now lifts a
trusted publisher one band from either starting tier:

- `stable` → `vibrant` (pre-existing behavior, retained)
- `outdated` → `stable` (new)

Promotion fires exactly once — it is not a cascade, so an `outdated` trusted-publisher
package settles at `stable`, never jumping two bands to `vibrant`. The `abandoned`
band and the hard end-of-life overrides (known-issue end_of_life, discontinued,
archived — all of which return early before this block) are intentionally left
untouched: a trusted publisher scoring below 20 with low pub points is a genuine
anomaly and is not rescued.

### Why this shape

The two band lifts are expressed as separate guarded `return`s inside a single
`isTrustedPublisher` check, rather than two independent `if` statements that mutate
`category`. Independent statements would let the `outdated` → `stable` rewrite fall
through into the `stable` → `vibrant` rewrite, producing the unwanted two-band
cascade. The single-block form guarantees one promotion per call.

### Logic & safety review

- No new shared state, no recursion, no async; the function remains a pure mapping
  from score/metadata to a `VibrancyCategory`.
- The end-of-life and discontinued overrides return before the promotion block, so
  trust can never resurrect a dead package.
- Casing remains exact-match via `isTrustedPublisher` (the existing `Dart.dev`
  false-positive guard test still passes), so the new branch inherits the same
  strict publisher-id matching.
- No user-facing strings added or changed: the `VibrancyCategory` values are internal
  enum identifiers, and the human-readable badge text comes from the pre-existing
  `categoryLabel` map. No `en.json` edit, so no catalog regeneration is required.

### Tests

`extension/src/test/vibrancy/scoring/status-classifier.test.ts` gained two cases:

- a `path_provider`-shaped `flutter.dev` package scoring in the `outdated` band is
  promoted to `stable` (and explicitly asserted NOT `vibrant`, pinning the
  no-cascade guarantee);
- a non-trusted `example.com` package in the `outdated` band stays `outdated`.

Existing assertions — the `stable` → `vibrant` promotions, the casing false-positive
guard, the end-of-life/discontinued overrides, and the pub-points floor — are
unchanged and still pass.

Command run:

```
node ./node_modules/typescript/bin/tsc -p tsconfig.test.json
node node_modules/mocha/bin/mocha "out-test/test/vibrancy/scoring/status-classifier.test.js" --timeout 10000
```

Result: 36 passing. Full extension type-check (`tsc --noEmit`) clean.

### Files changed

- `extension/src/vibrancy/scoring/status-classifier.ts` — band-promotion logic.
- `extension/src/test/vibrancy/scoring/status-classifier.test.ts` — two new cases.
- `CHANGELOG.md` — one `[Unreleased]` → Fixed (Extension) bullet.

### Outstanding work

None. The change is self-contained.
