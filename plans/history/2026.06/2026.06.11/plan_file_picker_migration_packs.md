# Plan: file_picker version-gated deprecation rules (migration packs)

**Status:** active. Split out of `plan_file_picker.md` (the 6 always-on correctness
rules shipped 2026-06-11; see `plans/history/2026.06/2026.06.11/plan_file_picker.md`).
These 4 rules are version-gated migration rules and require the semver rule-pack
system (the same mechanism as `dio_5` / the 6 migration plans). They were NOT
shipped with the correctness rules because firing them on a project still on an
older `file_picker` major would be a false positive (the parameter is not
deprecated there).

**Package:** file_picker (deprecations across v10 → v12).

---

## The 4 rules

| rule_name | deprecated in | replacement | fix | pack |
|---|---|---|---|---|
| `file_picker_deprecated_with_data` | v12 | `PlatformFile.readAsBytes()` | report-only | `file_picker_12` |
| `file_picker_deprecated_with_read_stream` | v12 | `PlatformFile.readAsByteStream()` | report-only | `file_picker_12` |
| `file_picker_deprecated_allow_multiple` | v12 | `pickFile()` / unflagged `pickFiles()` | report-only | `file_picker_12` |
| `file_picker_deprecated_allow_compression` | v10 | `compressionQuality:` | mechanical (`true`→`75`, `false`→`0`) | `file_picker_10` |

All four: match a `MethodInvocation` on `FilePicker` (library URI
`package:file_picker/file_picker.dart`) carrying the named argument; INFO; relocated
out of the ungated `file_picker` pack into the gated pack so a project on the old
major never sees them.

## Pack wiring (recipe — mirror `dio_5`)

`kRulePackDependencyGates` (`lib/src/config/rule_packs.dart`):
```dart
'file_picker_10': RulePackDependencyGate(dependency: 'file_picker', constraint: '>=10.0.0'),
'file_picker_12': RulePackDependencyGate(dependency: 'file_picker', constraint: '>=12.0.0-0'),
```

`kRelocatedRulePackCodes` (`tool/rule_pack_audit.dart`):
```dart
'file_picker_deprecated_allow_compression': (fromPack: 'file_picker', toPack: 'file_picker_10'),
'file_picker_deprecated_with_data': (fromPack: 'file_picker', toPack: 'file_picker_12'),
'file_picker_deprecated_with_read_stream': (fromPack: 'file_picker', toPack: 'file_picker_12'),
'file_picker_deprecated_allow_multiple': (fromPack: 'file_picker', toPack: 'file_picker_12'),
```

Add the gated pack ids + titles in `tool/generate_rule_pack_registry.dart`, then
regenerate (`dart run tool/generate_rule_pack_registry.dart`, run twice) + `dart format`.
Verify with `dart run tool/rule_pack_audit.dart` (exit 0) and `dart analyze --fatal-infos`.

## Detection detail (verbatim from the original plan)

- `file_picker_deprecated_with_data` — `withData:` named arg present. Report-only
  (removing it changes semantics; call sites must `await readAsBytes()`).
- `file_picker_deprecated_with_read_stream` — `withReadStream:` named arg present.
- `file_picker_deprecated_allow_multiple` — `allowMultiple:` named arg present.
  Report-only (the `false` case needs a `pickFile()` return-type change).
- `file_picker_deprecated_allow_compression` — `allowCompression:` named arg.
  Mechanical fix when the value is a boolean literal: `allowCompression: true` →
  `compressionQuality: 75`, `allowCompression: false` → `compressionQuality: 0`;
  report-only otherwise.

## Sources

See `plans/history/2026.06/2026.06.11/plan_file_picker.md` § Sources.

---

## Finish Report (2026-06-11)

Scope (LINTER variant): (A) Dart lint rules / analyzer plugin + (C) docs.

**Shipped.** file_picker_10 (allowCompression, quick fix to compressionQuality) + file_picker_12 (withData / withReadStream / allowMultiple) deprecation packs. All 4 codes relocated out of the base file_picker pack.

Rules marked DROP / defer in the 2026-06-11 VALIDATION notes were intentionally not implemented (duplicates, overlap with existing rules, or feasibility concerns). Every rule is import-gated via `fileImportsPackage`; migration rules are version-gated via `kRulePackDependencyGates` and relocated out of their base pack via `kRelocatedRulePackCodes` so a project on the old major never sees a rule for an API it lacks.

**Verification.** `dart analyze lib --fatal-infos` clean; `dart run tool/rule_pack_audit.dart` exit 0; full test suite green (1336 tests across test/integrity, test/config, test/rules/packages); registry regenerated twice + `dart format`. Rules authored by parallel subagents then serially registered into the shared files (tiers.dart, saropa_lints.dart, import_utils.dart, all_rules.dart, rule_packs.dart, generator + audit).

**Plan disposition.** Complete — archived to `plans/history/2026.06/2026.06.11/`.
