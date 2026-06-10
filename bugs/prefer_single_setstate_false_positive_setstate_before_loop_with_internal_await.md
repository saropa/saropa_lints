# BUG: `prefer_single_setstate` — false positive: setState before a loop merges with setState inside the loop after an in-loop `await`

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-10
Rule: `prefer_single_setstate`
File: `lib/src/rules/widget/build_method_rules.dart` (lines ~858–993)
Severity: False positive (High — fires on the standard per-item import/save loop idiom)
Rule version: v4 (source `version: 13.12.3`) | Since: v13.12.2 (`24307c2a` per-scope counting + `de77951c` branch/await barriers — both predate this gap) | Updated: n/a

---

## Summary

A `setState(...)` immediately before a loop is wrongly merged with a `setState(...)` *inside* the loop body that runs only after an `await` *inside the same loop iteration*. The two calls fire in different frames (each loop iteration suspends at the in-loop `await`), so they can never be combined — yet the rule reports them as mergeable. The v13.12.2 fix (`de77951c`) handles if/else arms, switch cases, try/catch, and **top-level** `await` barriers, but does not treat a loop body as its own segment scope, and the in-loop `await` is consumed too late to reset the count.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_single_setstate'" lib/src/rules/
# lib/src/rules/widget/build_method_rules.dart:821:    'prefer_single_setstate',

# Negative — rule is NOT in the sibling drift-advisor repo
grep -rn "'prefer_single_setstate'" ../saropa_drift_advisor/lib/
# 0 matches
```

**Emitter registration:** `lib/src/rules/widget/build_method_rules.dart:820` (`LintCode('prefer_single_setstate', …)`)
**Rule class:** `PreferSingleSetStateRule` — `lib/src/rules/widget/build_method_rules.dart:802`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

Minimal Dart. Structure mirrors the real per-item import-and-save loops in the
downstream app (`csv_import_panel.dart::_import`, `vcard_import_panel.dart::_import`).

```dart
import 'package:saropa_lints_example/flutter_mocks.dart';

// FALSE POSITIVE: the entry setState (line A) fires once, then EACH loop
// iteration awaits a DB write and then setState's the running counter
// (line B). A and B are separated by an `await` on every iteration, so they
// land in different frames and CANNOT be merged. Must NOT trigger
// prefer_single_setstate — but the rule reports line A.
Future<void> _import(List<Object> items, List<bool> selected) async {
  setState(() => _busy = true);            // line A  ← reported (FALSE POSITIVE)

  int saved = 0;
  for (int i = 0; i < items.length; i++) {
    if (!selected[i]) continue;
    final Object? id = await _save(items[i]);   // in-loop await (segment barrier)
    if (id != null) saved++;
    if (mounted) setState(() => _savedCount = saved);  // line B (runs after await)
  }

  if (mounted) {
    setState(() {                          // line C: own if-arm, deferred — fine
      _busy = false;
      _done = true;
    });
  }
}
```

**Frequency:** Always, for the shape "setState; then a loop whose body awaits then setState".

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the in-loop `await` is a frame barrier between line A and line B exactly as a top-level `await` is in the `_good132_loadingState` fixture case |
| **Actual** | `[prefer_single_setstate] Multiple setState calls cause unnecessary rebuilds…` reported at line A |

Confirmed live in the downstream app (`saropa_lints` plugin 13.12.1, the `{v3}`
message — pre-branch-fix; but the **current 13.12.3 source still fires**, see Root Cause):

```
info - lib/components/contact/import/csv_import_panel.dart:153:7  - [prefer_single_setstate] …
info - lib/components/contact/import/vcard_import_panel.dart:82:7 - [prefer_single_setstate] …
```

---

## AST Context

```
MethodDeclaration (_import)
  └─ BlockFunctionBody
      └─ Block
          └─ ExpressionStatement  setState(_busy=true)   ← line A, REPORTED
          └─ VariableDeclarationStatement  int saved = 0
          └─ ForStatement                                ← NOT deferred as own scope
              └─ Block (loop body)
                  └─ IfStatement  if (!selected[i]) continue
                  └─ VariableDeclarationStatement
                      └─ AwaitExpression  await _save(...)   ← in-loop barrier (ignored)
                  └─ IfStatement  if (id != null) saved++
                  └─ IfStatement  if (mounted) setState(...)  ← line B
          └─ IfStatement  if (mounted) { setState(...) }      ← line C (own arm)
```

The rule's `_SegmentVisitor` overrides `visitIfStatement`, `visitSwitchStatement`,
`visitTryStatement`, and `visitFunctionExpression` to *defer* those as separate
scopes — but has **no** `visitForStatement` / `visitWhileStatement` /
`visitDoStatement` / `visitForElement` override. So the `ForStatement` is walked
inline by `RecursiveAstVisitor` into the *current* `_StatementScan`.

---

## Root Cause

Two cooperating defects in `lib/src/rules/widget/build_method_rules.dart`.

### Defect 1 — loop bodies are not treated as their own execution scope

`_SegmentVisitor` (lines 921–993) defers `if`/`switch`/`try`/closure scopes but
defines no override for loop statements (`ForStatement`, `WhileStatement`,
`DoStatement`, `ForElement`). Because `RecursiveAstVisitor` has no special-casing
for loops, the whole loop body is visited within the single `_StatementScan` that
belongs to the `for` *statement* (line 882, `statement.accept(_SegmentVisitor(scan, defer))`).
Result: a `setState` inside the loop body increments `scan.setStateCount` on the
*same* scan that represents the loop statement, and the in-loop `await` is recorded
on that *same* scan via `visitAwaitExpression` (lines 941–945) — but only as a
single boolean flag for the whole statement, with no notion of "the setState comes
after the await".

### Defect 2 — `count >= 2` is checked before the `hasAwait` reset, within one statement

In `_scanScopeSegments` (lines 873–898):

```dart
for (final Statement statement in _statementsOf(scope)) {
  final _StatementScan scan = _StatementScan();
  statement.accept(_SegmentVisitor(scan, defer));

  if (scan.firstSetState != null) {
    firstInSegment ??= scan.firstSetState;
    count += scan.setStateCount;
    if (count >= 2) return firstInSegment;   // ← line 887: fires FIRST
  }

  // An await suspends execution…                  ← lines 890–895: reset SECOND
  if (scan.hasAwait) {
    count = 0;
    firstInSegment = null;
  }
}
```

Trace for the reproducer:

1. Statement A `setState(_busy=true)` → scan: `setStateCount=1`, `hasAwait=false`.
   → `count=1`, `firstInSegment = A`.
2. Statement `int saved = 0` → 0 setState.
3. The `for` **statement** → scan: walks the whole loop body inline →
   `setStateCount=1` (line B), `hasAwait=true` (the in-loop `await`).
   → line 886: `count += 1` → `count == 2` → **line 887 returns `firstInSegment` (A)** —
   *before* line 892 can apply the `hasAwait` reset that would have separated A from B.

So even ignoring Defect 1, the ordering in Defect 2 means a statement that both
makes a setState **and** awaits cannot act as a clean barrier: its setState is
counted into the running total before its await resets that total. The in-loop
`await` is real and *should* break the segment between A and B.

The `_good132_loadingState` fixture (fixture lines 210–214) passes only because
its `await` is a **top-level** statement that makes *no* setState of its own — so
it hits the `hasAwait` branch with `scan.firstSetState == null`, the `count >= 2`
check is skipped, and the reset runs. The loop case never gets that clean reset.

---

## Suggested Fix

Two independent changes; either alone removes this FP, but both are correct:

1. **Defer loop bodies as their own scope (Defect 1).** Add overrides to
   `_SegmentVisitor` mirroring `visitIfStatement` — visit the loop condition/parts
   on the current path, then `defer(...)` the loop body. A `setState` inside a loop
   body that runs after an in-loop `await` can never merge with a `setState` outside
   the loop; and two `setState`s inside one iteration with an `await` between them
   still split correctly once the body is scanned as its own scope.

   ```dart
   @override
   void visitForStatement(ForStatement node) {
     // The loop body runs an indeterminate number of times and (commonly)
     // awaits per iteration: a setState inside it lands in a different frame
     // from any setState outside the loop. Scan the body as its own scope.
     node.forLoopParts.accept(this);
     defer(node.body);
   }
   // Same for visitWhileStatement, visitDoStatement, and visitForElement
   // (collection-for inside a build list).
   ```

2. **Apply the `hasAwait` reset before the early return, when the same statement
   both setStates and awaits (Defect 2).** Reorder `_scanScopeSegments` so a
   statement that suspends does not let its own (post-await) setState complete a
   pair on the pre-await side. Simplest correct form: when `scan.hasAwait`, count
   only the setState calls that precede the await — or, conservatively, treat any
   awaiting statement as starting a fresh segment after its own contribution. (This
   needs `_StatementScan` to track setState-before-await vs setState-after-await,
   or to not early-return on a statement whose `hasAwait` is true.)

Fix 1 is the minimal, lowest-risk change and matches the existing branch-deferral
pattern already in the file.

---

## Fixture Gap

`example/lib/build_method/prefer_single_setstate_fixture.dart` covers if/else,
switch, try/catch, separate closures, top-level-await loading-state, and
sequential-in-branch — but has **no** loop case. Add:

1. **`_good_setStateBeforeLoopWithInternalAwait`** — entry `setState`, then a
   `for` loop whose body `await`s and then `setState`s a counter. Expect **NO**
   lint (this reproducer).
2. **`_good_setStateInWhileAfterAwait`** — same shape with `while`. Expect **NO** lint.
3. **`_good_collectionForAwaitFree`** — a collection-`for` building children with a
   single setState before it. Expect **NO** lint.
4. **`_bad_twoSequentialSetStatesInsideLoopNoAwait`** — two consecutive `setState`
   calls inside one loop body with **no** `await` between them on that body's
   straight-line path. Expect **LINT** (the loop body, scanned as its own scope,
   still merges genuinely consecutive calls — guards against over-correcting Fix 1).

---

## Environment

- saropa_lints version: source `13.12.3` (this repo); downstream plugin pinned at `13.12.1` (`analysis_options.yaml` → `plugins: saropa_lints: version: "13.12.1"`) emitted the live `{v3}` message
- Dart SDK version: 3.12.1 (stable)
- analysis_server_plugin: ^0.3.4 (`pubspec.yaml`); analyzer: ">=9.0.0 <13.0.0"
- Triggering project/file: `D:\src\contacts` — `lib/components/contact/import/csv_import_panel.dart:153`, `lib/components/contact/import/vcard_import_panel.dart:82`

---

## Note on the other 6 downstream flags (already fixed in 13.12.2)

The same downstream analyze run also flagged `contact_avatar_crop_screen.dart:262`
& `:280`, `contact_reaction_modal.dart:75`, `frame_counted_progress.dart:110`,
`common_radio.dart:89`, and `link_preview_card.dart:116`. All six are
mutually-exclusive-branch or top-level-`await` cases that the v13.12.2 fixes
(`24307c2a` + `de77951c`) already resolve; they fired only because the downstream
project pins the plugin at the pre-fix `13.12.1`. Bumping that pin to `>=13.12.2`
clears them. They are NOT covered by this bug — only the loop-await pattern above
survives in current source.
