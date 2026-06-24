# Fix: publish-audit duplicated-message check false-positives on enumerated code examples

The publish audit's duplicated-message check (`scripts/modules/_duplicated_messages.py`) flagged two `share_plus_rules.dart` correctionMessages as containing "inline repeated" text. The heuristic exists to catch a prose paragraph accidentally pasted twice into one `LintCode` message, but it could not distinguish that defect from a correctionMessage that intentionally repeats an API/call fragment across parallel before/after migration examples.

## Defect

The `dup_inline` detection slides an 80/60/40-char window across each stitched message string and records a finding when any window recurs (`full.count(sub) >= 2`) and contains a space. Two rules tripped it legitimately:

- `prefer_shareplus_instance` (line 83): its correctionMessage enumerates the three migrations (`Share.share`, `Share.shareUri`, `Share.shareXFiles`), each rewritten to `SharePlus.instance.share(ShareParams(...))`. The connective fragment ` with SharePlus.instance.share(ShareParams(` recurs by design across the examples.
- `share_plus_missing_position_origin` (line 297): its correctionMessage shows the double `(context.findRenderObject()! as RenderBox)` lookup it then advises hoisting into a local. The cast fragment recurs to demonstrate the very duplication being warned against.

The cross-message overlap between the two rules was only `" sharePositionOrigin"` (20 chars), confirming the finding was intra-message repetition, not cross-rule duplication.

## Fix

Added `_looks_like_code(sub)` and gated the `dup_inline` append on `not _looks_like_code(sub)`. A repeated window is treated as a code/API example (and therefore exempt) when it carries any of: call syntax (`\w\(`), a method chain (`\.\w`), a camelCase identifier (`[a-z][A-Z]`), the `=>` arrow, or the `! as ` cast. These markers reliably appear in a 40-char slice of a code expression — a windowed slice may capture only an open paren, so a balanced-pair test was insufficient — and are absent from English prose.

Prose duplication remains flagged: a repeated plain-English window carries none of the markers, so the original copy/paste-paragraph signal is preserved. Verified by inspection — a synthetic repeated prose window returns `False` from `_looks_like_code` (still flagged), while both share_plus windows return `True` (exempt). The standalone checker (`python -m scripts.modules._duplicated_messages`) now reports "No duplicated or suspicious LintCode message text found."

## Known tradeoff

The `\.\w` marker also matches prose abbreviations such as `U.S.`, so a genuinely duplicated prose window containing such a token would be exempted. This is accepted: the check is an informational pre-publish audit, not a gate, and the dedicated `VERIFY_PHRASE` check still catches the most common boilerplate-paste case independently.

## Scope

`scripts/modules/_duplicated_messages.py` (audit tooling) and `CHANGELOG.md` (Maintenance). No lint rule, tier assignment, fixture, or extension code changed. The two share_plus correctionMessages were left as written — the repetition there is intentional and aids clarity.
