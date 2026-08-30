# Issue #320 — require_text_overflow_handling correction message steers toward ellipsis

The `require_text_overflow_handling` and `require_text_overflow_in_row` rules had correction messages that recommended `TextOverflow.ellipsis` as the primary fix. AI agents followed this literally, hiding dynamic text behind ellipsis instead of keeping it readable.

## Finish Report (2026-08-30)

**Classification:** Confirmed bug — correction guidance, not detection logic.

**Root cause:** Both rules' `correctionMessage` fields led with "Add overflow: TextOverflow.ellipsis" as the first suggestion. AI code assistants parsed this as the canonical fix, applying ellipsis universally — even for content users need to read in full (e.g. descriptions, body text, error messages).

**Fix (two parts):**

1. **Correction messages rewritten** — both rules now recommend `Expanded`/`Flexible` wrapping first (keeps text visible and naturally flowing). Ellipsis is positioned as a last resort for intentional truncation (list tiles, chip labels). Removed misleading `softWrap: true` suggestion (it is already the `Text` default). DartDoc GOOD examples and the fixture updated to demonstrate wrapping as the primary approach.

2. **Context-aware quick fixes added** — two fixes registered on both rules:
   - `WrapTextInExpandedFix` — wraps `Text(...)` in `Expanded(child: ...)`. Only offered when inside a `Row`/`Column`/`Flex` ancestor (guarded by `_hasFlexAncestor` walk). Using `Expanded` outside a Flex crashes at runtime with "Incorrect use of ParentDataWidget."
   - `AddMaxLinesToTextFix` — inserts `, maxLines: 2` when NOT inside a Flex. Caps vertical growth while keeping text readable (unlike ellipsis on line 1). Only one fix activates per diagnostic location.

**Hardening applied:**
- Removed `softWrap: true` from correction message — it is the default on `Text`, so suggesting it explicitly was misleading.
- Fixture `Expanded` example now wrapped in `Row(children: [...])` for structural correctness.
- Merged duplicate `### Fixed` sections in CHANGELOG into one.
- Quick fix guards against Flex-ancestor absence — prevents runtime crash from `Expanded` outside `Row`/`Column`.

**Files changed:**
- `lib/src/rules/widget/widget_patterns_require_rules.dart` — correctionMessage rewritten, two fixGenerators registered
- `lib/src/rules/widget/forms_rules.dart` — correctionMessage rewritten, DartDoc GOOD example updated, two fixGenerators registered
- `lib/src/fixes/widget/wrap_text_in_expanded_fix.dart` — NEW: WrapTextInExpandedFix + AddMaxLinesToTextFix
- `example/lib/widget_patterns/require_text_overflow_handling_fixture.dart` — GOOD examples show wrapping first
- `CHANGELOG.md` — entry under `### Fixed` referencing #320

**Reporter's proposal rejected:** Renaming to `require_all_text_visible` would imply no truncation is ever acceptable, which causes the very RenderFlex overflow errors the rule prevents. The rule name and detection logic remain unchanged.

**Tests:** Existing tests assert `correctionMessage` is non-null and `problemMessage` contains the rule name prefix — both still pass. No assertions depend on message text. Test suite has a pre-existing compilation error in `code_quality_prefer_rules.dart:1254` unrelated to this change.
