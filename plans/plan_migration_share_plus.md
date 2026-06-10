# Plan: `share_plus_11` migration pack

**Status:** ready to implement (exemplar — validates the
[index recipe](plan_migration_packs_index.md#2-the-reusable-recipe-extracted-from-riverpod_2-and-dio_5)).
**Gate:** `share_plus >= 11.0.0`.
**Driving app usage:** Saropa Contacts ships `share_plus: ^13.1.0`.

## 1. The migration (verified)

`share_plus` 11.0.0 introduced the instance-based `SharePlus` API and
**deprecated** the static `Share.*` methods. Old API still compiles (deprecated),
so projects accumulate silent migration debt — exactly what a gated lint pack is for.

| Old (deprecated in 11.0.0) | New |
|---|---|
| `Share.share(text, subject: s, sharePositionOrigin: r)` | `SharePlus.instance.share(ShareParams(text: text, subject: s, sharePositionOrigin: r))` |
| `Share.shareUri(uri)` | `SharePlus.instance.share(ShareParams(uri: uri))` |
| `Share.shareXFiles(files, text: t, subject: s)` | `SharePlus.instance.share(ShareParams(files: files, text: t, subject: s))` |

Notes:
- `ShareResult` is still the return type, so call sites awaiting a result need no
  result-handling change — only the call shape changes.
- `sharePositionOrigin` (iPad popover anchor) is carried straight through into
  `ShareParams`. The rule's fix MUST preserve it (dropping it regresses iPad).

## 2. Rules to add (`lib/src/rules/packages/share_plus_rules.dart`, new file)

| Rule code | Detects | Fix |
|---|---|---|
| `prefer_shareplus_instance_share` | `Share.share(...)` static call | Rewrite to `SharePlus.instance.share(ShareParams(text: <arg0>, ...named...))` |
| `prefer_shareplus_instance_share_uri` | `Share.shareUri(...)` | → `ShareParams(uri: ...)` |
| `prefer_shareplus_instance_share_files` | `Share.shareXFiles(...)` / legacy `Share.shareFiles(...)` | → `ShareParams(files: ...)` |

Single combined rule vs three: prefer **one** rule code
`prefer_shareplus_instance` with three sub-detections (one per static method), so
the pack has a single relocatable code — mirrors `dio_5`'s single
`avoid_dio_error`. The fix branches on which static method matched.

**Detection (type-safe, not string match):** match `MethodInvocation` where the
target's static type/element is the `Share` class from `package:share_plus`
(check the element's library URI, per CLAUDE.md anti-pattern guidance — do NOT
`name == 'Share'`). Guard against unrelated user classes named `Share`.

**Fix mechanics:** positional first arg of `Share.share`/`shareXFiles` maps to the
`text`/`files` named param of `ShareParams`; all existing named args
(`subject:`, `sharePositionOrigin:`) copy across unchanged. Where the call spans
the positional + named args, wrap them in `ShareParams(...)` and prefix
`SharePlus.instance.share(`. Skip the fix (report only) if the invocation uses an
argument form the rewriter cannot mechanically map (e.g. spread/await inside the
arg list that would change evaluation order).

## 3. Wiring (recipe steps 2–6)

- `kRulePackDependencyGates` (`lib/src/config/rule_packs.dart`):
  `'share_plus_11': RulePackDependencyGate(dependency: 'share_plus', constraint: '>=11.0.0')`
- `tool/generate_rule_pack_registry.dart`: add `'share_plus_11': {'share_plus'}`
  to the gate-dep map and `'share_plus_11': 'share_plus 11.x'` to the title map.
- `tool/rule_pack_audit.dart` `kRelocatedRulePackCodes`:
  `'prefer_shareplus_instance': (fromPack: 'share_plus', toPack: 'share_plus_11')`.
  (The `share_plus` base pack is created implicitly by the generator from the new
  `share_plus_rules.dart` file; the relocation moves the gated code into
  `share_plus_11`.)
- Regenerate (twice) + `dart format`.

## 4. Tests

- `test/config/rule_packs_share_plus_test.dart`: gate passes at 11.0.0 / 13.1.0,
  fails at 10.x and when share_plus absent; ownership = `prefer_shareplus_instance`
  is the sole member of `share_plus_11` and is NOT in the ungated `share_plus`
  pack; merge respects `diagnostics: false`.
- `test/rules/packages/share_plus_rules_test.dart`: each static form triggers;
  `SharePlus.instance.share(ShareParams(...))` does NOT trigger; the fix output
  for `Share.share('x', sharePositionOrigin: r)` preserves `sharePositionOrigin`.

## 5. Verify

`dart run tool/rule_pack_audit.dart` exit 0 (share_plus_11=1 member); new
`test/config` + `test/rules/packages` tests pass; `dart analyze --fatal-infos`
clean. Confirm behavior against real code with the scan CLI:
`dart run saropa_lints scan <dir> --tier comprehensive --format json`.

## Sources

- [share_plus on pub.dev](https://pub.dev/packages/share_plus)
- [share_plus changelog](https://pub.dev/packages/share_plus/changelog)
- [SharePlus API source](https://github.com/fluttercommunity/plus_plugins/blob/main/packages/share_plus/share_plus/lib/share_plus.dart)
