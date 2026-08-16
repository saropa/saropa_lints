# BUG: `verify_documented_parameters_exist` — False positive on method/function dartdoc cross-references

**Status: Fixed**

Created: 2026-08-16
Rule: `verify_documented_parameters_exist`
File: `lib/src/rules/core/documentation_rules.dart` (line ~735)
Severity: False positive — HIGH (944 hits in contacts project; no workaround short of removing valid dartdoc)
Rule version: v3

---

## Summary

The rule flags every lowercase-starting `[name]` in a doc comment that doesn't match a parameter or class field — but many of those are valid dartdoc cross-references to methods, top-level functions, getters, enum values, or extension members. The rule assumes lowercase `[name]` = parameter reference; dartdoc spec says `[name]` = any in-scope identifier.

---

## Fix Applied

Two changes in `_checkDeclaration`:

1. **Extract class method names** alongside field names via new `_extractClassMethodNames` — skip `[name]` when it matches a method/getter/setter on the enclosing class.

2. **Apply `_isConfirmedParameterRef` gate universally** — previously only uppercase `[Name]` was gated; now ALL names that survive the param/field/method checks must also pass the context gate (bullet-list position or "parameter"/"argument" keyword). This eliminates FPs for cross-class and top-level function references.

Fixture updated with method cross-ref, field cross-ref, top-level function ref (all expect NO lint) and a bullet-list stale param (expects LINT).

---

## Environment

- saropa_lints version: (current HEAD)
- Dart SDK version: current stable
- Triggering project: `d:\src\contacts`
- Audit log: `reports/2026.08/2026.08.16/20260816_184138_saropa_lint_audit.log`

---

## Finish Report (2026-08-16)

`_checkDeclaration` in `VerifyDocumentedParametersExistRule` (`lib/src/rules/core/documentation_rules.dart`) treated any lowercase `[name]` in a dartdoc comment that did not match a formal parameter or a class field as a stale parameter reference, ignoring that dartdoc `[name]` syntax resolves to any in-scope identifier — methods, getters/setters, top-level functions, enum values, and extension members included.

The fix adds `_extractClassMethodNames`, mirroring the existing `_extractClassFieldNames`, so method/getter/setter names on the enclosing class suppress the lint the same way field names already did. It also widens the existing `_isConfirmedParameterRef` context gate (bullet-list position, or a following "parameter"/"argument" keyword) from PascalCase-only to all names, so lowercase cross-references to top-level functions or other classes' methods are no longer flagged by default — only names in confirmed parameter-documentation context are.

Known residual gap, not addressed by this fix and not a regression: references to inherited/superclass members, extension methods, and enum values are still suppressed only via the confirmed-context gate, not by name matching, so they remain flagged unless written in non-bullet, non-keyword prose. A narrower related risk: if a class declares a getter/setter whose name coincidentally matches a genuinely-removed parameter, the fix will now silently suppress that stale reference — same tradeoff the pre-existing field-name suppression already accepted, just extended to methods.

The rule's DartDoc header (`Suppressions:` section) was updated to describe the current suppression set and gate behavior accurately.

Testing: `dart analyze` on the rule file and fixture returned no issues. `test/rules/core/documentation_rules_test.dart` only pins rule instantiation for this rule — it does not assert on-lint/no-lint behavior, so it could not have caught the original bug or verify this fix; the fixture at `example/lib/verify_documented_parameters_exist_fixture.dart` carries the actual behavioral coverage (`expect_lint` markers), checked via the project's scan-CLI/accuracy tooling rather than `dart test`.

### Follow-up hardening (same day)

A second pass closed most of the residual gap noted above and fixed a latent defect discovered while doing so:

- Same-file superclass chains are now walked (`_sameFileClassChain`/`_findClassInUnit`) so a subclass's docs can reference an inherited field or method declared on a same-file superclass without a false positive. Cross-file/external superclasses still fall back to the confirmed-context gate.
- Same-file top-level function names and enum constant names are now extracted (`_extractSameFileTopLevelNames`) and suppress the lint the same way class members do.
- `_isConfirmedParameterRef`'s bullet-list detection had a latent off-by-one: `docText.substring(start - 2, start).trimLeft()` followed by `.endsWith('-')` could only ever match a literal `-` with zero whitespace before the following `[` — the conventional `- [name]` markdown style (hyphen, space, bracket) never matched. Replaced with an 8-character lookback matched against `RegExp(r'(^|\s)([-*]|\d+\.)\s*$')`, which correctly recognizes `-`, `*`, and numbered (`1.`) bullet markers with normal spacing.
- Verified end-to-end (not just compiled) by copying the fixture to a non-`_fixture`-named file in a throwaway in-package scratch directory (the scan CLI silently skips `_fixture.dart` paths) and running `dart run saropa_lints scan --tier comprehensive --format json` against it: exactly 5 `verify_documented_parameters_exist` diagnostics fired, at the 5 lines carrying `expect_lint` markers (including the new star- and numbered-bullet cases), and zero fired on any suppressed cross-reference case (same-class/inherited method or field, same-file top-level function, same-file enum constant).
- Remaining known gap: references to members declared in another file or package (cross-file inheritance, extension methods, imported enum values) are still only suppressed via the confirmed-context gate, not by name resolution — closing that fully would require resolving `[name]` through the analyzer's element model, which was scoped out as a larger follow-up (see the unrequested-feature note in the session handoff).

Closes bug: `plans/history/2026.08/2026.08.16/verify_documented_parameters_exist_false_positive_method_crossrefs.md`
