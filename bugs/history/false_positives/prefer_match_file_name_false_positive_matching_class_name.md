# Bug: `prefer_match_file_name` false positive when class name correctly matches file name

## Summary

The `prefer_match_file_name` rule fires on classes whose PascalCase name is an exact match for the snake_case file name. The warning is impossible to resolve without either renaming a correctly-named class or adding an `// ignore` comment.

## Severity

**Warning shown on correctly-named classes.** There is no action the developer can take — the class already matches the file name. This creates noise and erodes trust in the linter.

## Reproduction

### Case 1: `time_emoji_utils.dart`

```
lib/datetime/time_emoji_utils.dart
```

```dart
import 'package:saropa_dart_utils/datetime/date_constants.dart';

/// Utility class for handling time-related emojis.
class TimeEmojiUtils {  // <-- WARNING fires here (line 4, col 7)
  static const String sunEmoji = '☀️';
  static const String moonEmoji = '🌙';

  static String? getEmojiDayOrNight(int? tzHour) {
    if (tzHour == null) return null;
    return tzHour >= dayStartHour && tzHour < dayEndHour ? sunEmoji : moonEmoji;
  }
}

extension EmojiDateTimeExtensions on DateTime {
  String? get emojiDayOrNight => TimeEmojiUtils.getEmojiDayOrNight(hour);
}
```

**Expected conversion:**
- File: `time_emoji_utils.dart` → remove `.dart` → `time_emoji_utils`
- `_snakeToPascal('time_emoji_utils')` → split on `_` → `['time', 'emoji', 'utils']` → capitalize each → `TimeEmojiUtils`
- First public class: `TimeEmojiUtils`
- **Match: YES** → should NOT report

**Actual:** Warning fires.

### Case 2: `date_constants.dart`

```
lib/datetime/date_constants.dart
```

```dart
const int _unixEpochYear = 1970;
const int minMonth = 1;
// ... more top-level constants ...

class DateConstants {  // <-- WARNING fires here (line 62, col 7)
  static final DateTime unixEpochDate = DateTime.utc(_unixEpochYear);
}

class MonthUtils { /* ... */ }
class WeekdayUtils { /* ... */ }
class SerialDateUtils { /* ... */ }
```

**Expected conversion:**
- File: `date_constants.dart` → `date_constants`
- `_snakeToPascal('date_constants')` → `DateConstants`
- First public class: `DateConstants`
- **Match: YES** → should NOT report

**Actual:** Warning fires.

## Diagnostic output

```
info - time_emoji_utils.dart:4:7 - [prefer_match_file_name] When the primary class name
  does not match the file name, developers cannot use IDE file search to find declarations.
  This measurably slows navigation in large codebases. {v5} Rename either the file or the
  primary class so they match. For example, user_service.dart should contain class
  UserService. - prefer_match_file_name
```

```
info - date_constants.dart:62:7 - [prefer_match_file_name] When the primary class name
  does not match the file name, developers cannot use IDE file search to find declarations.
  This measurably slows navigation in large codebases. {v5} Rename either the file or the
  primary class so they match. For example, user_service.dart should contain class
  UserService. - prefer_match_file_name
```

## Root cause hypothesis

### Most likely: Windows path separator in file name extraction

**File:** `lib/src/rules/naming_style_rules.dart` (line ~1715)

The file name is extracted by taking the last segment after `/`:

```dart
final fileName = context.filePath.split('/').last.replaceAll('.dart', '');
```

On Windows, `context.filePath` may contain backslashes:

```
d:\src\saropa_dart_utils\lib\datetime\time_emoji_utils.dart
```

If the path uses `\` instead of `/`, `split('/')` returns a single element (the entire path). Then `replaceAll('.dart', '')` produces:

```
d:\src\saropa_dart_utils\lib\datetime\time_emoji_utils
```

And `_snakeToPascal()` on that string (splitting on `_`) produces garbage that will never match any class name. This would cause false positives on **every file** when running on Windows.

### Alternative: declaration iteration issue

The rule iterates `CompilationUnit.declarations` looking for the first public class. If extensions or other declaration types are incorrectly counted, or if the iteration order doesn't match source order, the rule might find a non-matching declaration before the actual matching class.

In `time_emoji_utils.dart`, the extension `EmojiDateTimeExtensions` follows `TimeEmojiUtils`. If the rule checks extensions as well as classes (or if declarations are unordered), it might compare `EmojiDateTimeExtensions` to the file name instead of `TimeEmojiUtils`.

## Suggested fix

### If path separator is the issue

Use `package:path` or split on both separators:

```dart
// Before (broken on Windows):
final fileName = context.filePath.split('/').last.replaceAll('.dart', '');

// After (cross-platform):
final segments = context.filePath.split(RegExp(r'[/\\]'));
final fileName = segments.last.replaceAll('.dart', '');
```

### If declaration iteration is the issue

Ensure only `ClassDeclaration` nodes are considered (not `ExtensionDeclaration`, `MixinDeclaration`, etc.) and that the first one in source order is used:

```dart
final firstPublicClass = node.declarations
    .whereType<ClassDeclaration>()
    .where((c) => !c.name.lexeme.startsWith('_'))
    .firstOrNull;

if (firstPublicClass == null) return;

final className = firstPublicClass.name.lexeme;
if (className != expectedClassName) {
  reporter.atToken(firstPublicClass.name, code);
}
```

## Affected patterns

Any file where the class name correctly matches the file name. Based on the two confirmed cases, this appears to be a systematic issue rather than edge-case-specific:

| File | Primary class | Should match | Warning? |
|------|--------------|:---:|:---:|
| `time_emoji_utils.dart` | `TimeEmojiUtils` | Yes | **Yes (FP)** |
| `date_constants.dart` | `DateConstants` | Yes | **Yes (FP)** |

## Resolution

**Fixed 2026-02-22.** Two root causes confirmed and patched in `naming_style_rules.dart`:

1. **Windows path separator** — `filePath.split('/')` failed on backslash paths. Fixed with `RegExp(r'[/\\]')` (static constant for performance).
2. **Multiple-class logic bug** — After the first public class matched, the loop continued and reported subsequent non-matching classes. Fixed by returning after checking the first public class regardless of match outcome.

## Environment

- **OS:** Windows 11 Pro 10.0.22631
- **IDE:** VS Code
- **Rule version:** v5
- **saropa_lints version:** (current)
- **Dart SDK:** (current stable)
