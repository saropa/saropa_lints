# False-positive batch, 2026-10-29

State of the 12-report batch. Working tree is uncommitted.

## Rules

- Not-reproducible reports and reports needing more explanation go to `bugs/unreproducable/`. They are handed back to the reporter.
- Any report left in `bugs/` is handed back to the reporter. Each needs a clear status note saying what was scanned and what the reporter must confirm.
- Archive a report only after a real, verified rule fix. "Not reproducible" stays in `bugs/` with a status note.

## Results

| # | Rule | Outcome | Report location |
|---|------|---------|-----------------|
| 1 | avoid_ignoring_return_values | Not reproducible on beta.4. Fixture cases added. | bugs/ |
| 2 | avoid_memory_intensive_operations | Real. Fixed (`isStringBufferDrain`). | archived |
| 3 | avoid_nullable_interpolation | Not reproducible. Fixture cases added. | bugs/ |
| 4 | avoid_only_rethrow | Not reproducible. Fixture cases added. | bugs/ |
| 5 | avoid_parameter_mutation | Not reproducible. Fixture cases added. | bugs/ |
| 6 | avoid_string_concatenation_loop | Covered by fix 2. Unit test and fixture added. | archived |
| 7 | avoid_string_substring | Not reproducible. Fixture case added. | bugs/ |
| 8 | avoid_unsafe_collection_methods | Not reproducible. Fixture cases added. | bugs/ |
| 9 | require_catch_logging | Real. Fixed (single `return Constructor(...)` catch body exempt). | archived |
| 10 | require_data_encryption | Not reproducible. Fixture cases added. | bugs/ |
| 11 | require_file_close_in_finally | Not reproducible. Fixture cases added. Stale `_bad965` removed. | bugs/ |
| 12 | avoid_platform_channel_on_web | Real. Fixed (private never-true-on-web flag). | archived |

## Mistake and gap

- Mistake: 8 not-reproducible reports were archived.
- Gap: my briefs said to archive on a not-reproducible result, and the saved rule `feedback_archive_bugs_only_when_resolved` was not consulted.
- Fixed: the 8 reports are back in `bugs/` with status "Open. Not reproducible". The saved rule now names the case.

## Second batch (3 reports)

- prefer_freezed_for_data_classes: real, fixed (gated on freezed dependency), archived. No automated test for the gate.
- avoid_return_await_db: real, fixed (camelCase word split, `compute`/`calculate`/`check` read verbs), archived. All 5 report cases verified.
- proposal_infra_single_on_off_switch: already shipped in beta.3. Opus design review found two defects (display ignores saved record; init exits 1 on default projects). Decision recorded: init exits 1 when the extension turned lints off (matches the proposal's "fail loudly"). Fix dispatched. Pack-detection mismatch goes to `bugs/unreproducable/`.
- Stray `saropa_lints: ^16.2.1` in pubspec.yaml dev_dependencies removed on owner's yes.

- Switch fix done: `initLintsSwitch` (display uses saved record), `init` exit codes by ownership record. Dart tests pass. Proposal stays in `bugs/` (original toggle failure in the contacts project not reproduced).
- Owner action: `npm test` in `extension/` has 48 locale-parity failures (keys missing in translations, e.g. `command.migrateRuleNames.title`, `command.configureCompatibility.title`). Translation is the owner's pipeline; agents do not touch it. Not caused by this batch (not verified on a clean tree).

## Reporter responses (2026-10-29)

- Cause on the reporter side: a stale compiled `lsp_server` snapshot (pre-beta.4) in `.dart_tool/pub/bin/saropa_lints/`. Fixed there.
- 8 beta4_evidence reports: all reported locations no longer fire in a fresh 762-finding export. No rule code changed for them ("Fixed" was the wrong label). Owner decision: reports deleted. Only the regression fixture cases remain in the repo.
- `require_ios_face_id_usage_description`: rule silent now, but Hypothesis A (plist lookup) not confirmed or refuted. Stays in `bugs/unreproducable/`.
- `pack_detection_mismatch_init_vs_dashboard_unverified`: no reporter response yet. Stays.
- The export holds other findings in `lib/utils/` for the same rules (12, 68, 54, 9, 13, 4). Not triaged. Not part of this batch.

## Open decision (owner)

**require_catch_logging exemption is broad.** Any catch whose only statement is `return SomeClass(...)` is exempt. That hides `catch (e) { return Failure(); }`, which drops the exception unlogged.

- Option A (Recommended): narrow to constructor calls whose arguments are const or enum-like constants, for example `Res(St.failed)`. Real status mappings stay clean. `Failure()` with no signal still lints.
- Option B: keep broad. Simplest. Misses silently dropped exceptions.
- Status: unanswered. File: `lib/src/rules/security/security_network_input_rules.dart` (~4649).

## Review findings (Haiku fresh-eyes, 2026-10-29)

| # | Finding | Status |
|---|---------|--------|
| 1 | `example/lib/web/avoid_platform_channel_on_web_fixture.dart` (~260) uses `defaultTargetPlatform` / `TargetPlatform.android`, missing from `flutter_mocks.dart`. | Not a problem: `dart analyze` clean, file header ignores undefined identifiers |
| 2 | `web_rules.dart` `_isWebSafeWrite` (~329) ignores polarity: `kIsWeb \|\| x` then `if (!flag) return;` wrongly suppresses. | Fixed, fixture `_WrongPolarityFlag939` |
| 3 | `_AssignmentFinder` misses `this._flag = true;` writes. | Fixed, fixture `_ThisAssignFlag939` |
| 4 | Broad catch-return exemption. | Open decision above |
| 5 | No true-positive test that `x += other.toString()` (non-StringBuffer) still lints. | Fixed: 4 unit tests added |
| 6 | `expect_lint` markers sit above the function, not the flagged line. No checker validates placement. | Dropped |
| 7 | New: `_mentionsWebGetter` (used by `_isGetterExitGuard`) has the same wrong-polarity flaw (`kIsWeb \|\| x` getter suppresses). Shared with the `kIsWeb ? null : MethodChannel(...)` case. | Fixed (`requireFalseOnWeb` in `_isGetterExitGuard`). Verified by resolved scan: bad case flagged, good getter-guard cases quiet. |

## Open question

- `plans/history/2026.10/2026.10.29/avoid_context_across_async_false_positive_mounted_guarded.md` matched a "not reproducible" phrase. It was archived before this session. Unread. Need to confirm its fix was real.
