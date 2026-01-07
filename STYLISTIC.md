# Stylistic Rules

These rules are **not included in any tier**. They represent team preferences where there's no objectively "correct" answer — enable them individually based on your coding conventions.

## Quick Reference

| Rule | Description |
|------|-------------|
| [`prefer_relative_imports`](#prefer_relative_imports) | Use relative imports instead of absolute `package:` imports |
| [`prefer_one_widget_per_file`](#prefer_one_widget_per_file) | One widget class per file |
| [`prefer_arrow_functions`](#prefer_arrow_functions) | Use `=>` arrow syntax for single-return functions |
| [`prefer_all_named_parameters`](#prefer_all_named_parameters) | Use named parameters when 3+ positional params |
| [`prefer_trailing_comma_always`](#prefer_trailing_comma_always) | Trailing commas on all multi-line constructs |
| [`prefer_private_underscore_prefix`](#prefer_private_underscore_prefix) | All instance fields should be private (`_name`) |
| [`prefer_widget_methods_over_classes`](#prefer_widget_methods_over_classes) | Small widgets as methods instead of classes |
| [`prefer_explicit_types`](#prefer_explicit_types) | Explicit types instead of `var`/`final` inference |
| [`prefer_class_over_record_return`](#prefer_class_over_record_return) | Return classes instead of records from methods |
| [`prefer_inline_callbacks`](#prefer_inline_callbacks) | Inline callbacks instead of method references |
| [`prefer_single_quotes`](#prefer_single_quotes) | Single quotes `'string'` instead of double quotes |
| [`prefer_todo_format`](#prefer_todo_format) | TODOs follow `TODO(author): description` format |
| [`prefer_fixme_format`](#prefer_fixme_format) | FIXMEs follow `FIXME(author): description` format |
| [`prefer_sentence_case_comments`](#prefer_sentence_case_comments) | Comments start with capital letter |
| [`prefer_period_after_doc`](#prefer_period_after_doc) | Doc comments end with period |
| [`prefer_screaming_case_constants`](#prefer_screaming_case_constants) | Constants in `SCREAMING_SNAKE_CASE` |
| [`prefer_descriptive_bool_names`](#prefer_descriptive_bool_names) | Booleans use `is`/`has`/`can` prefix |
| [`prefer_snake_case_files`](#prefer_snake_case_files) | File names in `snake_case.dart` |
| [`avoid_small_text`](#avoid_small_text) | Font size at least 12 for accessibility |
| [`prefer_doc_comments_over_regular`](#prefer_doc_comments_over_regular) | Use `///` instead of `//` for public API docs |

## Enabling Stylistic Rules

```yaml
# analysis_options.yaml
custom_lint:
  saropa_lints:
    tier: recommended
  rules:
    # Enable specific stylistic rules your team prefers
    - prefer_relative_imports: true
    - prefer_trailing_comma_always: true
    - prefer_explicit_types: true
```

---

## prefer_relative_imports

Use relative imports instead of absolute `package:` imports for files within the same package.

**Pros:**
- Shorter import paths
- Easier refactoring when moving directories
- Clear indication of local dependencies

**Cons:**
- Absolute paths are more explicit
- Easier to understand file location at a glance
- IDEs may auto-generate absolute imports

### Example

```dart
// BAD (with this rule enabled):
import 'package:my_app/src/utils/helpers.dart';

// GOOD:
import '../utils/helpers.dart';
```

**Quick fix available:** Converts to relative import automatically.

---

## prefer_one_widget_per_file

One widget class per file for easier navigation and searchability.

**Pros:**
- Easier file navigation and searchability
- Smaller, more focused files
- Clear file naming conventions

**Cons:**
- Related widgets can be viewed together
- Reduces number of files in project
- Simpler for small, tightly coupled widgets

**Note:** State classes are NOT counted as separate widgets since they must be in the same file as their StatefulWidget.

### Example

```dart
// BAD (with this rule enabled):
// my_widgets.dart
class MyButton extends StatelessWidget { ... }
class MyCard extends StatelessWidget { ... }  // Second widget triggers warning

// GOOD:
// my_button.dart
class MyButton extends StatelessWidget { ... }

// my_card.dart (separate file)
class MyCard extends StatelessWidget { ... }
```

---

## prefer_arrow_functions

Use arrow syntax (`=>`) for functions that contain only a return statement.

**Pros:**
- More concise and readable for simple returns
- Signals that function is a pure expression
- Consistent with functional programming style

**Cons:**
- Block bodies are more explicit
- Easier to add debug statements later
- Consistent formatting regardless of complexity

### Example

```dart
// BAD (with this rule enabled):
int double(int x) {
  return x * 2;
}

// GOOD:
int double(int x) => x * 2;
```

**Quick fix available:** Converts to arrow function automatically.

---

## prefer_all_named_parameters

Use named parameters when a function has 3 or more positional parameters.

**Pros:**
- Self-documenting call sites
- Order-independent arguments
- Easier to add optional parameters later

**Cons:**
- More verbose call sites
- Overkill for simple 2-3 param functions
- Familiar positional style from other languages

**Note:** Excludes `main()`, operators, and `@override` methods.

### Example

```dart
// BAD (with this rule enabled):
void createUser(String name, String email, int age, bool isAdmin) { ... }

// Call site is unclear:
createUser('John', 'john@example.com', 30, true);

// GOOD:
void createUser({
  required String name,
  required String email,
  required int age,
  required bool isAdmin,
}) { ... }

// Call site is self-documenting:
createUser(name: 'John', email: 'john@example.com', age: 30, isAdmin: true);
```

---

## prefer_trailing_comma_always

Trailing commas on all multi-line constructs for cleaner git diffs.

**Pros:**
- Cleaner git diffs (single line changes)
- Easier to reorder arguments
- Consistent formatting with `dart format`

**Cons:**
- Visual noise at end of lines
- Different from most other languages
- May feel redundant

### Example

```dart
// BAD (with this rule enabled):
Widget build() {
  return Container(
    child: Column(
      children: [
        Text('Hello'),
        Text('World')  // Missing trailing comma
      ]  // Missing trailing comma
    )  // Missing trailing comma
  );  // Missing trailing comma
}

// GOOD:
Widget build() {
  return Container(
    child: Column(
      children: [
        Text('Hello'),
        Text('World'),
      ],
    ),
  );
}
```

**Quick fix available:** Adds trailing comma automatically.

---

## prefer_private_underscore_prefix

All instance fields should be private (prefixed with underscore).

**Pros:**
- Encapsulation by default
- Clear distinction between public API and internal state
- Forces explicit getter/setter decisions

**Cons:**
- More boilerplate for simple data classes
- Dart already has library privacy without underscore
- Record types make plain fields common

**Note:** Excludes widget properties, State class fields, and documented fields.

### Example

```dart
// BAD (with this rule enabled):
class MyClass {
  String name;  // Public field triggers warning
}

// GOOD:
class MyClass {
  String _name;  // Private field

  String get name => _name;  // Public getter if needed
}
```

---

## prefer_widget_methods_over_classes

Simple private widgets could be build methods instead of separate classes.

**Pros:**
- Less boilerplate code
- Simpler for very small UI pieces
- Access to parent widget state without passing

**Cons:**
- Widget classes enable better rebuild optimization
- Easier to add const constructors
- Better separation of concerns
- More testable in isolation

**Note:** Only flags private StatelessWidgets with simple build methods (5 lines or fewer). Complex widgets with fields or multiple methods are not flagged.

### Example

```dart
// BAD (with this rule enabled):
class _MyIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Icon(Icons.star, color: Colors.yellow);
  }
}

// GOOD (as a method in parent widget):
Widget _buildIcon() {
  return Icon(Icons.star, color: Colors.yellow);
}
```

---

## prefer_explicit_types

Use explicit type annotations instead of `var`, `final` (without type), or `dynamic`.

**Pros:**
- Clear intent and documentation
- Catches type mismatches at declaration
- Easier to read in code reviews

**Cons:**
- More verbose
- Dart's type inference is excellent
- Redundant when type is obvious from initializer

### Example

```dart
// BAD (with this rule enabled):
var name = 'John';
final count = 42;
dynamic items = <String>[];

// GOOD:
String name = 'John';
final int count = 42;
List<String> items = <String>[];
```

---

## prefer_class_over_record_return

Return dedicated classes instead of records from methods.

**Pros:**
- Named fields are self-documenting
- Can add methods and validation
- Better IDE support and refactoring
- Can implement interfaces

**Cons:**
- Records are more concise
- Good for simple data transfer
- No boilerplate needed
- Pattern matching support

### Example

```dart
// BAD (with this rule enabled):
(String name, int age) getUser() {
  return ('John', 30);
}

({String name, int age}) getUserNamed() {
  return (name: 'John', age: 30);
}

// GOOD:
class User {
  final String name;
  final int age;
  User(this.name, this.age);
}

User getUser() {
  return User('John', 30);
}
```

---

## prefer_inline_callbacks

Inline callbacks instead of referencing extracted methods.

**Pros:**
- Behavior is visible where it's used
- No need to search for method definition
- Simpler for one-off handlers

**Cons:**
- Reusable across multiple widgets
- Easier to test in isolation
- Keeps build methods shorter
- Can have descriptive method names

### Example

```dart
// BAD (with this rule enabled):
class MyWidget extends StatelessWidget {
  void _onPressed() {
    print('pressed');
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _onPressed,  // Method reference triggers warning
      child: Text('Press me'),
    );
  }
}

// GOOD:
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        print('pressed');
      },
      child: Text('Press me'),
    );
  }
}
```

---

## prefer_single_quotes

Use single quotes instead of double quotes for strings.

**Pros:**
- Dart style guide recommends single quotes
- Fewer keystrokes (no shift key needed)
- Consistent with many Dart codebases

**Cons:**
- Familiar from other languages (Java, JavaScript)
- Easier to include apostrophes in strings
- JSON uses double quotes

### Example

```dart
// BAD (with this rule enabled):
String name = "John";
String message = "Hello, World!";

// GOOD:
String name = 'John';
String message = 'Hello, World!';
```

**Quick fix available:** Converts to single quotes automatically.

---

## prefer_todo_format

TODO comments should follow the format: `TODO(author): description`

**Pros:**
- Easy to track who added the TODO
- Searchable by author
- Consistent across codebase

**Cons:**
- Git blame already shows author
- Extra typing
- Author may leave the team

### Example

```dart
// BAD (with this rule enabled):
// TODO: fix this later
// TODO fix this
// todo: implement feature

// GOOD:
// TODO(john): fix this later
// TODO(jane): implement feature
```

---

## prefer_fixme_format

FIXME comments should follow the format: `FIXME(author): description`

**Pros:**
- Easy to track who added the FIXME
- Searchable by author
- Consistent with TODO format

**Cons:**
- Git blame already shows author
- Extra typing

### Example

```dart
// BAD (with this rule enabled):
// FIXME: this is broken
// FIXME fix the bug

// GOOD:
// FIXME(john): this is broken
// FIXME(jane): handle edge case
```

---

## prefer_sentence_case_comments

Comments should start with a capital letter.

**Pros:**
- More professional appearance
- Consistent with documentation standards
- Easier to read

**Cons:**
- Extra effort for quick notes
- May conflict with code references (e.g., `// userId is required`)

**Note:** Skips special markers (TODO, FIXME, NOTE, etc.) and code references.

### Example

```dart
// BAD (with this rule enabled):
// calculate the total
// this is a helper function

// GOOD:
// Calculate the total
// This is a helper function
```

**Quick fix available:** Capitalizes the first letter automatically.

---

## prefer_period_after_doc

Doc comments should end with a period.

**Pros:**
- Complete sentences are easier to read
- Professional documentation style
- Consistent with Dart documentation guidelines

**Cons:**
- Extra typing for simple docs
- May feel redundant for short descriptions

### Example

```dart
// BAD (with this rule enabled):
/// Returns the user's name
String getName() => name;

// GOOD:
/// Returns the user's name.
String getName() => name;
```

**Quick fix available:** Adds period automatically.

---

## prefer_screaming_case_constants

Constants should use `SCREAMING_SNAKE_CASE` naming.

**Pros:**
- Immediately identifiable as constants
- Traditional style from C/Java
- Clear distinction from variables

**Cons:**
- Dart style guide prefers `lowerCamelCase` for constants
- Less "shouty" in code
- Consistent with other Dart naming

### Example

```dart
// BAD (with this rule enabled):
const int maxRetries = 3;
const String apiVersion = 'v1';

// GOOD:
const int MAX_RETRIES = 3;
const String API_VERSION = 'v1';
```

**Quick fix available:** Converts to SCREAMING_SNAKE_CASE automatically.

---

## prefer_descriptive_bool_names

Boolean variables should use descriptive prefixes like `is`, `has`, `can`, `should`.

**Pros:**
- Self-documenting code
- Clear intent at usage site
- Reads naturally in conditions

**Cons:**
- Can be verbose for obvious cases
- Some booleans don't fit these patterns naturally

**Note:** Allows common standalone names like `enabled`, `visible`, `loading`, etc.

### Example

```dart
// BAD (with this rule enabled):
bool loading = true;
bool visible = false;
void setEnabled(bool enabled) { ... }

// GOOD:
bool isLoading = true;
bool isVisible = false;
void setEnabled(bool isEnabled) { ... }
```

---

## prefer_snake_case_files

Dart file names should use `snake_case`.

**Pros:**
- Dart style guide recommends snake_case
- Consistent across the Dart ecosystem
- Case-insensitive file systems handle better

**Cons:**
- Some prefer PascalCase to match class names
- Habit from other languages

### Example

```
BAD (with this rule enabled):
UserService.dart
user-service.dart
userService.dart

GOOD:
user_service.dart
```

---

## avoid_small_text

Font size should be at least 12 logical pixels for accessibility.

**Pros:**
- Better accessibility for all users
- WCAG compliance
- Easier reading on all devices

**Cons:**
- Design requirements may need smaller text
- Captions and legal text often need smaller sizes

### Example

```dart
// BAD (with this rule enabled):
Text('Small', style: TextStyle(fontSize: 10));

// GOOD:
Text('Readable', style: TextStyle(fontSize: 14));
```

**Quick fix available:** Changes font size to 12 automatically.

---

## prefer_doc_comments_over_regular

Use doc comments (`///`) instead of regular comments (`//`) for public API documentation.

**Pros:**
- Show up in IDE hover documentation
- Can be extracted by dartdoc
- Clearly mark API documentation

**Cons:**
- Less formal for internal notes
- Doc comments may feel heavy for simple members

### Example

```dart
// BAD (with this rule enabled):
// Returns the user's full name.
String getFullName() => '$firstName $lastName';

// GOOD:
/// Returns the user's full name.
String getFullName() => '$firstName $lastName';
```

**Quick fix available:** Converts `//` to `///` automatically.

---

## Opposing Rules

Some stylistic rules have valid opposites. Pick what fits your team:

| If you prefer... | Enable... | Instead of... |
|------------------|-----------|---------------|
| Relative imports | `prefer_relative_imports` | Absolute imports |
| Absolute imports | (no rule yet) | `prefer_relative_imports` |
| Arrow functions | `prefer_arrow_functions` | Block bodies |
| Block bodies | (no rule yet) | `prefer_arrow_functions` |
| Inline callbacks | `prefer_inline_callbacks` | Extracted methods |
| Extracted methods | (no rule yet) | `prefer_inline_callbacks` |

See [ROADMAP.md](https://github.com/saropa/saropa_lints/blob/main/ROADMAP.md) for planned opposing rules.

---

## About This Document

> "Code is read more often than it is written." — Guido van Rossum

> "Any fool can write code that a computer can understand. Good programmers write code that humans can understand." — Martin Fowler

**Stylistic rules** enforce team conventions that have no objectively correct answer. Quote styles, trailing commas, import ordering — these are preferences, not bugs. But consistency matters: it reduces cognitive load during code review, speeds up onboarding, and prevents style debates from derailing productive discussions.

Enable these rules based on your team's consensus. Document your choices. Move on to the work that matters.

**Keywords:** Dart code style, Flutter formatting rules, trailing commas, single quotes vs double quotes, relative imports, explicit types, arrow functions, naming conventions, code consistency, team style guide, Dart linter configuration

**Hashtags:** #Flutter #Dart #CodeStyle #CleanCode #FlutterDev #DartLang #StyleGuide #CodingStandards #TeamConventions #BestPractices

---

## Sources

- **Effective Dart: Style** — Official Dart style recommendations
  https://dart.dev/effective-dart/style

- **Dart Formatting** — dart format tool documentation
  https://dart.dev/tools/dart-format

- **Flutter Style Guide** — Flutter team's style conventions
  https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo

- **Google Dart Style Guide** — Google's internal Dart conventions
  https://google.github.io/styleguide/

- **Effective Dart: Documentation** — Documentation best practices
  https://dart.dev/effective-dart/documentation

- **Dart Language Tour** — Language features reference
  https://dart.dev/language
