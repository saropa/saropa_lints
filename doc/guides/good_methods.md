# What Makes a Good Method (and a Bad One)

A practical guide to writing methods that are clear, maintainable, and reliable. Use this for code reviews, refactors, and day-to-day implementation. Projects using **saropa_lints** can enforce many of these practices automatically; the rest stay in the guide and in code review.

---

## Table of contents

1. [Single responsibility](#1-single-responsibility)
2. [Naming](#2-naming)
3. [Length and complexity](#3-length-and-complexity)
4. [Parameters](#4-parameters)
5. [Documentation](#5-documentation)
6. [Validation and defensiveness](#6-validation-and-defensiveness)
7. [Return values and side effects](#7-return-values-and-side-effects)
8. [Testability](#8-testability)
9. [Formatting and readability](#9-formatting-and-readability)
10. [Inline comments: variables, parameters, branches, loops](#10-inline-comments-variables-parameters-branches-loops)
11. [Summary checklist](#11-summary-checklist)
12. [Appendix A: Rules enforced by saropa_lints](#12-appendix-a-rules-enforced-by-saropa_lints)
13. [Appendix B: Rules not enforced — manual review](#13-appendix-b-rules-not-enforced--manual-review)

---

## Quick reference: which rules to enable

To enforce good methods with saropa_lints:

**1. Use the Professional tier** (or explicitly enable these five rules). These must be **on**:

| Rule | Purpose |
|------|--------|
| `require_public_api_documentation` | Public API has doc comments. |
| `require_parameter_documentation` | Public method parameters are documented. |
| `require_return_documentation` | Non-void methods document return value. |
| `require_exception_documentation` | Throwing methods document exceptions. |
| `require_complex_logic_comments` | Complex methods have explanatory comments. |

**2. Turn on these stylistic rules** in your `analysis_options.yaml` (or stylistic overrides):

**Comments and documentation**

| Rule | Purpose |
|------|--------|
| `prefer_doc_comments_over_regular` | Use `///` for public API docs. |
| `prefer_period_after_doc` | Doc sentences end with a period. |
| `prefer_sentence_case_comments` **or** `prefer_sentence_case_comments_relaxed` **or** `prefer_capitalized_comment_start` | Comments start with a capital letter. (Use **one** of these; they overlap.) |
| `prefer_todo_format` | TODOs use `TODO(author): description`. |
| `prefer_fixme_format` | FIXMEs use `FIXME(author): description`. |
| `prefer_no_commented_out_code` | Remove commented-out code. |

**Spacing and layout**

| Rule | Purpose |
|------|--------|
| `prefer_blank_line_before_method` | Blank line before each method. |
| `prefer_blank_lines_between_members` | Blank line between class members. |
| `prefer_blank_line_before_constructor` | Blank line before constructors. |
| `prefer_blank_line_before_case` | Blank line before `switch` cases. |
| `prefer_blank_line_before_return` | Blank line before `return`. |
| `prefer_blank_line_before_else` | Blank line before standalone `else`. |
| `prefer_blank_line_after_loop` | Blank line after a for/while loop before the next statement. |
| `prefer_blank_line_after_declarations` | Blank line after variable declarations (separates setup from logic). |
| `prefer_single_blank_line_max` | At most one consecutive blank line. |

**Line breaks between branches and loops:** We have coverage for: **blank line before return** (`prefer_blank_line_before_return`), **blank line before else** (`prefer_blank_line_before_else`), and **blank line after loop** (`prefer_blank_line_after_loop`).

**3. Turn off (or leave off) rules that conflict with good-methods style**

| Rule | Why |
|------|-----|
| `prefer_compact_class_members` | Conflicts with `prefer_blank_lines_between_members`. Keep **off** if you use `prefer_blank_lines_between_members`. |
| `prefer_no_blank_line_before_return` | Opposite of good methods: it *removes* blank before return. Keep **off** so `prefer_blank_line_before_return` can enforce the desired style. |
| `prefer_no_blank_line_inside_blocks` | Flags blank lines at the very start or end of a block body. Keep **off** if you want that spacing inside blocks. |

No other saropa_lints rules need to be turned off specifically for good methods. Use your normal tier (Essential / Recommended / Professional) and add the stylistic rules above.

---

## 1. Single responsibility

A good method does **one thing** and does it well. If you need "and" to describe it, split it.

### Good

```dart
/// Persists the current user id to platform storage.
Future<void> saveCurrentUserId(String id) async {
  if (id.trim().isEmpty) throw ArgumentError('id must be non-empty');
  await _prefs.setString(_keyCurrentUserId, id);
}

/// Loads the current user id from platform storage; returns empty string if unset.
Future<String> loadCurrentUserId() async {
  return _prefs.getString(_keyCurrentUserId) ?? '';
}
```

Each method has one job: save or load. No mixing.

### Bad

```dart
/// Saves the user id and then loads it back and updates the UI and logs.
Future<String> saveAndReloadUserId(String id) async {
  await _prefs.setString(_keyCurrentUserId, id);
  final loaded = _prefs.getString(_keyCurrentUserId) ?? '';
  ref.read(currentUserIdProvider.notifier).state = loaded;
  AppLogger.info('User id updated to $loaded');
  return loaded;
}
```

This method **saves**, **loads**, **updates state**, and **logs**. Four responsibilities. Split into save, load, and callers that update state and log.

---

## 2. Naming

Names should be **verb + noun** (or verb phrase), match the domain, and not lie about what the method does.

### Good

```dart
/// Returns the number of active entries for the given [userId].
int countActiveEntries(String userId) { ... }

/// Scrolls the list to show the newest entry (index 0).
void scrollToNewestEntry() { ... }

/// True if the user has already seen the onboarding content for [version].
bool hasSeenOnboardingForVersion(String version) { ... }
```

Clear, specific, and accurate.

### Bad

```dart
int getData(String id) { ... }           // "Data" is vague; "get" doesn't say what kind of get.
void doStuff() { ... }                   // No information.
bool check(String v) { ... }             // Check what? Parameter name unclear.
void handlePress() { ... }               // "Handle" is vague; prefer "onSubmit", "saveDraft", etc.
```

Rename so that the name alone tells you what the method does and for what inputs.

---

## 3. Length and complexity

Short methods are easier to read, test, and change. Aim for a **single level of abstraction** and avoid deep nesting.

### Good

```dart
/// Builds the list of nav destinations (Home, Settings, Profile, About).
List<NavDestination> _destinations(BuildContext context) {
  final l10n = context.l10n;
  return [
    NavDestination(icon: Icons.home, label: l10n.navHome),
    NavDestination(icon: Icons.settings, label: l10n.navSettings),
    // ...
  ];
}
```

One job, flat structure, fits on one screen.

### Bad

```dart
void process() {
  if (x != null) {
    if (y != null) {
      for (var i = 0; i < items.length; i++) {
        if (items[i].active) {
          final data = fetch(items[i].id);
          if (data != null) {
            if (validate(data)) {
              save(data);
              notify();
              if (config.logging) log(data);
            }
          }
        }
      }
    }
  }
}
```

Too long, too nested, and doing many things. Extract helpers and use early returns or guards to flatten.

---

## 4. Parameters

Fewer parameters are easier to use and less error-prone. Make types and contracts explicit; validate when it matters.

### Good

```dart
/// Adds an entry with [body] to the stream for [userId].
/// Throws if [body] is empty or [userId] is invalid.
Future<void> addEntry(String body, String userId) async {
  if (body.trim().isEmpty) throw ArgumentError('body must be non-empty');
  if (userId.trim().isEmpty) throw ArgumentError('userId must be non-empty');
  // ...
}
```

Two parameters, clear names, validation at the boundary.

### Bad

```dart
Future<void> add(String a, String b, bool c, int d, String e) async { ... }
```

Unclear what `a`, `b`, `c`, `d`, `e` are. Use named parameters and descriptive names:

```dart
Future<void> addEntry({
  required String body,
  required String userId,
  bool notify = true,
  int position = 0,
  String? source,
}) async { ... }
```

### Rule of thumb

- **0–2 parameters**: usually fine as positional.
- **3+**: prefer named parameters and/or a parameter object so call sites stay readable.

---

## 5. Documentation

Public and non-obvious methods should have a **brief doc comment**: purpose, parameters, return value, and important exceptions or edge cases.

### Good

```dart
/// Returns a callback that adds a link between two entries with an unused color.
/// The callback is safe to call from the UI; errors are logged and not rethrown.
void Function(String fromId, String toId) createLinkCallback(
  WidgetRef ref,
  List<EntryLink> existingLinks,
) { ... }
```

Reader knows what they get, what to pass, and that errors are handled inside.

### Bad

```dart
void Function(String, String) createLinkCallback(WidgetRef ref, List<EntryLink> links) { ... }
```

No explanation of the two strings, return behavior, or error handling.

### What to document

- **Purpose**: what the method does in one sentence.
- **Parameters**: meaning and any constraints (e.g. non-empty, not null).
- **Return**: what is returned and in which cases (e.g. empty list vs null).
- **Throws / errors**: if it throws or reports errors in a specific way.
- **Side effects**: if it mutates state, writes to disk, or triggers UI.

Focus on **why** and **constraints**; don't repeat what the name and types already say.

---

## 6. Validation and defensiveness

Validate inputs at the **boundary** (public API, entry from UI or network). Fail fast with clear errors.

### Good

```dart
/// Parses [value] as a positive integer; returns null if invalid.
int? parsePositiveInt(String value) {
  if (value.trim().isEmpty) return null;
  final n = int.tryParse(value);
  if (n == null || n < 1) return null;
  return n;
}
```

```dart
/// Sets the display name for the user [id]. [name] must be non-empty.
Future<void> setUserName(String id, String name) async {
  if (id.trim().isEmpty) throw ArgumentError('id must be non-empty');
  if (name.trim().isEmpty) throw ArgumentError('name must be non-empty');
  await _dao.updateName(id, name);
}
```

Validation at the entry point; no silent misuse.

### Bad

```dart
int? parsePositiveInt(String value) {
  return int.tryParse(value);  // Doesn't check for empty or negative.
}
```

```dart
Future<void> setUserName(String id, String name) async {
  await _dao.updateName(id, name);  // No check; empty id/name can corrupt data.
}
```

Validate once at the boundary; internal helpers can assume valid input.

---

## 7. Return values and side effects

Prefer **one** of: return a value **or** perform a side effect. Mixing both in one method makes call sites and testing harder.

### Good

```dart
/// Computes the number of entries that will expire in the next [window].
int countExpiringIn(DateTime now, Duration window) {
  return _entries.where((e) => e.expiresAt.isBefore(now.add(window))).length;
}

/// Persists the entry and shows a snackbar on success.
Future<void> saveEntryAndNotify(Entry entry) async {
  await _repo.addEntry(entry);
  if (mounted) _showSnackBar('Saved');
}
```

First method only returns a value; second only performs side effects. Names make that clear.

### Bad

```dart
/// Saves the entry and returns the new id and also updates the badge count.
Future<String> save(Entry entry) async {
  final id = await _repo.addEntry(entry);
  _updateBadge();
  return id;
}
```

Returns a value **and** mutates global/UI state. Prefer: return the id and let the caller update the badge, or rename and document (e.g. `saveEntryAndUpdateBadge`).

---

## 8. Testability

A method is easier to test when it has **explicit inputs** (parameters, injected dependencies) and **observable outcomes** (return value, thrown exceptions, or clearly documented side effects).

### Good

```dart
/// Formats [date] for the section header; uses [locale] for month/day names.
String formatSectionDate(DateTime date, Locale locale) {
  return DateFormat.yMMM(locale.toString()).format(date);
}
```

Pure function: same `date` and `locale` always give the same string.

```dart
/// Validates [body] for entry input; returns an error message or null if valid.
String? validateEntryBody(String? body) {
  if (body == null || body.trim().isEmpty) return 'Enter some text';
  if (body.length > 10000) return 'Too long';
  return null;
}
```

No hidden state or I/O; easy to test with different strings.

### Bad

```dart
String formatSectionDate(DateTime date) {
  return DateFormat.yMMM(Platform.locale).format(date);  // Hidden dependency.
}
```

Depends on global/platform state. Prefer passing `Locale` (or a formatter) as a parameter.

```dart
void save() {
  final id = ref.read(currentUserIdProvider);  // Hidden ref/context.
  _repo.add(ref.read(someOtherProvider));      // Multiple hidden deps.
}
```

Prefer passing in the values or a small interface so tests can inject fakes.

---

## 9. Formatting and readability

Consistent **line breaks** and **comments** make methods easier to scan and understand.

### Good

```dart
/// Handles tab/screen change; logs screen open for debugging.
void _onScreenSelected(int index) {
  setState(() => _currentIndex = index);
  AppLogger.info('Screen opened: ${_screenNames[index]}');
}

// --- Share intent / extension ---

/// Called when share intent delivers one or more text snippets.
void _onSharedTexts(List<String> texts) {
  if (texts.isEmpty) return;
  unawaited(_addSharedTextsAndNotify(texts));
}
```

Blank line between methods; section comment for a group of related methods; doc comments on non-obvious behavior.

### Bad

```dart
void _onScreenSelected(int index) {
  setState(() => _currentIndex = index);
  AppLogger.info('Screen opened: ${_screenNames[index]}');
}
void _onSharedTexts(List<String> texts) {
  if (texts.isEmpty) return;
  unawaited(_addSharedTextsAndNotify(texts));
}
```

No breathing room and no explanation.

### Practices

- **Blank line** between logical blocks inside a method (e.g. after validation, before return).
- **Blank line** between methods.
- **Section comments** (`// --- Name ---`) for groups of related methods.
- **Doc comments** for public and non-obvious methods; brief inline comments for non-obvious steps.

---

## 10. Inline comments: variables, parameters, branches, loops

Every variable, parameter, branch, and loop should have a **concise** comment that explains *why* it exists or *what* it represents. Comment above the line or at end of line (when very short). Prefer one short sentence; avoid restating the code literally.

### Parameters

Document each parameter's role and any constraints. Use the method's doc comment (`///`) or inline `//` for each param.

**Good:** Doc comment or inline explains `[entries]`, `[reverse]`, `[onCreateLink]`, `scrollController`.  
**Bad:** Long parameter list with no explanation of what `reverse`, `onCreateLink`, or `scrollController` are for.

### Variables

Every local variable should have a comment stating what it holds or why it's needed. Names help, but a short comment per variable (and for the loop/branch) makes intent explicit.

### Branches (if / else / switch)

Every branch should have a comment explaining the **condition** or **case** in domain terms (e.g. "Success: close the sheet"; "Failure: leave sheet open and show error"; "Entry reached 24h and was auto-archived").

### Loops (for / while / for-in)

Every loop should have a comment explaining **what** we're iterating over and **what** we're doing in the loop (or why we break/continue).

### Summary: what to comment

| Element     | Comment explains |
|------------|-------------------|
| **Parameter** | Role, units, constraints (e.g. non-empty, nullable). |
| **Variable**  | What value it holds or why it's needed. |
| **if / else** | What the condition means in domain terms; why we take this branch. |
| **switch case** | What this case represents or when it happens. |
| **Loop**       | What we're iterating over and what we do each time (or why we break/continue). |

Keep each comment **concise** (one short sentence).

---

## 11. Summary checklist

| Aspect | Good | Bad |
|--------|------|-----|
| **Responsibility** | One clear job | Multiple jobs ("and" in the description) |
| **Name** | Verb + noun, specific | Vague (`doStuff`, `handle`, `getData`) |
| **Length** | Short, one level of abstraction | Long, deeply nested |
| **Parameters** | Few, named when 3+, clear types | Many, unclear names, no validation |
| **Documentation** | Purpose, params, return, errors | Missing or misleading |
| **Validation** | Inputs validated at boundary, fail fast | No checks, silent misuse |
| **Return / side effects** | Return value **or** side effect, not both mixed | Unclear mix of return and mutation |
| **Testability** | Explicit inputs, observable outcome | Hidden globals, ref, platform |
| **Formatting** | Line breaks, section/docs where needed | Cramped, no comments |
| **Inline comments** | Every variable, param, branch, loop has a concise explanation | Uncommented vars, params, branches, loops |

---

## 12. Appendix A: Rules enforced by saropa_lints

When you use **saropa_lints** (e.g. professional tier) and enable the optional stylistic rules below, the analyzer can enforce parts of this guide. Violations appear in the Problems tab and in lint reports.

### Public API and method documentation (Professional tier)

| Rule | What it enforces | Guide section |
|------|------------------|---------------|
| `require_public_api_documentation` | Every public class, method, and property must have a doc comment (`///`). | §5 Documentation |
| `require_parameter_documentation` | Parameters of public methods must be documented (purpose, constraints). | §4 Parameters, §5, §10 (params) |
| `require_return_documentation` | Every non-void method must document what it returns and when. | §5 Documentation |
| `require_exception_documentation` | Methods that throw must document the exceptions they throw. | §5 Documentation |
| `require_complex_logic_comments` | Methods the analyzer considers "complex" must have explanatory comments. | §5, §10 (logic) |

Enable these via the **Professional** tier (see [README.md](../../README.md) and tier config).

### Comment style and formatting (Stylistic tier / overrides)

Enable in your `analysis_options.yaml` or stylistic overrides to align with this guide:

| Rule | What it enforces | Guide section |
|------|------------------|---------------|
| `prefer_doc_comments_over_regular` | Use `///` for public API documentation, not `//`. | §5 Documentation |
| `prefer_period_after_doc` | Doc comment sentences must end with a period. | §5 Documentation |
| `prefer_sentence_case_comments` | Prose comments (3+ words) must start with a capital letter. Skips continuation lines in multi-line `//` blocks. | §9, §10 |
| `prefer_sentence_case_comments_relaxed` | Like above but only enforces on 5+ word comments. Skips continuation lines in multi-line `//` blocks. | §9, §10 |
| `prefer_capitalized_comment_start` | Same idea; capital letter at start of prose comments. | §9, §10 |
| `prefer_todo_format` | TODOs must use `TODO(author): description`. | §9 Formatting |
| `prefer_fixme_format` | FIXMEs must use `FIXME(author): description`. | §9 Formatting |
| `prefer_no_commented_out_code` | Remove commented-out code; rely on version control. | §9 Formatting |

### Spacing and layout (Stylistic tier / overrides)

| Rule | What it enforces | Guide section |
|------|------------------|---------------|
| `prefer_blank_line_before_method` | One blank line before each method declaration. | §9 Formatting and readability |
| `prefer_blank_lines_between_members` | One blank line between class members (fields, constructors, methods). | §9 Formatting and readability |
| `prefer_blank_line_before_constructor` | One blank line before each constructor. | §9 Formatting and readability |
| `prefer_blank_line_before_case` | One blank line before each `switch` case. | §9 Formatting and readability |
| `prefer_blank_line_before_return` | One blank line before each `return` statement. | §9 Formatting and readability |
| `prefer_blank_line_before_else` | One blank line before standalone `else` clauses (not `else if`). | §9 Formatting and readability |
| `prefer_blank_line_after_loop` | One blank line after a for/while loop before the next statement. | §9 Formatting and readability |
| `prefer_blank_line_after_declarations` | One blank line after variable declarations (separates setup from logic). | §9 Formatting and readability |
| `prefer_single_blank_line_max` | At most one consecutive blank line (no large gaps). | §9 Formatting and readability |

Keep `prefer_no_blank_line_before_return` **off** (it does the opposite of `prefer_blank_line_before_return`).

**Where to enable:** Use the Professional tier for the documentation rules; enable the stylistic rules above in your project's `analysis_options.yaml` or via the stylistic tier / overrides as described in the saropa_lints README.

---

## 13. Appendix B: Rules not enforced — manual review

The following requirements are part of this guide but **cannot** be enforced by the current Dart/Flutter/saropa_lints setup. Enforce them by **code review** and by following this document.

| Requirement | Why it's not enforced |
|-------------|------------------------|
| **Every local variable has a concise comment** | No rule checks for a comment on every local variable. |
| **Every parameter (at definition) has a comment** | `require_parameter_documentation` applies to *public* API only; private and internal parameters are not required to be documented by the analyzer. |
| **Every branch (if/else/switch case) has a comment** | No rule requires a comment on each branch. |
| **Every loop has a comment** | No rule requires a comment explaining what the loop does. |
| **Input validation at method boundaries** | No rule checks that parameters are validated (e.g. non-empty, range checks) at the top of methods. |
| **Single responsibility (one logical job per method)** | Heuristics like "long function" exist (`avoid_long_functions`), but there is no rule that checks "method does only one thing." |

### Manual-review checklist

Use this in code review or self-review:

- [ ] **Variables:** Every local variable has a concise comment (or is covered by a loop/block comment).
- [ ] **Parameters:** Every parameter at definition has a comment or is documented in the method's doc comment.
- [ ] **Branches:** Every non-trivial `if`/`else` and every `switch` case has a comment explaining the condition or case.
- [ ] **Loops:** Every loop has a comment explaining what we iterate and what we do (or why we break/continue).
- [ ] **Validation:** Entry-point and public methods validate inputs at the top and fail fast with a clear error.
- [ ] **Single responsibility:** The method can be described in one sentence without "and"; if not, it's split or explicitly justified.

Enforcing "comment on every variable/param/branch/loop" and "validate at boundaries" automatically would require additional custom lint rules; until then, this checklist and the guide are the standard.

---

Use this guide to write and review methods so the codebase stays clear, safe, and easy to change.
