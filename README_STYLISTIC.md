<!-- cspell:ignore edgeinsets borderradius ifnull addall wheretype wherecast asmap catcherror richtext sizedbox -->
# Stylistic Rules

Stylistic rules represent team preferences where there's no objectively "correct" answer.

## Two Ways to Enable Stylistic Rules

### Option 1: Include Stylistic Rules with CLI Tool

```bash
# Generate config with stylistic rules included
dart run saropa_lints:init --tier comprehensive --stylistic
```

This enables the 35 non-conflicting stylistic rules like `enforce_member_ordering`, `prefer_trailing_comma_always`, and `prefer_arrow_functions`.

### Option 2: Enable Individual Rules

After generating your base configuration, edit `analysis_options.yaml` to enable specific stylistic rules:

```yaml
# analysis_options.yaml
custom_lint:
  rules:
    # Enable specific stylistic rules your team prefers
    - prefer_single_quotes: true      # OR prefer_double_quotes
    - prefer_relative_imports: true   # OR prefer_absolute_imports
```

**Conflicting pairs** (e.g., `prefer_single_quotes` vs `prefer_double_quotes`) are NOT auto-enabled. You must explicitly enable one of the pair.

---

## All Stylistic Rules Reference

This document lists **all** stylistic rules organized into 7 categories:

- [General Stylistic Rules](#general-stylistic-rules)
- [Widget Preferences](#widget-preferences)
- [Null & Collection Handling](#null--collection-handling)
- [Control Flow & Async](#control-flow--async)
- [Whitespace & Constructors](#whitespace--constructors)
- [Error Handling & Testing](#error-handling--testing)
- [Additional Style Rules](#additional-style-rules)

---

## General Stylistic Rules

Core stylistic preferences for imports, functions, formatting, naming, and comments.

| Rule | Description | Quick Fix |
|------|-------------|:---------:|
| [`prefer_relative_imports`](#prefer_relative_imports) | Use relative imports instead of absolute `package:` imports | Yes |
| [`prefer_one_widget_per_file`](#prefer_one_widget_per_file) | One widget class per file | |
| [`prefer_arrow_functions`](#prefer_arrow_functions) | Use `=>` arrow syntax for single-return functions | Yes |
| [`prefer_all_named_parameters`](#prefer_all_named_parameters) | Use named parameters when 3+ positional params | |
| [`prefer_trailing_comma_always`](#prefer_trailing_comma_always) | Trailing commas on all multi-line constructs | Yes |
| [`prefer_private_underscore_prefix`](#prefer_private_underscore_prefix) | All instance fields should be private (`_name`) | |
| [`prefer_widget_methods_over_classes`](#prefer_widget_methods_over_classes) | Small widgets as methods instead of classes | |
| [`prefer_class_over_record_return`](#prefer_class_over_record_return) | Return classes instead of records from methods | |
| [`prefer_inline_callbacks`](#prefer_inline_callbacks) | Inline callbacks instead of method references | |
| [`prefer_single_quotes`](#prefer_single_quotes) | Single quotes `'string'` instead of double quotes | Yes |
| [`prefer_todo_format`](#prefer_todo_format) | TODOs follow `TODO(author): description` format | |
| [`prefer_fixme_format`](#prefer_fixme_format) | FIXMEs follow `FIXME(author): description` format | |
| [`prefer_sentence_case_comments`](#prefer_sentence_case_comments) | Comments start with capital letter | Yes |
| [`prefer_period_after_doc`](#prefer_period_after_doc) | Doc comments end with period | Yes |
| [`prefer_screaming_case_constants`](#prefer_screaming_case_constants) | Constants in `SCREAMING_SNAKE_CASE` | Yes |
| [`prefer_descriptive_bool_names`](#prefer_descriptive_bool_names) | Booleans use `is`/`has`/`can` prefix | |
| [`prefer_snake_case_files`](#prefer_snake_case_files) | File names in `snake_case.dart` | |
| [`avoid_small_text`](#avoid_small_text) | Font size at least 12 for accessibility | Yes |
| [`prefer_doc_comments_over_regular`](#prefer_doc_comments_over_regular) | Use `///` instead of `//` for public API docs | Yes |
| [`prefer_straight_apostrophe`](#prefer_straight_apostrophe) | Straight apostrophe `'` in strings | Yes |
| [`prefer_curly_apostrophe`](#prefer_curly_apostrophe) | Curly apostrophe `'` in strings | Yes |
| [`prefer_doc_curly_apostrophe`](#prefer_doc_curly_apostrophe) | Curly apostrophe `'` in doc comments | Yes |
| [`prefer_doc_straight_apostrophe`](#prefer_doc_straight_apostrophe) | Straight apostrophe `'` in doc comments | Yes |
| [`arguments_ordering`](#arguments_ordering) | Named arguments should be in alphabetical order | Yes |
| [`capitalize_comment`](#capitalize_comment) | Comments should start with a capital letter | Yes |
| [`firebase_custom`](#firebase_custom) | Custom Firebase usage should follow team conventions | |
| [`avoid_generic_greeting_text`](#avoid_generic_greeting_text) | Greeting messages should follow team style conventions | |
| [`prefer_kebab_tag_name`](#prefer_kebab_tag_name) | Tag names should use kebab-case | |
| [`prefer_rethrow_over_throw_e`](#prefer_rethrow_over_throw_e) | Prefer 'rethrow' over 'throw e' in catch blocks | |
| [`prefer_sorted_members`](#prefer_sorted_members) | Class members should be sorted by team convention | |
| [`prefer_sorted_parameters`](#prefer_sorted_parameters) | Function parameters should be sorted by team convention | |
| [`require_purchase_verification`](#require_purchase_verification) | Purchase logic should follow team style conventions | |
| [`purchase_completed`](#purchase_completed) | Purchase completion logic should follow team style conventions | |
| [`require_save_confirmation`](#require_save_confirmation) | Save logic should follow team style conventions | |
| [`user_clicked_button`](#user_clicked_button) | Button click logic should follow team style conventions | |

---

## Widget Preferences

Preferences for Flutter widget patterns. Many come in opposing pairs — choose the one that fits your team.

| Rule | Description | Opposing Rule |
|------|-------------|---------------|
| `prefer_sizedbox_over_container` | Use SizedBox for simple sizing | `prefer_container_over_sizedbox` |
| `prefer_container_over_sizedbox` | Prefer Container for consistency | `prefer_sizedbox_over_container` |
| `prefer_text_rich_over_richtext` | Use Text.rich over RichText widget | `prefer_richtext_over_text_rich` |
| `prefer_richtext_over_text_rich` | Use RichText over Text.rich | `prefer_text_rich_over_richtext` |
| `prefer_edgeinsets_symmetric` | Use EdgeInsets.symmetric when applicable | `prefer_edgeinsets_only` |
| `prefer_edgeinsets_only` | Use EdgeInsets.only for explicit values | `prefer_edgeinsets_symmetric` |
| `prefer_borderradius_circular` | Use BorderRadius.circular for uniform corners | |
| `prefer_expanded_over_flexible` | Use Expanded instead of Flexible(flex: 1) | `prefer_flexible_over_expanded` |
| `prefer_flexible_over_expanded` | Prefer Flexible for explicit control | `prefer_expanded_over_flexible` |
| `prefer_material_theme_colors` | Use Theme.of(context) colors | `prefer_explicit_colors` |
| `prefer_explicit_colors` | Use explicit color values | `prefer_material_theme_colors` |

### Example: SizedBox vs Container

```dart
// prefer_sizedbox_over_container
SizedBox(width: 100, height: 50)  // Preferred

// prefer_container_over_sizedbox
Container(width: 100, height: 50)  // Preferred
```

---

## Null & Collection Handling

Preferences for null-aware operators and collection manipulation patterns.

| Rule | Description | Opposing Rule |
|------|-------------|---------------|
| `prefer_addall_over_spread` | Use addAll method | `prefer_spread_over_addall` |
| `prefer_spread_over_addall` | Use `...` spread operator | `prefer_addall_over_spread` |

### Example: Cascade vs Multiple Calls

```dart
list
  ..add(1)
  ..add(2)
  ..add(3);

list.add(1);
list.add(2);
list.add(3);
```

---

## Control Flow & Async

Preferences for control flow patterns, guard clauses, and async/await style.

| Rule | Description | Opposing Rule |
|------|-------------|---------------|
| `prefer_switch_expression` | Use switch expressions (Dart 3) | `prefer_switch_statement` |
| `prefer_switch_statement` | Use switch statements | `prefer_switch_expression` |

### Example: Early Return vs Single Exit

```dart
// prefer_early_return
void process(User? user) {
  if (user == null) return;
  if (!user.isActive) return;
  // main logic here
}

void process(User? user) {
  if (user != null && user.isActive) {
    // main logic here
  }
}
```

---

## Whitespace & Constructors

Preferences for blank lines, member ordering, and constructor patterns.

| Rule | Description | Opposing Rule |
|------|-------------|---------------|
| `prefer_blank_line_before_return` | Blank line before return statements | `prefer_no_blank_line_before_return` |
| `prefer_no_blank_line_before_return` | No blank line before return | `prefer_blank_line_before_return` |

### Example: Initializing Formals

```dart
// prefer_initializing_formals
class User {
  final String name;
  User(this.name);
}

class User {
  final String name;
  User(String name) : name = name;
}
```

---

## Error Handling & Testing

Preferences for exception handling patterns and test organization.

| Rule | Description | Opposing Rule |
|------|-------------|---------------|
| `prefer_specific_exceptions` | Throw specific exception types | `prefer_generic_exception` |
| `prefer_generic_exception` | Use generic Exception class | `prefer_specific_exceptions` |
| `prefer_exception_suffix` | Exception classes end with "Exception" | `prefer_error_suffix` |
| `prefer_error_suffix` | Exception classes end with "Error" | `prefer_exception_suffix` |
| `prefer_on_over_catch` | Use `on ExceptionType` in try-catch | `prefer_catch_over_on` |
| `prefer_catch_over_on` | Use bare `catch (e)` | `prefer_on_over_catch` |
| `prefer_given_when_then_comments` | Use AAA/GWT comments in tests | `prefer_self_documenting_tests` |
| `prefer_self_documenting_tests` | No structure comments in tests | `prefer_given_when_then_comments` |
| `prefer_expect_over_assert_in_tests` | Use expect() instead of assert() | |
| `prefer_single_expectation_per_test` | One assertion per test | `prefer_grouped_expectations` |
| `prefer_grouped_expectations` | Group related assertions | `prefer_single_expectation_per_test` |
| `prefer_test_name_should_when` | Test names: "should X when Y" | `prefer_test_name_descriptive` |
| `prefer_test_name_descriptive` | Descriptive test names | `prefer_test_name_should_when` |

### Example: Test Structure Comments

```dart
// prefer_given_when_then_comments
test('user login', () {
  // Arrange
  final user = User('test@example.com');

  // Act
  final result = authService.login(user);

  // Assert
  expect(result.isSuccess, true);
});

// prefer_self_documenting_tests
test('user login', () {
  final user = User('test@example.com');
  final result = authService.login(user);
  expect(result.isSuccess, true);
});
```

---

## Additional Style Rules

Additional preferences for strings, imports, class structure, types, naming, and expressions.

### String Handling

| Rule | Description | Opposing Rule |
|------|-------------|---------------|
| `prefer_interpolation_over_concatenation` | Use `'Hello, $name'` | `prefer_concatenation_over_interpolation` |
| `prefer_concatenation_over_interpolation` | Use `'Hello, ' + name` | `prefer_interpolation_over_concatenation` |
| `prefer_double_quotes` | Use double quotes for strings | `prefer_single_quotes` |

### Import Organization

| Rule | Description | Opposing Rule |
|------|-------------|---------------|
| `prefer_absolute_imports` | Use `package:` imports | `prefer_relative_imports` |
| `prefer_grouped_imports` | Group: dart, package, relative | `prefer_flat_imports` |
| `prefer_flat_imports` | No grouping, flat import list | `prefer_grouped_imports` |

### Class Structure

| Rule | Description | Opposing Rule |
|------|-------------|---------------|
| `prefer_fields_before_methods` | Fields declared before methods | `prefer_methods_before_fields` |
| `prefer_methods_before_fields` | Methods declared before fields | `prefer_fields_before_methods` |
| `prefer_static_members_first` | Static members before instance | `prefer_instance_members_first` |
| `prefer_instance_members_first` | Instance members before static | `prefer_static_members_first` |
| `prefer_public_members_first` | Public members before private | `prefer_private_members_first` |
| `prefer_private_members_first` | Private members before public | `prefer_public_members_first` |

### Type Annotations

| Rule | Description | Opposing Rule |
|------|-------------|---------------|
| `prefer_object_over_dynamic` | Use `Object?` instead of `dynamic` | `prefer_dynamic_over_object` |
| `prefer_dynamic_over_object` | Use `dynamic` for truly dynamic types | `prefer_object_over_dynamic` |

### Naming Conventions

| Rule | Description | Opposing Rule |
|------|-------------|---------------|
| `prefer_lower_camel_case_constants` | Constants: `maxRetries` | `prefer_screaming_case_constants` |
| `prefer_camel_case_method_names` | Methods: `fetchUserData` | |

### Expression Style

| Rule | Description | Opposing Rule |
|------|-------------|---------------|
| `prefer_explicit_this` | Use `this.field` for field access | |
| `prefer_implicit_boolean_comparison` | Use `if (isValid)` not `if (isValid == true)` | `prefer_explicit_boolean_comparison` |
| `prefer_explicit_boolean_comparison` | Use `if (isValid == true)` for nullable bools | `prefer_implicit_boolean_comparison` |

---

## Opposing Rules Reference

Many stylistic rules have valid opposites. This table helps you choose which rules to enable based on your team's preferences:

|--------------|--------|:--:|--------|--------------|
| Relative imports | `prefer_relative_imports` | | `prefer_absolute_imports` | Absolute imports |
| Arrow functions | `prefer_arrow_functions` | | (block bodies) | Block bodies |
| Inline callbacks | `prefer_inline_callbacks` | | (extracted methods) | Extracted methods |
| Single quotes | `prefer_single_quotes` | | `prefer_double_quotes` | Double quotes |
| SizedBox | `prefer_sizedbox_over_container` | | `prefer_container_over_sizedbox` | Container |
| Text.rich | `prefer_text_rich_over_richtext` | | `prefer_richtext_over_text_rich` | RichText |
| EdgeInsets.symmetric | `prefer_edgeinsets_symmetric` | | `prefer_edgeinsets_only` | EdgeInsets.only |
| Expanded | `prefer_expanded_over_flexible` | | `prefer_flexible_over_expanded` | Flexible |
| Theme colors | `prefer_material_theme_colors` | | `prefer_explicit_colors` | Explicit colors |
| Spread operator | `prefer_spread_over_addall` | | `prefer_addall_over_spread` | addAll |
| Switch expressions | `prefer_switch_expression` | | `prefer_switch_statement` | Switch statements |
| Blank before return | `prefer_blank_line_before_return` | | `prefer_no_blank_line_before_return` | No blank |
| Spaced declarations | `prefer_blank_line_after_declarations` | | `prefer_compact_declarations` | Compact |
// ...existing code...
| AAA comments | `prefer_given_when_then_comments` | | `prefer_self_documenting_tests` | No comments |
| Single assertion | `prefer_single_expectation_per_test` | | `prefer_grouped_expectations` | Grouped |
| should/when names | `prefer_test_name_should_when` | | `prefer_test_name_descriptive` | Descriptive |
| Interpolation | `prefer_interpolation_over_concatenation` | | `prefer_concatenation_over_interpolation` | Concatenation |
| Grouped imports | `prefer_grouped_imports` | | `prefer_flat_imports` | Flat imports |
| Fields first | `prefer_fields_before_methods` | | `prefer_methods_before_fields` | Methods first |
| Static first | `prefer_static_members_first` | | `prefer_instance_members_first` | Instance first |
| Public first | `prefer_public_members_first` | | `prefer_private_members_first` | Private first |
| Object? | `prefer_object_over_dynamic` | | `prefer_dynamic_over_object` | dynamic |
| lowerCamel constants | `prefer_lower_camel_case_constants` | | `prefer_screaming_case_constants` | SCREAMING_CASE |
| Implicit bool | `prefer_implicit_boolean_comparison` | | `prefer_explicit_boolean_comparison` | Explicit bool |

---

## Detailed Rule Documentation

### prefer_relative_imports

Use relative imports instead of absolute `package:` imports for files within the same package.

**Pros:**
- Shorter import paths
- Easier refactoring when moving directories
- Clear indication of local dependencies

**Cons:**
- Absolute paths are more explicit
- Easier to understand file location at a glance
- IDEs may auto-generate absolute imports

```dart
// BAD (with this rule enabled):
import 'package:my_app/src/utils/helpers.dart';

// GOOD:
import '../utils/helpers.dart';
```

**Quick fix available:** Converts to relative import automatically.

---

### prefer_one_widget_per_file

One widget class per file for easier navigation and searchability.

**Note:** State classes are NOT counted as separate widgets since they must be in the same file as their StatefulWidget.

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

### prefer_arrow_functions

Use arrow syntax (`=>`) for functions that contain only a return statement.

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

### prefer_all_named_parameters

Use named parameters when a function has 3 or more positional parameters.

**Note:** Excludes `main()`, operators, and `@override` methods.

```dart
// BAD (with this rule enabled):
void createUser(String name, String email, int age, bool isAdmin) { ... }
createUser('John', 'john@example.com', 30, true);  // Unclear

// GOOD:
void createUser({
  required String name,
  required String email,
  required int age,
  required bool isAdmin,
}) { ... }
createUser(name: 'John', email: 'john@example.com', age: 30, isAdmin: true);
```

---

### prefer_trailing_comma_always

Trailing commas on all multi-line constructs for cleaner git diffs.

```dart
// BAD (with this rule enabled):
return Container(
  child: Text('Hello')  // Missing trailing comma
);

// GOOD:
return Container(
  child: Text('Hello'),
);
```

**Quick fix available:** Adds trailing comma automatically.

---

### prefer_single_quotes

Use single quotes instead of double quotes for strings.

```dart
// BAD (with this rule enabled):
String name = "John";

// GOOD:
String name = 'John';
```

**Quick fix available:** Converts to single quotes automatically.

---

### prefer_screaming_case_constants

Constants should use `SCREAMING_SNAKE_CASE` naming.

```dart
// BAD (with this rule enabled):
const int maxRetries = 3;

// GOOD:
const int MAX_RETRIES = 3;
```

**Quick fix available:** Converts to SCREAMING_SNAKE_CASE automatically.

---

### prefer_descriptive_bool_names

Boolean variables should use descriptive prefixes like `is`, `has`, `can`, `should`.

**Note:** Allows common standalone names like `enabled`, `visible`, `loading`, etc.

```dart
// BAD (with this rule enabled):
bool admin = true;

// GOOD:
bool isAdmin = true;
bool hasPermission = true;
bool canEdit = true;
```

---

### avoid_small_text

Font size should be at least 12 logical pixels for accessibility.

```dart
// BAD (with this rule enabled):
Text('Small', style: TextStyle(fontSize: 10));

// GOOD:
Text('Readable', style: TextStyle(fontSize: 14));
```

**Quick fix available:** Changes font size to 12 automatically.

---

### prefer_straight_apostrophe

Use straight ASCII apostrophe (`'` U+0027) instead of curly apostrophe in string literals.

```dart
// BAD (with this rule enabled):
String message = "It's a beautiful day";  // Curly apostrophe U+2019

// GOOD:
String message = "It's a beautiful day";  // Straight apostrophe U+0027
```

**Opposing rule:** `prefer_curly_apostrophe`

**Quick fix available:** Replaces curly apostrophes with straight apostrophes.

---

### prefer_curly_apostrophe

Use curly apostrophe (`'` U+2019) instead of straight apostrophe in string literals for better typography.

```dart
// BAD (with this rule enabled):
String message = "It's a beautiful day";  // Straight apostrophe U+0027

// GOOD:
String message = "It's a beautiful day";  // Curly apostrophe U+2019
```

**Opposing rule:** `prefer_straight_apostrophe`

**Quick fix available:** Replaces straight apostrophes with curly apostrophes in contractions.

---

### prefer_doc_curly_apostrophe

Use curly apostrophe (`'` U+2019) in documentation comments for better typography.

```dart
// BAD (with this rule enabled):
/// It's a beautiful day.  // Straight apostrophe

// GOOD:
/// It's a beautiful day.  // Curly apostrophe
```

**Opposing rule:** `prefer_doc_straight_apostrophe`

**Quick fix available:** Replaces straight apostrophes with curly apostrophes in doc comments.

---

### prefer_doc_straight_apostrophe

Use straight ASCII apostrophe (`'` U+0027) in documentation comments for consistency with code.

```dart
// BAD (with this rule enabled):
/// It's a beautiful day.  // Curly apostrophe U+2019

// GOOD:
/// It's a beautiful day.  // Straight apostrophe U+0027
```

**Opposing rule:** `prefer_doc_curly_apostrophe`

**Quick fix available:** Replaces curly apostrophes with straight apostrophes in doc comments.

---
<!-- cspell:ignore Rossum -->
## About This Document

> "Code is read more often than it is written." — Guido van Rossum

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

---

> "Any fool can write code that a computer can understand. Good programmers write code that humans can understand." — Martin Fowler
