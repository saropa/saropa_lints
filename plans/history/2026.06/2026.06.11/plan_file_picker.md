# Plan: new `file_picker` lint rules

**Package:** file_picker ^12.0.0-beta.5 (Saropa Contacts). **saropa_lints coverage:** none (new file).

**Beta / API-churn note:** v12.0.0-beta.5 is a pre-release. The v8→v12 window contains
real API churn: static-method refactor (v11), `withData`/`withReadStream`/`allowMultiple`
deprecated in favor of `readAsBytes()`/`readAsByteStream()`/`pickFile()` (v12 beta),
`allowCompression` deprecated in favor of `compressionQuality` (v10),
`FilePicker.platform` removed (v11). Rules that reference these deprecated APIs are
migration rules and should be version-gated (see §Migration rules below).
Correctness rules (null safety, FileType.custom contract) are always-on.

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `file_picker_unchecked_null_result` | correctness | `pickFiles()` / `pickFile()` return value used without null check | report-only | WARNING | only flag direct field/method access on the raw result without a prior null check |
| `file_picker_path_on_web` | correctness | `.path` accessed on a `PlatformFile` inside a `kIsWeb`-reachable branch without a null guard | report-only | WARNING | guard: only flag `!` force-unwrap or direct non-null use; skip when inside `if (!kIsWeb)` / `defaultTargetPlatform != TargetPlatform.web` guard |
| `file_picker_custom_type_missing_extensions` | correctness | `pickFiles`/`pickFile`/`saveFile` called with `type: FileType.custom` and no `allowedExtensions` argument (or `allowedExtensions: []`) | mechanical fix | ERROR | confirm the named arg `type` resolves to `FileType.custom` via element check |
| `file_picker_extensions_without_custom_type` | correctness | `allowedExtensions` passed with a `type` other than `FileType.custom` | report-only | WARNING | confirm `allowedExtensions` argument is non-null/non-empty and `type` is present and not `FileType.custom` |
| `file_picker_extension_with_dot` | correctness | any string literal in `allowedExtensions: [...]` that starts with `.` (e.g. `'.pdf'`) | mechanical fix (strip dot) | WARNING | only literals inside the `allowedExtensions` named-arg list of a `file_picker` call |
| `file_picker_with_data_large_files` | best-practice | `withData: true` combined with `allowMultiple: true` (or `withData` absent on web where it was defaulting true) | report-only | WARNING | only flag when `withData: true` is explicit and `allowMultiple: true` is also explicit; skip single-file calls |
| `file_picker_deprecated_with_data` | migration | `withData:` named argument passed to `pickFiles` (deprecated in v12: use `PlatformFile.readAsBytes()`) | report-only | INFO | gate `file_picker >= 12.0.0`; confirm call target resolves to `FilePicker` from `package:file_picker` |
| `file_picker_deprecated_with_read_stream` | migration | `withReadStream:` named argument passed to `pickFiles` (deprecated in v12: use `PlatformFile.readAsByteStream()`) | report-only | INFO | gate `file_picker >= 12.0.0`; same library-URI check |
| `file_picker_deprecated_allow_multiple` | migration | `allowMultiple:` named argument passed to `pickFiles` (deprecated in v12: use `pickFile()` for single, `pickFiles()` without the flag for multiple) | report-only | INFO | gate `file_picker >= 12.0.0`; same library-URI check |
| `file_picker_deprecated_allow_compression` | migration | `allowCompression:` named argument passed to `pickFiles` (deprecated since v10: use `compressionQuality:`) | mechanical fix | INFO | gate `file_picker >= 10.0.0`; fix rewrites `allowCompression: true` → `compressionQuality: 75`, `allowCompression: false` → `compressionQuality: 0` |

---

## Rule detail

### `file_picker_unchecked_null_result`

- **What/why:** `pickFiles()` returns `FilePickerResult?` — null when the user cancels on
  Android/iOS/desktop (on web cancellation is undetectable). Accessing `.files`, `.paths`,
  `.xFiles`, etc. on an unchecked result is a runtime null-dereference. This is the
  single most commonly reported misuse in GitHub issues (#695, #794, #1415).
- **Detection (AST, type-safe):** match `MethodInvocation` whose static type (return type)
  is `FilePickerResult?` from library URI `package:file_picker/file_picker.dart`. Flag any
  immediately chained member access (`result.files`, `result.paths`, `result.xFiles`) on
  the direct call result, OR assignment to a non-nullable local followed by use, where no
  null check (`== null`, `!= null`, `?.`, `??`, `if (result == null)`) intervenes in the
  same lexical scope. The simpler, high-precision trigger: flag `expr.files` /
  `expr.paths` / `expr.xFiles` where `expr`'s static type is `FilePickerResult?`
  (nullable). Type lookup — `FilePickerResult` element library URI must be
  `package:file_picker/file_picker.dart`; do NOT match on class name alone.
- **Fix:** report-only. The correct null-handling pattern depends on app intent
  (return, show error, no-op) and cannot be determined mechanically from the AST.
- **False positives:** calls inside a prior `if (result == null) return;` guard are already
  safe — flow analysis marks the type as non-nullable after the guard, so the flagged
  expression's static type will be `FilePickerResult` (non-nullable) and the rule will not
  fire. No special guard logic needed; rely on type narrowing.

---

### `file_picker_path_on_web`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** kIsWeb source-text scan is fragile (helper-wrapped checks, ternaries); mark experimental.

- **What/why:** `PlatformFile.path` is `String?` and is always null on the web platform —
  browsers do not expose real file-system paths. Force-unwrapping with `!` or passing to a
  non-nullable `File(path!)` constructor causes a runtime throw on web. Documented in the
  FAQ and in multiple GitHub issues (#548, #591, #676, #823). The correct web pattern is to
  use `bytes` or `readAsBytes()` for data and `name` for the filename.
- **Detection (AST, type-safe):** match `PostfixExpression` with operator `!` where the
  operand is a `PropertyAccess` / `PrefixedIdentifier` with property name `path` and the
  receiver's static type is `PlatformFile` from `package:file_picker/file_picker.dart`.
  Additionally flag `.path` access (without `!`) that feeds into a `File(...)` constructor
  or `String` non-nullable context (look at the parent `ArgumentList` or assignment target
  static type). Keep scope narrow: only fire when the static type is confirmed to be
  `PlatformFile` via element resolution.
- **Fix:** report-only. The correct alternative (`bytes`, `readAsBytes()`) depends on
  whether the caller needs synchronous bytes or a stream, and is platform-conditional;
  a mechanical single-symbol replacement would be wrong.
- **False positives:** `PlatformFile.path` inside an `if (!kIsWeb)` or
  `if (defaultTargetPlatform != TargetPlatform.web)` guard is legitimate desktop/mobile
  usage. Guard: check whether the nearest enclosing `IfStatement` or conditional expression
  narrows to a non-web platform; if yes, suppress. In practice, checking for `kIsWeb` in
  the enclosing `IfStatement.condition` source text is a reasonable heuristic when type
  flow analysis cannot see `kIsWeb` at compile time. Mark speculative — verify the approach
  produces acceptable FP rate against real code before shipping. (speculative — verify)

---

### `file_picker_custom_type_missing_extensions`

- **What/why:** `FileType.custom` without a non-empty `allowedExtensions` list throws at
  runtime on all platforms ("You are setting a type [FileType.custom]. Custom extension
  filters are only allowed with FileType.custom, please change it or remove filters" — the
  message is confusing but the assert/throw fires when `allowedExtensions` is null or empty
  while type is custom). Documented in FAQ and multiple issues (#725, #312, #1658).
- **Detection (AST, type-safe):** match `MethodInvocation` where:
  (a) the invocation target's static type is `FilePicker` from
  `package:file_picker/file_picker.dart` (static class — check enclosing class element
  library URI), AND
  (b) there is a named argument `type:` whose expression resolves to the enum field
  `FileType.custom` from `package:file_picker/file_picker.dart`, AND
  (c) `allowedExtensions:` named argument is absent, OR present with a `ListLiteral` that
  is empty.
  Resolve `FileType.custom` via `SimpleIdentifier.staticElement` → `EnumConstantElement`
  whose enclosing `EnumElement.name == 'FileType'` and library URI matches. Never match on
  the string `'custom'`.
- **Fix:** mechanical — insert `allowedExtensions: ['']` as a placeholder and emit a
  TODO comment noting the developer must populate the list. Actually, per CLAUDE.md
  "Quick Fixes" rule, inserting a TODO is prohibited. Report-only is safer here; the
  required extension list is app-domain knowledge the lint cannot infer.
  **Revised: report-only.**
- **False positives:** low — the rule only fires when the exact enum value `FileType.custom`
  is detected via element resolution and `allowedExtensions` is absent or empty.

---

### `file_picker_extensions_without_custom_type`

- **What/why:** `allowedExtensions` is silently ignored (or throws, depending on platform)
  when `type` is anything other than `FileType.custom`. Developers often pass extensions
  hoping they'll filter even with `FileType.any` or `FileType.image`, but the API contract
  rejects this — the package throws: "Custom extension filters are only allowed with
  FileType.custom". Many reported bugs stem from this misunderstanding.
- **Detection (AST, type-safe):** match `MethodInvocation` on `FilePicker` (library URI
  guard as above) where `allowedExtensions:` is present with a non-null/non-empty value,
  AND `type:` is present and resolves to any `FileType` enum constant *other than*
  `FileType.custom`. If `type:` is absent (defaulting to `FileType.any`), also flag — the
  presence of `allowedExtensions` with no `type: FileType.custom` is always wrong.
- **Fix:** report-only. The correct resolution is either remove `allowedExtensions` or
  change `type` to `FileType.custom`; the lint cannot know which is intended.
- **False positives:** confirm `allowedExtensions` value is not `null` before firing; skip
  if the list literal is empty (covered by `file_picker_custom_type_missing_extensions`).

---

### `file_picker_extension_with_dot`

- **What/why:** `allowedExtensions` entries must not include the leading dot — `'pdf'` is
  correct, `'.pdf'` causes the extension to be ignored or silently fail on Android. The
  FAQ explicitly states "use the extension without the dot". Multiple issues report this
  exact mistake (#1689 and others).
- **Detection (AST, type-safe):** match `StringLiteral` elements inside a `ListLiteral`
  that is the value of the `allowedExtensions:` named argument in an invocation of
  `FilePicker.pickFiles`, `FilePicker.pickFile`, `FilePicker.saveFile`, or
  `FilePicker.pickFileAndDirectoryPaths`. Confirm the parent invocation's target library
  URI is `package:file_picker/file_picker.dart`. Flag any `StringLiteral` whose string
  value starts with `'.'`. This is a pure string-literal value inspection (the
  *content* of the literal, not the identifier), so it is not "bare-name matching of a
  type" and is acceptable.
- **Fix:** mechanical — strip the leading `.` from the string literal. `'.pdf'` → `'pdf'`.
- **False positives:** very low. Any extension string starting with `.` inside this exact
  named argument is unambiguously wrong per the documented API contract.

---

### `file_picker_with_data_large_files`

- **What/why:** `withData: true` loads the entire file content into `Uint8List` in memory
  before returning. When combined with `allowMultiple: true`, this means N×file-size RAM
  consumption. The package documentation warns explicitly: "on iOS & Android it may result
  in out of memory issues if you allow multiple picks or pick huge files — use
  `withReadStream` instead." With v12, `withData` and `withReadStream` are both deprecated
  in favor of lazy `readAsBytes()`/`readAsByteStream()` on `PlatformFile`, but the
  memory hazard remains for code that has not yet migrated.
  **Note:** `withData` is also the hidden default on web (documented as defaulting to
  `true` on web, though v11 introduced a regression where this default is not honored
  without an explicit `withData: kIsWeb` — flagging this overlap is out of scope; see
  `file_picker_deprecated_with_data`).
- **Detection (AST, type-safe):** match `MethodInvocation` on `FilePicker` (library URI
  guard) where `withData: true` is explicitly present AND `allowMultiple: true` is
  explicitly present in the same argument list. Both named args must be boolean literal
  `true`; symbolic constants or expressions are not detectable statically — do not flag
  them to avoid FPs.
- **Fix:** report-only. The correct alternative (`readAsByteStream()` per-file) requires
  restructuring call-site logic; a mechanical single-arg replacement would be incomplete
  and potentially wrong.
- **False positives:** constrained to only explicit `true` literals on both params;
  single-file calls (`allowMultiple` absent or `false`) are not flagged.

---

### `file_picker_deprecated_with_data`

- **What/why:** in v12.0.0-beta, `withData` is annotated `@Deprecated('Use
  PlatformFile.readAsBytes(); this parameter will be removed in a future release')`. The
  new pattern is to call `file.readAsBytes()` on each `PlatformFile` lazily, rather than
  loading all bytes eagerly at pick time. Version-gated so this rule only fires when the
  resolved `file_picker` version satisfies `>=12.0.0`.
- **Detection (AST, type-safe):** match `MethodInvocation` on `FilePicker` from
  `package:file_picker/file_picker.dart` where a `withData:` named argument is present.
  Detection (named-arg presence + library URI) runs unconditionally inside `run()`; the
  version gate is applied at pack-merge time via `kRulePackDependencyGates`
  (rule_packs.dart:62) — there is no in-rule version-check API.
- **Fix:** report-only. Removing `withData` changes semantics (bytes no longer eagerly
  available); call sites need to await `readAsBytes()` explicitly at the consumption point.
- **False positives:** low — `withData` is a named parameter unique to `file_picker`'s
  `FilePicker` class; with library-URI confirmation the signal is unambiguous.

---

### `file_picker_deprecated_with_read_stream`

- **What/why:** `withReadStream` is annotated `@Deprecated('Use
  PlatformFile.readAsByteStream(); this parameter will be removed in a future release')` in
  v12.0.0-beta. Companion to `file_picker_deprecated_with_data`.
- **Detection (AST, type-safe):** same pattern as `file_picker_deprecated_with_data` but
  matching the `withReadStream:` named argument. Same `>=12.0.0` version gate.
- **Fix:** report-only. Same rationale as above.
- **False positives:** same guards as above.

---

### `file_picker_deprecated_allow_multiple`

- **What/why:** `allowMultiple` is annotated `@Deprecated('use pickFile for
  single-file selection; this parameter will be removed in a future release')` in v12.0.0-
  beta. The API has split: `pickFile()` for single-file selection, `pickFiles()` (without
  the flag) for multi-file selection. Using `allowMultiple: false` on `pickFiles()` is the
  pattern that needs replacing with `pickFile()`. Version-gated at `>=12.0.0`.
- **Detection (AST, type-safe):** match `MethodInvocation` on `FilePicker` where
  `allowMultiple:` named argument is present. Version gate as above.
- **Fix:** report-only. When `allowMultiple: false`, the fix would be to switch to
  `FilePicker.pickFile()` which has a different return type (`PlatformFile?` vs
  `FilePickerResult?`), requiring call-site restructuring. When `allowMultiple: true`,
  simply removing the argument suffices — but detecting which case applies requires
  evaluating the boolean value, which may not always be a literal. Report-only is safer.
- **False positives:** constrained by library-URI check on `FilePicker`.

---

### `file_picker_deprecated_allow_compression`

- **What/why:** `allowCompression` was deprecated in v10.0.0 in favor of
  `compressionQuality` (an `int` from 0–100, where 0 = no compression). Code still
  using `allowCompression: true` gets no compression on v10+ because the parameter is
  a no-op. Version-gated at `>=10.0.0`.
- **Detection (AST, type-safe):** match `MethodInvocation` on `FilePicker` where an
  `allowCompression:` named argument is present. Version gate: `>=10.0.0`.
- **Fix:** mechanical when the argument value is a boolean literal:
  `allowCompression: true` → `compressionQuality: 75` (a reasonable non-zero default;
  the exact quality value is app-specific — note this in the correction message),
  `allowCompression: false` → `compressionQuality: 0`.
  Skip the fix (report-only) when the value is not a boolean literal (e.g. a variable).
- **False positives:** `allowCompression` is a named parameter specific to file_picker;
  library-URI guard makes this unambiguous.

---

## Implementation note

**New file:** `lib/src/rules/packages/file_picker_rules.dart`

**Register in `lib/saropa_lints.dart` `_allRuleFactories`:**
```dart
FilePickerUncheckedNullResultRule.new,
FilePickerPathOnWebRule.new,
FilePickerCustomTypeMissingExtensionsRule.new,
FilePickerExtensionsWithoutCustomTypeRule.new,
FilePickerExtensionWithDotRule.new,
FilePickerWithDataLargeFilesRule.new,
FilePickerDeprecatedWithDataRule.new,
FilePickerDeprecatedWithReadStreamRule.new,
FilePickerDeprecatedAllowMultipleRule.new,
FilePickerDeprecatedAllowCompressionRule.new,
```

**Tier assignments (`lib/src/tiers.dart`):**
- `comprehensiveOnlyRules`: `file_picker_unchecked_null_result`,
  `file_picker_path_on_web`, `file_picker_custom_type_missing_extensions`,
  `file_picker_extensions_without_custom_type`, `file_picker_extension_with_dot`,
  `file_picker_with_data_large_files`
- `pedanticOnlyRules`: `file_picker_deprecated_with_data`,
  `file_picker_deprecated_with_read_stream`, `file_picker_deprecated_allow_multiple`,
  `file_picker_deprecated_allow_compression`

**Migration rules → version-gated packs:** the four `file_picker_deprecated_*` rules
follow the recipe in [plan_migration_plugin_system.md §2](plan_migration_plugin_system.md).
Two packs:
- `file_picker_10`: gate `file_picker >= 10.0.0`, contains
  `file_picker_deprecated_allow_compression`.
- `file_picker_12`: gate `file_picker >= 12.0.0-0` (semver pre-release prefix), contains
  `file_picker_deprecated_with_data`, `file_picker_deprecated_with_read_stream`,
  `file_picker_deprecated_allow_multiple`.

**`kRulePackDependencyGates`** entries:
```dart
'file_picker_10': RulePackDependencyGate(dependency: 'file_picker', constraint: '>=10.0.0'),
'file_picker_12': RulePackDependencyGate(dependency: 'file_picker', constraint: '>=12.0.0-0'),
```

**`kRelocatedRulePackCodes`** entries (relocate out of the ungated `file_picker` pack):
```dart
'file_picker_deprecated_allow_compression': (fromPack: 'file_picker', toPack: 'file_picker_10'),
'file_picker_deprecated_with_data': (fromPack: 'file_picker', toPack: 'file_picker_12'),
'file_picker_deprecated_with_read_stream': (fromPack: 'file_picker', toPack: 'file_picker_12'),
'file_picker_deprecated_allow_multiple': (fromPack: 'file_picker', toPack: 'file_picker_12'),
```

**Coverage map entry** — update `plan_migration_plugin_system.md` row for `file_picker`:
change status from `Cand P2 — research pending` to `RF + MP (file_picker_10, file_picker_12) — researched, plan ready`.

**`example*/` exclusion:** add `example_file_picker/` to `analysis_options.yaml`
`analyzer: exclude:` list when creating the fixture directory.

**Not lint-able (runtime-only concerns):**
- Whether the Android OS honors MIME-type filters (platform runtime, not statically
  detectable).
- Whether `result.paths` is populated on older Android SDK (SDK 30+ returns null paths
  for content URIs — same category as web-path issue but cannot be statically keyed to
  the Android target).
- Web-specific `cancelUploadOnWindowBlur` behavior (parameter exists, no known misuse
  pattern that is statically detectable).
- macOS entitlement absence causing null returns (build-time config, not Dart AST).

---

## Sources

- [file_picker on pub.dev](https://pub.dev/packages/file_picker)
- [file_picker changelog](https://pub.dev/packages/file_picker/changelog)
- [GitHub: miguelpruivo/flutter_file_picker](https://github.com/miguelpruivo/flutter_file_picker)
- [file_picker API wiki](https://github.com/miguelpruivo/flutter_file_picker/wiki/API)
- [file_picker FAQ wiki](https://github.com/miguelpruivo/flutter_file_picker/wiki/FAQ)
- [file_picker source: file_picker.dart](https://github.com/miguelpruivo/flutter_file_picker/blob/master/lib/src/file_picker.dart)
- [Issue #695: pickFiles() returns null Flutter Web](https://github.com/miguelpruivo/flutter_file_picker/issues/695)
- [Issue #725: Bug with FileType.custom doesn't allow to set allowedExtensions](https://github.com/miguelpruivo/flutter_file_picker/issues/725)
- [Issue #1689: Allowed Extensions throws error (Android)](https://github.com/miguelpruivo/flutter_file_picker/issues/1689)
- [Issue #1987: withData no longer defaults to true on web](https://github.com/miguelpruivo/flutter_file_picker/issues/1987)
- [Issue #548/#591/#676: File path is null on Web](https://github.com/miguelpruivo/flutter_file_picker/issues/548)
- [Issue #1658: allowedExtensions support for custom formats](https://github.com/miguelpruivo/flutter_file_picker/issues/1658)

---

## Finish Report (2026-06-11)

**Scope:** (A) Dart lint rules. The 6 always-on correctness/best-practice rules
shipped; the 4 version-gated `deprecated_*` migration rules are SPLIT into the new
active plan `plans/plan_file_picker_migration_packs.md` (they need the semver
rule-pack system, shared with the migration-plan workstream).

### Validation fixes applied

- `file_picker_path_on_web` — marked **experimental** in its doc + message; the
  `kIsWeb` guard is a best-effort enclosing-`if` AST scan (walks `IfStatement`
  conditions for a `kIsWeb` identifier — not a source-text `.contains`).
- The `deprecated_*` version-gate concern — addressed by SPLITTING those 4 rules to
  the pack-system plan rather than shipping them ungated (which would false-positive
  on older file_picker majors).

### Delivered (6 rules, Comprehensive tier)

`file_picker_unchecked_null_result`, `file_picker_path_on_web` (experimental),
`file_picker_custom_type_missing_extensions` (ERROR),
`file_picker_extensions_without_custom_type`,
`file_picker_extension_with_dot` (+ dot-stripping quick fix),
`file_picker_with_data_large_files`. All gated by
`fileImportsPackage(PackageImports.filePicker)`. `RuleType.bug`/`codeSmell`.

### Verification

- `dart analyze --fatal-infos` → No issues found. Unit (12) + registration integrity pass.
- **Scan-verified (4/6 fire):** `custom_type_missing_extensions`,
  `extensions_without_custom_type`, `extension_with_dot`, `with_data_large_files`
  fire on BAD and stay clean on GOOD (syntactic detection). `unchecked_null_result`
  and `path_on_web` key on resolved types (`FilePickerResult?` / `PlatformFile`) and
  fire only in resolved code — verified by review, not positively triggered in an
  unresolved mock.

### Remaining work (split to active plan)

`plans/plan_file_picker_migration_packs.md` — the 4 `deprecated_*` rules + their
`file_picker_10` / `file_picker_12` pack wiring.
