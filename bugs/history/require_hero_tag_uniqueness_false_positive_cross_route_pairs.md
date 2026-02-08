# `require_hero_tag_uniqueness` False Positive on Cross-Route Hero Pairs

## Status: CONFIRMED BUG

## Summary

`require_hero_tag_uniqueness` flags Hero widgets that share the same literal string tag within a single file, even when the two Heroes exist on **different routes** — which is exactly how Hero animations are designed to work. Flutter's Hero widget requires matching tags on the source route and destination route. If both are defined in the same file (common for inline navigation), the rule incorrectly reports the destination Hero as a duplicate.

## Severity

**High** — The rule actively discourages correct Hero usage. Hero animations are a core Flutter feature, and the most natural way to write them (source Hero + inline `MaterialPageRoute` with destination Hero in the same file) always triggers this error. Developers either suppress the warning everywhere (defeating its purpose) or avoid Hero animations entirely.

## The Core Problem: File-Scoped Detection Without Route Awareness

The rule scans the entire `CompilationUnit` (file) for `Hero` constructors with `SimpleStringLiteral` tag values, collects them in a map, and flags any tag that appears more than once. It has **zero awareness** of navigation context — it cannot distinguish:

1. **Two Heroes with the same tag on the SAME route** (actual bug — should flag)
2. **Two Heroes with the same tag on DIFFERENT routes** (correct usage — should NOT flag)

Since Hero animations fundamentally require matching tags across routes, the rule flags the exact pattern that Flutter's documentation recommends.

## Reproducer

### Code that falsely triggers the error

```dart
// Source Hero — on the current route (home screen)
GestureDetector(
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => Scaffold(
          body: Center(
            // Destination Hero — on the PUSHED route (detail screen)
            child: Hero(
              tag: 'avatar-profile',     // ← flagged as duplicate
              child: CircleAvatar(radius: 100),
            ),
          ),
        ),
      ),
    );
  },
  child: Hero(
    tag: 'avatar-profile',              // ← first occurrence (not flagged)
    child: CircleAvatar(radius: 24),
  ),
),
```

**Diagnostic produced:**
```
[require_hero_tag_uniqueness] Using duplicate Hero tags within the same
navigation context causes Hero animations to fail, resulting in visual
glitches and confusing user experiences.
```

**Why this is wrong:**

1. The two Heroes are on **different routes** — one is in the current widget tree, the other is inside a `MaterialPageRoute.builder` closure that only materializes when the route is pushed.
2. Having the same tag on source and destination is **required** for Hero flight — it's how Flutter knows what to animate between routes.
3. The Flutter documentation explicitly shows this pattern: https://docs.flutter.dev/ui/animations/hero-animations

### Real-world file

`lib/components/home/section/home_section_top_contacts.dart` line 245:

```dart
// Source Hero (home screen, line ~239)
child: Hero(
  tag: 'test-hero-minimal',
  child: Container(width: 50, height: 50, color: Colors.red),
),

// Destination Hero (inside MaterialPageRoute builder, line ~226)
child: Hero(
  tag: 'test-hero-minimal',    // ← FALSE POSITIVE: flagged as duplicate
  child: Container(width: 200, height: 200, color: Colors.red),
),
```

The Hero animation works correctly — the red box flies from 50x50 to 200x200 during the route transition. The lint rule flags working, correct code as an error.

## Root Cause

### Location

`lib/src/rules/animation_rules.dart` — `RequireHeroTagUniquenessRule` (lines 489-532) and `_HeroTagCollector` visitor (lines 534-558).

### The buggy detection logic

```dart
class _HeroTagCollector extends RecursiveAstVisitor<void> {
  final Map<String, List<AstNode>> heroTags = <String, List<AstNode>>{};

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? constructorName = node.constructorName.type.element?.name;
    if (constructorName == 'Hero') {
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'tag') {
          final Expression tagValue = arg.expression;

          if (tagValue is SimpleStringLiteral) {
            final String tagString = tagValue.value;
            // Problem: Collects ALL Hero tags in the file regardless of
            // which route/navigation context they belong to
            heroTags.putIfAbsent(tagString, () => <AstNode>[]);
            heroTags[tagString]!.add(arg);
          }
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}
```

```dart
// Reporting: flags all occurrences after the first
for (final MapEntry<String, List<AstNode>> entry in heroTags.entries) {
  if (entry.value.length > 1) {
    for (int i = 1; i < entry.value.length; i++) {
      reporter.atNode(entry.value[i], code);
    }
  }
}
```

### Two distinct problems

**Problem 1 — No route-context awareness:** The visitor uses `RecursiveAstVisitor` on the entire `CompilationUnit`, treating the whole file as a single "navigation context." It cannot distinguish between Heroes on the current widget tree vs. Heroes inside a `MaterialPageRoute.builder`, `PageRouteBuilder.pageBuilder`, `showDialog.builder`, or any other route constructor closure. Every Hero in the file is treated as being on the same route.

**Problem 2 — Contradicts Hero's core design:** Hero animations REQUIRE tag pairs — one on the source route and one on the destination route. The rule's error message says "Ensure each Hero tag is unique within a given Navigator" but its detection fires on tags that are unique within each route (which is what matters). Two Heroes with the same tag on different routes is the entire point of the Hero widget.

## Suggested Fix

### Approach A: Scope-aware visitor (recommended)

Track whether the visitor is inside a route builder closure. When visiting nodes inside `MaterialPageRoute.builder`, `PageRouteBuilder.pageBuilder`, or similar route constructors, treat them as a separate navigation context:

```dart
class _HeroTagCollector extends RecursiveAstVisitor<void> {
  // Separate maps for different route contexts
  final Map<String, List<AstNode>> currentRouteHeroes = {};
  final Map<String, List<AstNode>> pushedRouteHeroes = {};
  bool _insideRouteBuilder = false;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? name = node.constructorName.type.element?.name;

    // Detect route builder entry
    if (_isRouteConstructor(name)) {
      _insideRouteBuilder = true;
      super.visitInstanceCreationExpression(node);
      _insideRouteBuilder = false;
      return;
    }

    if (name == 'Hero') {
      // ... extract tag ...
      final map = _insideRouteBuilder ? pushedRouteHeroes : currentRouteHeroes;
      map.putIfAbsent(tagString, () => []);
      map[tagString]!.add(arg);
    }
    super.visitInstanceCreationExpression(node);
  }

  bool _isRouteConstructor(String? name) {
    return name == 'MaterialPageRoute' ||
           name == 'CupertinoPageRoute' ||
           name == 'PageRouteBuilder';
  }
}
```

Then only flag duplicates WITHIN the same route context, not across contexts.

### Approach B: Only flag 3+ occurrences (simpler but less precise)

A Hero pair (source + destination) means exactly 2 occurrences of a tag in a file. Three or more occurrences almost certainly indicate a real duplicate within a single route. Change the threshold from `> 1` to `> 2`:

```dart
if (entry.value.length > 2) { // Allow pairs, flag triples
```

This is less precise (misses actual same-route duplicates when there are exactly 2) but eliminates the most common false positive (cross-route pairs).

### Approach C: Downgrade to warning (minimal fix)

At minimum, change the severity from `DiagnosticSeverity.ERROR` to `DiagnosticSeverity.WARNING` since the rule has known false positives on correct Hero usage:

```dart
errorSeverity: DiagnosticSeverity.WARNING, // was ERROR
```

## Affected Patterns (Not Exhaustive)

### 1. Inline navigation with Hero (Flutter docs pattern)
```dart
// This is the standard Hero example from Flutter docs
Hero(tag: 'hero-tag', child: source)
// ...
Navigator.push(MaterialPageRoute(
  builder: (_) => Hero(tag: 'hero-tag', child: destination),  // FALSE POSITIVE
))
```

### 2. showDialog with Hero
```dart
Hero(tag: 'expand', child: thumbnail)
// ...
showDialog(builder: (_) =>
  Hero(tag: 'expand', child: fullImage),  // FALSE POSITIVE
)
```

### 3. Custom page route with Hero
```dart
Hero(tag: 'card', child: listItem)
// ...
PageRouteBuilder(
  pageBuilder: (_, __, ___) =>
    Hero(tag: 'card', child: detailView),  // FALSE POSITIVE
)
```

### 4. Helper method returning route with Hero
```dart
Hero(tag: 'profile', child: avatar)
// ...
Route _buildDetailRoute() => MaterialPageRoute(
  builder: (_) => Hero(tag: 'profile', child: largeAvatar),  // FALSE POSITIVE
)
```

## What the Rule SHOULD Catch (True Positives)

The rule correctly identifies these actual bugs, but currently cannot distinguish them from the false positives above:

```dart
// Two Heroes with same tag in the SAME widget tree (actual bug)
Column(children: [
  Hero(tag: 'avatar', child: image1),
  Hero(tag: 'avatar', child: image2),  // TRUE POSITIVE — same route
])
```

```dart
// Duplicate tags in a ListView (actual bug)
ListView(children: items.map((item) =>
  Hero(tag: 'item', child: Text(item.name)),  // TRUE POSITIVE — same literal tag for all items
).toList())
```

## Impact on Developer Experience

This rule fires on **every correct usage** of Hero animations where source and destination are in the same file. Since the severity is `ERROR` (red underline in VS Code), it creates high-visibility noise that:

1. **Blocks adoption of Hero animations** — developers see a red error and assume their code is wrong
2. **Trains developers to suppress the rule** — `// ignore: require_hero_tag_uniqueness` everywhere
3. **Erodes trust in saropa_lints** — when a rule's most common trigger is a false positive, developers stop reading the warnings

This is the third confirmed false-positive pattern in saropa_lints rules (after `check_mounted_after_async` and `require_location_timeout`), all sharing the same root cause: **detection logic that operates on syntax without understanding semantics or scope**.

## Environment

- **saropa_lints**: path dependency from `D:\src\saropa_lints`
- **Rule file**: `lib/src/rules/animation_rules.dart` lines 489-558
- **Test project**: `D:\src\contacts`
- **Triggered in**: `lib/components/home/section/home_section_top_contacts.dart:245`
- **Pattern flagged**: Standard Flutter Hero animation pair (source + destination in same file)
- **Flutter docs reference**: https://docs.flutter.dev/ui/animations/hero-animations
