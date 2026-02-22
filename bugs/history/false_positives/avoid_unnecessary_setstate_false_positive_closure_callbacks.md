# Bug Report: `avoid_unnecessary_setstate` — False Positive on setState Inside Closures/Callbacks

## Diagnostic Reference

```json
[{
  "resource": "/D:/src/contacts/lib/components/main_layout/search/app_search_bar.dart",
  "owner": "_generated_diagnostic_collection_name_#2",
  "code": "avoid_unnecessary_setstate",
  "severity": 4,
  "message": "[avoid_unnecessary_setstate] setState called in lifecycle method where not needed. This violates the widget lifecycle, risking setState-after-dispose errors or silent state corruption. {v6}\nIn initState/dispose, modify state directly without setState. Verify the change works correctly with existing tests and add coverage for the new behavior.",
  "source": "dart",
  "startLineNumber": 187,
  "startColumn": 24,
  "endLineNumber": 187,
  "endColumn": 39,
  "modelVersionId": 1,
  "origin": "extHost1"
}]
```

---

## Summary

The `avoid_unnecessary_setstate` rule flags `setState` calls inside closures (stream listeners, `Future.delayed` callbacks, etc.) that are *defined* within a lifecycle method but *execute* later, after the widget has already built. The rule's AST visitor uses `RecursiveAstVisitor` which walks into closure bodies without distinguishing between synchronous code in the lifecycle method and deferred code in callbacks. This produces false positives for the common Flutter pattern of setting up stream subscriptions in `initState`.

---

## The False Positive Scenario

### Triggering Code

`lib/components/main_layout/search/app_search_bar.dart` — a search bar widget that subscribes to preference changes:

```dart
@override
void initState() {
  super.initState();

  Future<void>.delayed(SearchWelcomeAnimation.AnimationDurationTotal, () {
    if (mounted) {
      _showAnimationNotifier.updateValue(false);
    }
  });

  // Rebuild when focus mode changes to update gradient indicator
  _focusModeSubscription =
      <UserPreferenceType>[
        UserPreferenceType.ActiveContactFocusMode,
      ].notify()?.listen((_) {
        if (mounted) setState(() {});  // <-- FLAGGED
      });
}
```

The `setState(() {})` on line 187 is inside a `.listen()` callback. It does **not** run during `initState` — it runs asynchronously when the preference stream emits a new value, potentially minutes or hours later. The code already guards with `if (mounted)`, making it a safe and idiomatic pattern.

---

## Root Cause Analysis

The visitor class `_SetStateCallFinder` ([widget_lifecycle_rules.dart:689-699](lib/src/rules/widget_lifecycle_rules.dart#L689-L699)):

```dart
class _SetStateCallFinder extends RecursiveAstVisitor<void> {
  _SetStateCallFinder(this.onFound);
  final void Function(MethodInvocation) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      onFound(node);
    }
    super.visitMethodInvocation(node);
  }
}
```

`RecursiveAstVisitor` traverses **all** descendant AST nodes, including:

1. `FunctionExpression` nodes (closures/lambdas passed to `.listen()`, `.then()`, `Future.delayed()`, etc.)
2. The `Block` bodies inside those closures
3. `MethodInvocation` nodes (`setState`) inside those blocks

The visitor has no mechanism to distinguish between:

| Call Site | When Does setState Execute? | Is It "Unnecessary"? |
|---|---|---|
| Direct call in `initState` body | Synchronously during `initState` | **Yes** — state is set before first build anyway |
| Inside `.listen()` callback | Asynchronously when stream emits | **No** — widget has already built, setState is required |
| Inside `Future.delayed()` callback | Asynchronously after delay | **No** — widget has already built, setState is required |
| Inside `.then()` callback | Asynchronously when Future completes | **No** — widget has already built, setState is required |

The rule treats all four cases identically, which is incorrect for cases 2-4.

### AST Structure

For the triggering code, the AST looks like:

```
MethodDeclaration (initState)
  └─ Block (method body)
      └─ ExpressionStatement
          └─ MethodInvocation (.listen)
              └─ ArgumentList
                  └─ FunctionExpression (closure: (_) { ... })  ← boundary
                      └─ Block (closure body)
                          └─ IfStatement
                              └─ Block
                                  └─ ExpressionStatement
                                      └─ MethodInvocation (setState)  ← flagged
```

The `FunctionExpression` node is the semantic boundary — code inside it is deferred, not synchronous with the lifecycle method.

---

## Additional False Positive Examples

Any of these common Flutter patterns would be incorrectly flagged:

```dart
// Pattern 1: Stream subscription in initState
@override
void initState() {
  super.initState();
  _subscription = myStream.listen((data) {
    if (mounted) setState(() { _data = data; });  // FLAGGED — false positive
  });
}

// Pattern 2: Future callback in initState
@override
void initState() {
  super.initState();
  _loadData().then((result) {
    if (mounted) setState(() { _result = result; });  // FLAGGED — false positive
  });
}

// Pattern 3: Timer callback in initState
@override
void initState() {
  super.initState();
  _timer = Timer.periodic(Duration(seconds: 1), (_) {
    if (mounted) setState(() { _elapsed++; });  // FLAGGED — false positive
  });
}

// Pattern 4: Delayed execution in didChangeDependencies
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) setState(() {});  // FLAGGED — false positive
  });
}
```

All of these are legitimate, idiomatic Flutter code where `setState` is **required** — removing it would prevent the UI from rebuilding.

---

## Correct vs Incorrect Flagging

| Code Pattern | Currently Flagged | Should Be Flagged |
|---|---|---|
| `initState() { setState(() {}); }` | Yes | **Yes** — synchronous, unnecessary |
| `didChangeDependencies() { setState(() {}); }` | Yes | **Yes** — synchronous, unnecessary |
| `dispose() { setState(() {}); }` | Yes | **Yes** — dangerous in dispose |
| `initState() { stream.listen((_) { setState(() {}); }); }` | **Yes** | **No** — deferred callback |
| `initState() { Future.delayed(d, () { setState(() {}); }); }` | **Yes** | **No** — deferred callback |
| `initState() { future.then((_) { setState(() {}); }); }` | **Yes** | **No** — deferred callback |
| `initState() { Timer.periodic(d, (_) { setState(() {}); }); }` | **Yes** | **No** — deferred callback |

---

## Fix

Override `visitFunctionExpression` in `_SetStateCallFinder` to stop recursion at closure boundaries. When the visitor encounters a `FunctionExpression` (lambda/closure), it should **not** call `super` — this prevents it from walking into the closure body:

```dart
class _SetStateCallFinder extends RecursiveAstVisitor<void> {
  _SetStateCallFinder(this.onFound);
  final void Function(MethodInvocation) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      onFound(node);
    }
    super.visitMethodInvocation(node);
  }

  /// Stop recursion into closures — setState inside a callback (e.g. .listen,
  /// Future.delayed) runs after the lifecycle method, so it's not "unnecessary"
  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Intentionally do not call super — skip closure bodies
  }
}
```

This is safe because:

- Direct `setState` calls in the lifecycle body are still at the top-level visitor scope and will be found
- `setState` inside any closure (`.listen`, `.then`, `Future.delayed`, `Timer.periodic`, `addPostFrameCallback`, etc.) will be skipped
- All closures in lifecycle methods are inherently deferred — there is no case where a `FunctionExpression` inside `initState` executes synchronously during `initState` itself

### Doc Comment Fix

The class-level doc comment for `AvoidUnnecessarySetStateRule` was also incorrect — it described a GestureDetector rule (copy-paste artifact). Updated to accurately describe the setState lifecycle rule and document the closure exception.

---

## Missing Test Coverage

The fixture file ([avoid_unnecessary_setstate_fixture.dart](example_widgets/lib/widget_lifecycle/avoid_unnecessary_setstate_fixture.dart)) previously contained only skeleton `TODO` classes with no actual State classes or lifecycle methods. Updated with:

### BAD cases (should trigger):

```dart
// Direct setState in initState
class _bad1340__MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    // expect_lint: avoid_unnecessary_setstate
    setState(() {});
  }
}

// Direct setState in didChangeDependencies
class _bad1340b__MyWidgetState extends State<MyWidget> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // expect_lint: avoid_unnecessary_setstate
    setState(() {});
  }
}
```

### GOOD cases (should NOT trigger):

```dart
// setState inside stream listener — deferred
class _good1340__MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    Stream<int>.empty().listen((_) {
      if (mounted) setState(() {});
    });
  }
}

// setState inside Future.delayed — deferred
class _good1340b__MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(seconds: 1), () {
      if (mounted) setState(() {});
    });
  }
}
```

---

## Affected Files

| File | Line(s) | What |
|---|---|---|
| `lib/src/rules/widget_lifecycle_rules.dart` | 689-699 | `_SetStateCallFinder` — `RecursiveAstVisitor` walks into closure bodies without stopping |
| `lib/src/rules/widget_lifecycle_rules.dart` | 602-621 | Doc comment — described wrong rule (GestureDetector instead of setState) |
| `example_widgets/lib/widget_lifecycle/avoid_unnecessary_setstate_fixture.dart` | 108-119 | Fixture — skeleton TODO classes, no real test coverage |

## Priority

**High** — This is a fundamental flaw in the visitor traversal. Stream subscriptions and Future callbacks in `initState` are one of the most common Flutter patterns. Every widget that sets up a listener in `initState` and calls `setState` in the callback will produce a false positive. The fix (stopping recursion at `FunctionExpression` boundaries) is a single method override with zero risk to correct positive detections.
