# Plan: Package migration-pack coverage (driven by a real app's pubspec)

**Status:** living index. Source of candidate packages: the Saropa Contacts app
pubspec (`D:\src\contacts\pubspec.yaml`) — a real, shipping Flutter app whose
~95 direct dependencies are a high-signal list of packages worth migration-pack
coverage. This index ranks them and links one `plan_migration_<package>.md` per
candidate.

**Relationship to the pack system:** the *mechanism* is already shipped — see
[plan_migration_plugin_system.md](plan_migration_plugin_system.md). Semver-gated
migration packs exist (`collection_compat`, `riverpod_2`, `dio_5`) plus the
`*_sdk_*` packs. This index is about **coverage**: none of the high-churn
packages a real app ships are covered by a version-gated migration pack yet.

---

## 1. What a "migration pack" is (vs a package rules file)

| | Package rules file (`lib/src/rules/packages/<x>_rules.dart`) | Migration pack (semver-gated) |
|---|---|---|
| Purpose | Correct/safe *current* usage | Detect **old-version** API → recommend **new-version** API |
| Gate | None (on whenever tier on) | `RulePackDependencyGate` on resolved version |
| Example | `drift_rules.dart` (~31 correctness rules) | `dio_5` flags `DioError` (removed in 5.0 → `DioException`) |
| Precedent | 24 files exist | `riverpod_2`, `dio_5`, `collection_compat` |

A package can have **both**: a correctness file *and* a migration pack. The two
are independent.

---

## 2. The reusable recipe (extracted from `riverpod_2` and `dio_5`)

Every `plan_migration_<package>.md` is a fill-in of these steps. Do NOT re-derive
them per plan — link here.

1. **Rule(s) + fix.** Add detection rule(s) for the *old* API to
   `lib/src/rules/packages/<package>_rules.dart` (create the file if absent),
   extending `SaropaLintRule`. Add a `DartFix` that rewrites old → new where the
   transform is mechanical.
2. **Register.** Add `MyRule.new` to `_allRuleFactories` in
   `lib/saropa_lints.dart`; add the rule code to a tier set in
   `lib/src/tiers.dart`.
3. **Dependency gate.** Add to `kRulePackDependencyGates` in
   `lib/src/config/rule_packs.dart`:
   `'<package>_<major>': RulePackDependencyGate(dependency: '<package>', constraint: '>=X.0.0')`.
4. **Pack definition.** Add the gated pack id + its dependency name(s) and title
   in `tool/generate_rule_pack_registry.dart` (the gate-dep map and title map,
   alongside the `dio_5` / `riverpod_2` entries).
5. **Relocate the rule code into the gated pack.** Add to
   `kRelocatedRulePackCodes` in `tool/rule_pack_audit.dart`:
   `'<rule_code>': (fromPack: '<package>', toPack: '<package>_<major>')`. This is
   the load-bearing step — it moves the version-gated rule out of the ungated
   package pack so a project on the *old* version is never told to adopt an API
   that does not exist there.
6. **Regenerate.** `dart run tool/generate_rule_pack_registry.dart` (run twice —
   the TS writer reads the compiled registry), then `dart format`.
7. **Test.** `test/config/` — gate + ownership + merge (mirror
   `rule_packs_semver_test.dart`). `test/rules/packages/<package>_rules_test.dart`
   — detection + fix.
8. **Verify.** `dart run tool/rule_pack_audit.dart` exit 0; `dart analyze
   --fatal-infos` clean.

**Gate-direction note — two archetypes (key insight from P1 research):** the
right gate direction depends on **whether the old API still compiles on the new
version.**

- **Post-upgrade cleanup (`>=` gate).** Old API is *deprecated but still
  compiles*. The analyzer is silent, so the lint is the only nudge. Gate on the
  **new** major; flag lingering old-API usage. Matches `dio_5` (flag `DioError`
  only when `dio >=5.0.0`), `riverpod_2`, and P1's `share_plus_11`,
  `sensors_plus_4`, `flutter_svg_2`. **Highest value** — this is the gap the
  compiler does NOT already cover.
- **Pre-upgrade readiness (`<` gate).** Old API is *removed* in the new major, so
  on the new version it does not compile and `dart analyze` already errors — a
  `>=` pack would find nothing. Gate on the **old** major instead; flag current
  (valid) code that will break on the bump, as opt-in upgrade prep. Used by P1's
  `google_sign_in_7`, `webview_flutter_4`, `connectivity_plus_6`. **Medium
  value**, and depends on a maintainer decision to support `<` gates (a new
  archetype — all shipped gates are `>=`). See
  [plan_migration_google_sign_in.md §5](plan_migration_google_sign_in.md#5-open-decision-needs-maintainer-call).

**Corollary for ranking:** "removed in vN" reads like a big migration but is
*weaker* lint territory than "deprecated in vN," because the compiler already
forces removed-API migrations. Weight deprecated-but-compiling APIs highest.

---

## 3. Coverage map (contacts packages → status)

Legend: **RF** = has a `*_rules.dart` correctness file. **MP** = has a
version-gated migration pack. **Cand** = migration-pack candidate (this index).

| Package (contacts version) | RF | MP | Migration headline | Notes |
|---|---|---|---|---|
| `collection` ^1.19.1 | — | ✅ `collection_compat` | `flattenedToList` etc. | Already applies to contacts |
| `flutter_bloc` ^9.1.1 | ✅ bloc | — | bloc 8→9 deprecations | Cand (lower) |
| `drift` ^2.33 | ✅ drift | — | API stable across 2.x | Low |
| `firebase_*` | ✅ firebase | — | modular API migration | Cand (lower) |
| `supabase_flutter` ^2.14 | ✅ supabase | — | v1→v2 auth | Cand (lower) |
| `geolocator` ^14.0 | ✅ geolocator | — | v14 `LocationSettings` | Cand (lower) |
| `url_launcher` ^6.3 | ✅ url_launcher | — | `launch`→`launchUrl` (old) | Low |
| `isar_community` ^3.3 | ✅ isar | — | fork-frozen | Low |
| `mobile_scanner` ^7.2 | ✅ qr_scanner | — | v5→v7 controller API | Cand |
| **`google_sign_in` ^7.2** | — | — | **v7 auth/authorize rewrite, `signIn`→`authenticate`** | **Cand P1 — researched** |
| **`share_plus` ^13.1** | — | — | **`Share.share*`→`SharePlus.instance.share(ShareParams)`** | **Cand P1 — researched, [plan](plan_migration_share_plus.md)** |
| `connectivity_plus` ^7.1 | — | — | v6 single→`List<ConnectivityResult>` | Cand P1 — research pending |
| `sensors_plus` ^7.0 | — | — | v4 event-getter→stream-function | Cand P1 — research pending |
| `flutter_svg` ^2.3 | — | — | v2 `color`→`colorFilter` | Cand P1 — research pending |
| `webview_flutter` ^4.13 | — | — | v4 `WebView`→`WebViewWidget`+`WebViewController` | Cand P1 — research pending |
| `audioplayers` ^6.7 | — | — | v5/v6 `AudioCache`/`play(Source)` rewrite | Cand P2 — research pending |
| `app_links` ^7.1 | — | — | v3→v6 `getInitialLink`/stream changes | Cand P2 — research pending |
| `file_picker` 12.0-beta | — | — | v5→v8 `FileType`/`withData` churn | Cand P2 — research pending |
| `permission_handler` ^12 | — | — | mostly stable | Low |
| `image_picker` ^1.2 | — | — | `pickImage`→`pickMedia`? | Cand P3 |
| `local_auth` ^3.0 | — | — | v2 `authenticate` signature, `BiometricType` | Cand P3 |
| `google_maps_flutter` ^2.17 | — | — | stable-ish | Low |
| `flutter_contacts` (fork 1.x) | — | — | v1→v2 (app-specific fork) | Out of scope (fork) |
| `cached_network_image*` | — | — | `color`/builder changes | Low |
| `intl` ^0.20 | — | — | minor | Low |
| `package_info_plus` ^10 | — | — | stable | Low |

(The long tail of stable utility packages — `crypto`, `uuid`, `path`, `meta`,
`logging`, `http`, `xml`, `html`, `archive` — has no meaningful migration surface
and is intentionally omitted.)

---

## 4. Priority tranche (re-ranked after P1 research)

**Selection criterion (3 tests):** a migration pack earns its keep when the old
API is (a) **statically detectable** (a named symbol / constructor / method, not
a behavioral change), (b) **mechanically fixable** (deterministic rewrite), and
— the decisive one — (c) **still compiles** on the relevant gate version (else
the compiler already does the job; see §2 gate-direction note).

**Tier A — deprecated-but-compiles, mechanical fix (post-upgrade `>=`, highest value):**
`share_plus_11` ✅ plan, `sensors_plus_4` ✅ plan, `flutter_svg_2` ✅ plan.
These are where saropa_lints uniquely adds value over `dart analyze`.

**Tier B — removed API, pre-upgrade `<` gate (medium value, needs gate-archetype sign-off):**
`google_sign_in_7` ✅ plan, `connectivity_plus_6` ✅ plan, `webview_flutter_4` ✅ plan.

**P2 (research pending):** `audioplayers_6` (deprecated `AudioCache`/`play` — likely
Tier A), `app_links_6`, `file_picker_8`, `mobile_scanner_7`.

**P3 / lower:** `local_auth_2`, `image_picker`, `flutter_bloc_9`, `supabase_2`,
`geolocator_14`, `firebase_modular`.

**Note on the driving app:** the contacts app is already on the *new* major for
every Tier A/B package and has no lingering old-API call sites (greped:
no `Share.*`, no `accelerometerEvents`, no `SvgPicture(color:)`). So these packs
serve the **broader saropa_lints user base**, not contacts itself — the contacts
pubspec functioned purely as a high-signal candidate inventory.

---

## 5. Status

- [x] Mechanism shipped (`plan_migration_plugin_system.md`)
- [x] Coverage map + ranked candidates (this doc)
- [x] Recipe extracted (§2)
- [x] Exemplar plan researched + written: [`share_plus`](plan_migration_share_plus.md)
- [x] P1 plans (all researched + written):
  - [Tier A] [`sensors_plus`](plan_migration_sensors_plus.md), [`flutter_svg`](plan_migration_flutter_svg.md), [`share_plus`](plan_migration_share_plus.md)
  - [Tier B] [`google_sign_in`](plan_migration_google_sign_in.md), [`connectivity_plus`](plan_migration_connectivity_plus.md), [`webview_flutter`](plan_migration_webview_flutter.md)
- [ ] Maintainer decision: support `<` (pre-upgrade) gate archetype? (gates Tier B)
- [ ] P2 / P3 plans
- [ ] Implement packs (separate work, per plan)
