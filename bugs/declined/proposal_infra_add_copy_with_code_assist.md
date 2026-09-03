# PROPOSAL: Code Assist to Generate `copyWith` Method

**Status: Declined**

Created: 2026-09-02
Type: Tooling / Infrastructure
Related rules: none

---

## Summary

DCM ships `add-copy-with`, a code assist (not a diagnostic) that generates a `copyWith` method for an immutable class from its constructor parameters.

**Closes gap:** DCM `add-copy-with` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Hand-writing `copyWith` for a class with many fields is repetitive and error-prone (a field added to the constructor but forgotten in `copyWith` silently breaks immutable-update call sites). DCM offers this as an editor "quick assist" invoked at the class declaration, independent of any lint diagnostic — it fires with no warning present, purely as a generation aid.

`saropa_lints` currently has no code-assist system at all: every entry in `fixGenerators` is a `DartFix` tied to a `LintCode` diagnostic (see `Skill(lint-rules)` and `lib/src/fixes/`). There is no mechanism for an assist that runs independent of a lint violation. Building one is a new capability, not a rule addition, and the ROI is low relative to the 2383 diagnostic rules already shipped — `copyWith` boilerplate is already solved for most consumers by `freezed`/`data_class` code generation, so the audience for a manual-generation assist is narrow (plain immutable classes without a build_runner codegen dependency).

---

## Detection / Behavior

Not applicable — this is a generative code assist, not a detection rule. It would need to:

1. Trigger from a class declaration (via a "Quick Assist" style entry point, not a `LintCode`).
2. Read the primary constructor's parameter list.
3. Emit a `copyWith({Type1? field1, Type2? field2, ...}) => ClassName(field1: field1 ?? this.field1, ...)` method inserted into the class body.

### Should flag (bad code)

Not applicable (no diagnostic).

### Should pass (good code)

Not applicable (no diagnostic).

---

## Proposed Tier

Tier: N/A — infrastructure, not a tier-assigned lint rule.

Justification: This is a code-generation assist, not a diagnostic. If ever built, it would ship as an editor command/quick-assist, not register in `lib/src/tiers.dart`.

---

## Edge Cases

1. **Class already has a `copyWith`** — assist should replace or decline to generate, needs discussion.
2. **Constructor uses `required` positional params** — copyWith semantics for positional-required fields are ambiguous (there is no "keep existing value" sentinel for a non-nullable positional slot).
3. **Class already uses `freezed`/`built_value`/`data_class` codegen** — assist should detect and skip, since a generated `copyWith` would conflict with or duplicate the codegen output.
4. **Nullable fields** — cannot distinguish "explicitly set to null" from "not passed" without a sentinel wrapper (`Wrapped<T>` pattern), a known hard problem for any copyWith generator.

---

## Alternatives Considered

- **Do nothing** — recommended for now. `saropa_lints` has no code-assist infrastructure; building one for a single low-demand generator is a large investment (new extension command surface, new AST-to-source-edit pipeline separate from `DartFix`) for a problem `freezed` already solves for most Flutter projects.
- **Note as a future idea only** — record the gap here so it is not silently forgotten, but do not schedule work. Revisit only if a code-assist system is built for other reasons (e.g. a broader "generate boilerplate" feature) and `copyWith` becomes a cheap addition on top of that infrastructure.

---

## Decision

Not yet decided — logged as low-priority future idea per task instructions, not proposed for near-term implementation.

---

## Implementation Notes

None — no implementation planned at this time.

---

## Commits

None yet.
