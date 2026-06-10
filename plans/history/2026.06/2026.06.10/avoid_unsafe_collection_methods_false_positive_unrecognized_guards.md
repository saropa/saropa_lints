# BUG: `avoid_unsafe_collection_methods` — Misses seven common non-emptiness guard shapes (combined `|| isEmpty`, `continue`/nested-block early return, `length <= 1`, `Map.keys`/`Map.values` after `Map`-level / `while`-loop guard, extension `isListNullOrEmpty`, index-expression target, split-result-via-variable)

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `avoid_unsafe_collection_methods`
File: `lib/src/rules/data/collection_rules.dart` (line ~380, class `AvoidUnsafeCollectionMethodsRule`; guard helpers ~455–926)
Severity: False positive
Rule version: v10 (rule), v9 in dartdoc header | Since: v0.1.8 | Updated: v4.13.0

---

## Summary

`avoid_unsafe_collection_methods` flags `.first` / `.last` / `.single` even when emptiness is provably impossible inline, because its guard-recognition helpers handle only a narrow set of guard shapes. Seven distinct correct-code patterns trip it. The downstream project's own code-quality rule REQUIRES the nullable-safe form, so genuine unguarded accessors are true positives — but these 24 sites are already guarded by a construct the rule cannot see, forcing `// ignore:` workarounds on idiomatic Dart.

24 false positives across 18 sites in `D:\src\contacts`; 1 true positive in the same batch (`remote_locale_cache_meta.dart:210`, an unguarded `pathSegments.last`, correctly flagged).

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_unsafe_collection_methods'" lib/src/rules/
# lib/src/rules/data/collection_rules.dart:371:    'avoid_unsafe_collection_methods',
# lib/src/rules/data/collection_rules.dart:372:    '[avoid_unsafe_collection_methods] Calling .first, .last, or .single ...'

# Negative — NOT in sibling drift-advisor repo
#   (Select-String over saropa_drift_advisor/lib/src + extension/src) → 0 matches
```

**Emitter registration:** `lib/src/rules/data/collection_rules.dart:370` (`_code`), rule class `AvoidUnsafeCollectionMethodsRule` at line 354.
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`.

---

## Reproducer

Each block is correct Dart that the rule wrongly flags. `// LINT (FP)` marks the wrongly-reported line.

```dart
import 'package:collection/collection.dart';

class UnsafeCollectionFalsePositives {
  // Pattern 1 — combined `x == null || x.isEmpty` early return.
  // After the guard, `pages` is non-null and non-empty.
  Object? combinedNullOrEmpty(List<Object>? pages) {
    if (pages == null || pages.isEmpty) {
      return null;
    }
    return pages.first; // LINT (FP) — guard guarantees non-empty
  }

  // Pattern 2 — early return guarded by `length < 2` / `length <= 1`.
  // `_isEmptinessCheck` only accepts `< N (N>=1)` for the LT op but rejects
  // `<= 1` (it requires value == 0 for LT_EQ), and combined `|| length < 2`
  // is never reached because the whole `||` is passed to the checker.
  double firstOfLenGuarded(List<double>? timezones) {
    if (timezones == null || timezones.length < 2) {
      return 0;
    }
    return timezones.first; // LINT (FP) — length >= 2 here
  }

  // Pattern 3 — `continue` guard inside a for-loop (not return/throw).
  // `_containsEarlyExit` recognizes only ReturnStatement / ThrowExpression.
  List<String> continueGuard(Map<String, List<Object>> byName) {
    final List<String> out = <String>[];
    for (final List<Object> candidates in byName.values) {
      if (candidates.length != 1) {
        continue;
      }
      out.add(candidates.first.toString()); // LINT (FP) — length == 1 here
    }
    return out;
  }

  // Pattern 4 — access nested in an INNER block; guard sits in the OUTER
  // (method) block. `_isCollectionGuardedByEarlyReturn` looks only at the
  // NEAREST enclosing Block via thisOrAncestorOfType<Block>().
  String nestedBlockGuard(List<String> contacts) {
    if (contacts.isEmpty) {
      return '';
    }
    if (true) {
      return contacts.first; // LINT (FP) — outer guard proves non-empty
    }
  }

  // Pattern 5 — `Map.keys` / `Map.values` accessed after a guard on the MAP,
  // or inside a `while (map.length > n)` loop. Collection name resolves to
  // `map.keys` but the guard names `map`; and `while` conditions aren't
  // inspected at all (only if / ternary / collection-if / same-block return).
  String mapKeysGuard(Map<String, int> buckets) {
    if (buckets.isEmpty) {
      return '';
    }
    return buckets.keys.first.toString(); // LINT (FP) — buckets non-empty
  }

  void trimWhileLoop(Map<String, int> map, int maxEntries) {
    while (map.length > maxEntries) {
      final String oldest = map.keys.first; // LINT (FP) — loop cond => non-empty
      map.remove(oldest);
    }
  }

  // Pattern 6 — extension emptiness guard (`isListNullOrEmpty`) not in the
  // recognized check set; also the access name differs from the guard name
  // (result!.files vs result?.files).
  Object pickFirst(({List<Object> files})? result) {
    if (result?.files.isListNullOrEmpty ?? true) {
      return 0;
    }
    return result!.files.first; // LINT (FP) — non-empty after guard
  }

  // Pattern 7 — `.first` on an INDEX-expression target with an inline
  // `isNotEmpty` guard in the SAME condition. `_collectionNameOf` returns
  // null for IndexExpression / PostfixExpression, so no guard is even checked.
  Object? indexedTarget(Map<String, List<Object>> props, String k) {
    if (props[k]!.isNotEmpty) {
      return props[k]!.first; // LINT (FP) — guarded by isNotEmpty inline
    }
    return null;
  }

  // Pattern 8 — `.split()` result stored in a variable, then `.first`.
  // `_isGuaranteedNonEmpty` recognizes split ONLY when the target IS the
  // split MethodInvocation; through a variable it is a SimpleIdentifier.
  String splitViaVariable(String prefix) {
    final List<String> prefixParts = prefix.split(';');
    return prefixParts.first; // LINT (FP) — split() always yields >= 1 element
  }
}
```

**Frequency:** Always, for each of the eight patterns above.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — each access is provably non-empty inline (early-return / loop / ternary / inline guard, or a `split()` result that always has ≥1 element). |
| **Actual** | `[avoid_unsafe_collection_methods] Calling .first, .last, or .single on an empty collection ...` reported at each marked line. |

### Real-codebase sites (verdict per site)

| Site | Pattern | Verdict |
|---|---|---|
| `connection_admin_drift_io.dart:200` | 5 (`.values.first` after `Map.length == 1` guard) | FP |
| `vcard_import_utils.dart:156` | 8 (`prefixParts.first`, split-via-var) | FP |
| `vcard_import_utils.dart:216` | 8 (`orgParts.first`, split-via-var) | FP |
| `vcard_import_utils.dart:800` | 8 (`parts.first`, split-via-var) | FP |
| `remote_locale_cache_meta.dart:210` | none — `pathSegments.last` unguarded | **TP** |
| `remote_locale_cache_meta.dart:240` | 5 (`map.keys.first` in `while` loop) | FP |
| `remote_static_content_cache_meta.dart:265` | 5 (`map.keys.first` in `while` loop) | FP |
| `import_companion_from_json_file.dart:46` | 6 (`result!.files.first`, `isListNullOrEmpty` guard) | FP |
| `import_companion_from_json_file.dart:99` | 1 (`fileData.first`, `== null \|\| isEmpty`) | FP |
| `wikimedia_birth_model.dart:202` | 1 (`pages.first`, `== null \|\| isEmpty`) | FP |
| `pre_processor_relationship_name_link.dart:118` | 3 (`candidates.first`, `continue` on `length != 1`) | FP |
| `contact_timezone_utils.dart:397` | 2 (`timezones.first`, `== null \|\| length < 2`) | FP |
| `contact_match_batch.dart:291` | 3 (`entry.value.first`, `continue` on `length < 2`) | FP |
| `contact_match_batch.dart:292` | 3 (`entry.value.first`, `continue` on `length < 2`) | FP |
| `contact_name_parsing_utils.dart:101` | 4 (`words.first`, nested block; outer `words.isEmpty`) | FP |
| `contact_name_parsing_utils.dart:176` | 2 (`parts.first`, `length <= 1` early return) | FP |
| `contact_name_parsing_utils.dart:178` | 2 (`parts.last`, `length <= 1` early return) | FP |
| `contact_quick_channels_resolver.dart:119` | 1 (`phones.first`, `== null \|\| isEmpty`) | FP |
| `signature_line_classifiers.dart:44` | 1/2 (`words.first`, `isEmpty \|\| length > 4`) | FP |
| `signature_vcard_extractor.dart:159` | 7 (`props[k]!.first`, indexed target, inline guard) | FP |
| `data_name_utils.dart:51` | 4 (`contacts.first`, nested block; outer `isEmpty`) | FP |
| `data_name_utils.dart:64` | 4 (`contacts.first`, nested block; outer `isEmpty`) | FP |
| `dominant_color_utils.dart:99` | 5 (`buckets.keys.first` after `buckets.isEmpty`) | FP |

---

## AST Context

Pattern 1 (combined `|| isEmpty` early return — `wikimedia_birth_model.dart:202`):

```
MethodDeclaration (_firstPage)
  └─ BlockFunctionBody
      └─ Block                                    ← _isCollectionGuardedByEarlyReturn scans here
          ├─ VariableDeclarationStatement (pages = JsonUtilsLocal.toList(...))
          ├─ IfStatement
          │     condition: BinaryExpression  `pages == null || pages.isEmpty`  (op = BAR_BAR)
          │     then: ReturnStatement (return null)   ← _containsEarlyExit = true
          └─ ReturnStatement
                └─ MethodInvocation (JsonUtilsLocal.toMap(...))
                    argument: PrefixedIdentifier `pages.first`   ← node reported here
```

`_isEmptinessCheck` receives the whole `pages == null || pages.isEmpty` `BinaryExpression`; `src == 'pages.isEmpty'` is false (the source is the full `||`), and the BinaryExpression branch only matches length comparisons (`<`, `<=`, `==`), not `||`. So the guard is missed.

Pattern 4 (nested block — `contact_name_parsing_utils.dart:101`):

```
MethodDeclaration (_stripHonorificPrefix)
  └─ Block (method body)                          ← contains `if (words.isEmpty) return ...`
      ├─ IfStatement  `if (words.isEmpty) return (...)`   (the guard)
      └─ IfStatement  `if (isCommon...(words.first)) { ... }`
            then: Block                           ← thisOrAncestorOfType<Block>() stops HERE
                └─ ReturnStatement
                    └─ ... PrefixedIdentifier `words.first`  ← node reported here
```

`_isCollectionGuardedByEarlyReturn` calls `node.thisOrAncestorOfType<Block>()`, which returns the INNER `if`-body block, not the method body block holding the guard. The guard is invisible.

Pattern 7 (indexed target — `signature_vcard_extractor.dart:159`):

```
ForStatement
  └─ Block
      └─ IfStatement  `if (kCompare == lower && props[k]!.isNotEmpty)`
            then: Block
                └─ ReturnStatement
                    └─ PropertyAccess  `props[k]!.first`
                          realTarget: PostfixExpression  `props[k]!`  (operand = IndexExpression)
                                                            ← _collectionNameOf returns null
```

`_collectionNameOf` handles only `SimpleIdentifier` / `PrefixedIdentifier` / `PropertyAccess`. For a `PostfixExpression`(`IndexExpression`) it returns null, so the `collectionName != null` precondition fails and `runWithReporter` skips guard evaluation entirely (line ~411) before reporting.

---

## Root Cause

The detection in `runWithReporter` (PropertyAccess branch lines 385–418, PrefixedIdentifier branch 422–452) delegates non-emptiness proof to a small set of helpers that each miss a real guard shape:

### Hypothesis A — `_isEmptinessCheck` (lines 896–926) only matches a bare emptiness/length expression, never a compound `||`

`_isCollectionGuardedByEarlyReturn` (841–857) passes `stmt.expression` straight to `_isEmptinessCheck`. When the guard is `x == null || x.isEmpty` (Patterns 1 & 2 & the `isEmpty || length>N` form in Pattern, classifier:44), the expression is a `||` `BinaryExpression`. `_isEmptinessCheck` does `src == '$name.isEmpty'` (false for the whole `||`) and otherwise only matches a length-comparison `BinaryExpression` whose operator is `<`/`<=`/`==`. `||`/`&&` are never decomposed. Fix: when the guard expression is a `BinaryExpression` with `BAR_BAR`, recurse into both operands and return true if either is an emptiness check for `name`.

### Hypothesis B — `_isEmptinessCheck` rejects `length <= 1` and other `>= 1` floors

For `parts.length <= 1` (Pattern 2, name_parsing:176/178) the early return fires when length ≤ 1, so afterwards length ≥ 2. But the LT_EQ branch (line 919) only accepts `value == 0`. `length < 2` via LT is accepted (`value >= 1`), but `length <= 1` is not, and neither is `length < 1`. Any `length < N (N>=1)`, `length <= N (N>=0)`, `length == k (k < required)` that forces a non-empty remainder should count. Fix: broaden LT_EQ to `value >= 0` and add the symmetric forms.

### Hypothesis C — `_containsEarlyExit` (884–893) ignores `continue` (and `break`) inside loops

Patterns 3 (relationship_name_link:118, contact_match_batch:291/292) guard with `if (cond) continue;` inside a `for`. `_containsEarlyExit` recognizes only `ReturnStatement` and `ThrowExpression`. A `ContinueStatement` in a loop is an equally valid guard for code that follows in the same iteration. Fix: when the enclosing statement of the guard is inside a loop body, treat `ContinueStatement` / `BreakStatement` as early exits.

### Hypothesis D — guard scan uses only the NEAREST `Block`

`_isCollectionGuardedByEarlyReturn` (842) calls `node.thisOrAncestorOfType<Block>()`, returning the innermost block. When the access is nested one block deeper than the guard (Pattern 4: name_parsing:101, data_name_utils:51/64), the guard in the enclosing method block is never seen. Fix: walk OUTWARD through ancestor blocks (or scan all statements that lexically precede the node up to the method body), not just the nearest block.

### Hypothesis E — `Map.keys` / `Map.values` not unified with the backing `Map`, and `while` conditions unchecked

Patterns 5 (connection_admin:200, dominant_color:99, the two `while` trims, mapKeysGuard) access `map.keys.first` / `map.values.first` after a guard on `map` itself (`map.isEmpty` / `map.length == 1`) or inside `while (map.length > n)`. `_collectionNameOf` yields `map.keys`, but the guard names `map`; the names never unify. Separately, `_isGuardedAccess` inspects only `IfStatement` / `ConditionalExpression` / `IfElement` and same-block early returns — never a `WhileStatement` / `ForStatement` condition. Fix: (a) when the target is a `.keys`/`.values`/`.entries` PropertyAccess on a Map, also test the guard against the underlying map identifier; (b) add a `_isGuardedByWhile`/loop-condition check mirroring `_isGuardedByIfStatement`.

### Hypothesis F — extension emptiness predicates not recognized

Pattern 6 (import_companion:46) guards with `result?.files.isListNullOrEmpty`. The early-return checker has no entry for project extension predicates (`isListNullOrEmpty`, `isNullOrEmpty`). `_isValidGuardCondition` already accepts `propName.contains('NotEmpty') || propName.contains('NotNull')` for the IF-guard path, but `_isEmptinessCheck` (early-return path) has no equivalent. Fix: in `_isEmptinessCheck`, also accept a property/getter whose name contains `Empty`/`NullOrEmpty` on `name` (or on a `name?.…` chain) as an emptiness check.

### Hypothesis G — `_collectionNameOf` returns null for indexed / postfix targets, disabling ALL guard checks

Pattern 7 (signature_vcard_extractor:159): `props[k]!.first`. `_collectionNameOf` returns null for the `PostfixExpression(IndexExpression)` target, so the `collectionName != null` precondition at line 411 short-circuits and the node is reported without ever checking the inline `&& props[k]!.isNotEmpty` guard in the same `if` condition. Fix: extend `_collectionNameOf` to handle `IndexExpression` and `PostfixExpression` via `.toSource()`, so the existing `_isGuardedByIfStatement` source-fallback (`src.contains('$collectionName.isNotEmpty')`) can match.

### Hypothesis H — `split()` result through a variable not recognized

Pattern 8 (vcard_import_utils:156/216/800): `final parts = x.split(';'); ... parts.first`. `_isGuaranteedNonEmpty` (459–463) recognizes `split()` only when the access target IS the `split` `MethodInvocation` (`expr is MethodInvocation && methodName == 'split'`). Through a variable the target is a `SimpleIdentifier`. Fix: when the target is a `SimpleIdentifier`, resolve its initializer within the enclosing block; if it is a `…split(…)` invocation (and the variable is not reassigned), treat as guaranteed non-empty. (Lower priority — split-result is the weakest case; the project could also just use `.firstOrNull`. The guard-shape misses A–G are the high-value fixes.)

---

## Suggested Fix

Priority order (by FP count and idiom frequency):

1. **A + B** — decompose `||` guards and broaden length-floor acceptance in `_isEmptinessCheck` (lines 896–926). Covers Patterns 1 & 2 (7 sites).
2. **D** — scan ancestor blocks, not just the nearest, in `_isCollectionGuardedByEarlyReturn` (line 842). Covers Pattern 4 (3 sites).
3. **C** — accept `continue`/`break` in `_containsEarlyExit` when inside a loop (884–893). Covers Pattern 3 (3 sites).
4. **E** — unify `.keys`/`.values`/`.entries` targets with the backing map identifier, and add loop-condition guard recognition. Covers Pattern 5 (5 sites).
5. **G** — extend `_collectionNameOf` to `IndexExpression`/`PostfixExpression` (line 828). Covers Pattern 7 (1 site).
6. **F** — recognize extension `*Empty`/`NullOrEmpty` getters in `_isEmptinessCheck`. Covers Pattern 6 (1 site).
7. **H** — resolve `split()` through an unreassigned local. Covers Pattern 8 (3 sites).

Each fix is additive to an existing helper; none changes the report path for genuinely unguarded access (e.g. `remote_locale_cache_meta.dart:210` stays flagged).

---

## Fixture Gap

The fixture at `example*/lib/data/avoid_unsafe_collection_methods_fixture.dart` should add (each with `// OK` — expect NO lint):

1. **Combined `|| isEmpty` early return** — `if (x == null || x.isEmpty) return;` then `x.first`.
2. **`|| length < 2` / `length <= 1` early return** — both `< 2` (LT) and `<= 1` (LT_EQ) and combined-with-`||` forms.
3. **`continue` guard in a for-loop** — `for (...) { if (c.length != 1) continue; c.first; }` and the `length < 2` form.
4. **Access nested one block below the guard** — method-block `if (x.isEmpty) return;` then `x.first` inside an inner `if`/`for` block.
5. **`Map.keys.first` / `Map.values.first`** — after `if (m.isEmpty) return;`, after `if (m.length == 1)`, and inside `while (m.length > n)`.
6. **Extension emptiness guard** — `if (x.isListNullOrEmpty) return;` (and `x?.files.isListNullOrEmpty ?? true`) then `x.first`.
7. **Indexed target with inline guard** — `if (m[k]!.isNotEmpty) { m[k]!.first; }`.
8. **`split()` via local variable** — `final p = s.split(';'); p.first;` (expect NO lint).

Plus a `// LINT` control: an unguarded `someList.last` / `uri.pathSegments.last` with no guard, to confirm the broadened logic does not suppress genuine positives.

---

## Environment

- saropa_lints version: 13.12.2 (`pubspec.yaml` line 10)
- Dart SDK version: 3.12.1 (stable)
- analysis_server_plugin: ^0.3.4 (native analyzer plugin; not custom_lint)
- Triggering project/files: `D:\src\contacts` — 18 files, 24 false-positive sites (see verdict table above); 1 true positive (`remote_locale_cache_meta.dart:210`) correctly flagged.
