# Task: `avoid_redundant_argument_values`

## Summary
- **Rule Name**: `avoid_redundant_argument_values`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality / Unnecessary Code

## Problem Statement
Passing the default value of a named parameter explicitly at a call site is redundant and clutters the code. It wastes visual space, makes diffs noisier, and can mislead readers into thinking the value is significant or non-default. Common examples include `Text('label', softWrap: true)` where `softWrap` defaults to `true`, or `ListView(reverse: false)`. Removing these redundant arguments makes call sites communicate intent more clearly: the only named arguments present are the ones that differ from defaults. This is especially prevalent in Flutter widget code where widgets have many named parameters with sensible defaults.

## Description (from ROADMAP)
Detects named arguments at call sites whose passed value is identical to the parameter's declared default value, making the argument redundant.

## Trigger Conditions
- A function or constructor invocation contains a named argument.
- The named argument's value is a compile-time constant expression.
- The corresponding parameter has a default value that is also a compile-time constant.
- The passed value is equal to the default value (deep constant equality).
- The parameter is optional (has a default value defined in the declaration).

## Implementation Approach

### AST Visitor
```dart
context.registry.addArgumentList((node) {
  // inspection happens here
});
```

### Detection Logic
1. For each argument in `node.arguments`:
   a. Check if the argument is a `NamedExpression`.
   b. Get the corresponding `ParameterElement` from `argument.staticParameterElement`.
   c. Check if `parameterElement.hasDefaultValue` is true.
   d. Get the default value: `parameterElement.computeConstantValue()` (returns `DartObject?`).
   e. Get the passed value: evaluate `argument.expression` as a constant via `resolver.session.evaluate(argument.expression)` or use `argument.expression.staticValue` if available.
   f. Compare the two `DartObject` values using `DartObject.isIdentical` or `==` on the constant values.
   g. If the values are equal, report the `NamedExpression` node.
2. Skip arguments where either constant evaluation fails (returns null or throws) — avoid false positives.
3. Skip arguments where the parameter element is null (unresolved code).

## Code Examples

### Bad (triggers rule)
```dart
// softWrap defaults to true in Text
Text(
  'Hello',
  softWrap: true,  // LINT: same as default
)

// reverse defaults to false in ListView
ListView.builder(
  reverse: false,  // LINT: same as default
  itemCount: 10,
  itemBuilder: (context, i) => ListTile(title: Text('$i')),
)

// alignment defaults to Alignment.center in some widgets
Container(
  alignment: Alignment.center,  // LINT: same as default
  child: const Text('centered'),
)

// Custom function with defaults
void sendEmail({
  bool urgent = false,
  int retries = 3,
}) {}

void callSite() {
  sendEmail(
    urgent: false,   // LINT: same as default
    retries: 3,      // LINT: same as default
  );
}
```

### Good (compliant)
```dart
// Only passing non-default values
Text(
  'Hello',
  softWrap: false,  // explicitly overriding default
)

// Omitting arguments that match defaults
ListView.builder(
  itemCount: 10,
  itemBuilder: (context, i) => ListTile(title: Text('$i')),
)

// Explicitly different from default
void callSite() {
  sendEmail(urgent: true);  // overrides default
}

// Positional arguments (not named) are always required/intentional
Text('Hello');  // softWrap not passed — that's fine
```

## Edge Cases & False Positives
- **Null defaults**: If the default is `null` and the caller passes `null` explicitly, flag it. However, some APIs use the explicit `null` to mean "I am intentionally passing null" rather than "I forgot the default". In practice, if the default is `null`, passing `null` is still redundant. Flag it, but note that some style guides prefer explicit `null` for documentation purposes.
- **Computed defaults**: Default values that use expressions (e.g., `{String prefix = '${Platform.operatingSystem}:'}`) — if the constant cannot be evaluated at analysis time, skip. Only flag when both sides evaluate successfully as constants.
- **Overridden methods**: When calling an overriding method, the passed argument may need to differ from the super's default. If the override's parameter element has the same default, flag normally; otherwise skip.
- **Named constructors**: Apply the same logic — check the named constructor's parameter defaults.
- **`const` vs non-const equality**: Two `DartObject` instances may represent the same value but differ if one is from an enum and one is a literal. Ensure the comparison is semantic value equality, not reference equality.
- **Widget tests and golden tests**: In tests, explicit default values are sometimes written for documentation/clarity. Consider adding a `// ignore:` mechanism or having the rule suppressed in test files via a configuration option.
- **Boolean `true`/`false` literals**: The most common case. Ensure bool comparison works correctly with `DartObject` APIs.
- **Enum defaults**: `{TextAlign align = TextAlign.left}` — if caller passes `TextAlign.left`, flag it. Enum constant equality via `DartObject` should handle this.
- **`Duration.zero` and similar**: Struct-like constant objects. Equality comparison must be deep (compare all fields), not surface-level.
- **Cascade notation**: Not directly applicable (cascades don't use named args in the same way), but keep in mind.
- **Function tear-off defaults**: If the default is a function reference (rare), skip — comparing function equality is complex.

## Unit Tests

### Should Trigger (violations)
```dart
void myFunc({int count = 0, bool verbose = false, String label = 'default'}) {}

void triggerCases() {
  myFunc(count: 0);           // LINT: 0 == default 0
  myFunc(verbose: false);     // LINT: false == default false
  myFunc(label: 'default');   // LINT: 'default' == default 'default'
  myFunc(count: 0, verbose: false, label: 'default'); // LINT ×3
}

class Widget {
  Widget({this.enabled = true, this.opacity = 1.0});
  final bool enabled;
  final double opacity;
}

void widgetCases() {
  Widget(enabled: true);    // LINT
  Widget(opacity: 1.0);     // LINT
}
```

### Should NOT Trigger (compliant)
```dart
void myFunc({int count = 0, bool verbose = false}) {}

void ok() {
  myFunc(count: 1);        // different from default
  myFunc(verbose: true);   // different from default
  myFunc();                // no named args — fine
}

// Dynamic / non-constant default — skip
String dynamicDefault() => DateTime.now().toString();
void funcWithDynamic({String ts = ''}) {}  // default is constant but ts is empty string
// Caller: funcWithDynamic(ts: ''); // would flag this — empty string equals default

// Null default — caller passes non-null
void withNullDefault({String? name}) {}
void okNull() {
  withNullDefault(name: 'Alice'); // non-null — not flagged
}

// Positional args (not named) — never flagged
void positional(int x, [int y = 0]) {}
void okPositional() {
  positional(5, 0); // not a named arg — no flag
}
```

## Quick Fix
Remove the redundant named argument from the argument list.

- If only one argument in the list is redundant, remove it along with any trailing comma.
- If multiple arguments are redundant, each should be individually removable (offer a fix per violation, and optionally a "Remove all redundant arguments" bulk fix).
- Preserve formatting: if removing the argument leaves the call on a single line, reformat appropriately. If the call was multi-line and one argument is removed, adjust indentation.

**Fix steps:**
1. Identify the `NamedExpression` node to remove.
2. Determine the source range to delete: include the trailing comma if present, or the leading comma if it is the last argument.
3. Apply a `deleteSourceRange` edit to remove the argument.
4. If the argument list becomes empty (no remaining args), also remove surrounding parentheses content but leave `()`.

## Notes & Issues
- Dart SDK: 2.0+ (named parameters with defaults exist since Dart 1.x, but null safety changes some defaults).
- The key API is `ParameterElement.computeConstantValue()` which returns a `DartObject`. This requires that the source is fully resolved. In some analysis contexts (e.g., plugin mode), this should be available.
- Performance consideration: evaluating constants for every named argument in every call is potentially expensive. Cache parameter default values per `ParameterElement` using the element's identity. The analyzer itself caches constant evaluation results, so repeated evaluation of the same element's default should be fast.
- Flutter widgets have many parameters with defaults — this rule will have high value in Flutter codebases but also higher volume of findings. Consider making it configurable (e.g., exclude certain classes or packages).
- The official Dart lint `avoid_redundant_argument_values` already exists in `package:lints`. Verify whether this is a duplicate. If the SDK lint exists and can be enabled, the saropa version should add differentiated value (e.g., better fixes, more precise detection, or integration with project context).
