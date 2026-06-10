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

**Gate-direction note:** a migration rule is gated on the **new** version range.
Rationale: once a project is *on* the version that removed/deprecated the old
API, any remaining old-API usage is a real migration debt to flag. A project
still on the old version should NOT see the rule (their API is valid there). This
matches `dio_5` (flag `DioError` only when `dio >=5.0.0`).

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

## 4. Priority tranche

**P1 (clear, mechanical, high-blast-radius migrations — build first):**
`google_sign_in_7`, `share_plus_11`, `connectivity_plus_6`, `sensors_plus_4`,
`flutter_svg_2`, `webview_flutter_4`.

**P2:** `audioplayers_6`, `app_links_6`, `file_picker_8`, `mobile_scanner_7`.

**P3 / lower:** `local_auth_2`, `image_picker`, `flutter_bloc_9`, `supabase_2`,
`geolocator_14`, `firebase_modular`.

Selection criterion (why P1 ⟶ P3): a migration pack earns its keep when the old
API is (a) **statically detectable** (a named symbol / constructor / method, not
a behavioral change), and (b) **mechanically fixable** (the new form is a
deterministic rewrite). `google_sign_in` and `share_plus` score highest on both;
behavioral-only changes (e.g. permission semantics) score low and are deprioritized.

---

## 5. Status

- [x] Mechanism shipped (`plan_migration_plugin_system.md`)
- [x] Coverage map + ranked candidates (this doc)
- [x] Recipe extracted (§2)
- [x] Exemplar plan researched + written: [`share_plus`](plan_migration_share_plus.md)
- [ ] P1 plans: `google_sign_in`, `connectivity_plus`, `sensors_plus`, `flutter_svg`, `webview_flutter`
- [ ] P2 / P3 plans
- [ ] Implement packs (separate work, per plan)
