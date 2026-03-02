# False Positive Lint Reports from Kykto Project

Reported: 2026-02-25

---

## 1. `avoid_path_traversal` / `require_file_path_sanitization`

**File:** `lib/data/database/app_database.dart:79`
**Code:**
```dart
static Future<void> _deleteOldUnencryptedDb(String dbDirPath) async {
  for (final suffix in ['', '-wal', '-shm']) {
    final oldFile = File('$dbDirPath/kykto_db.sqlite$suffix');
```

**Why false positive:** The `dbDirPath` parameter comes exclusively from
`getApplicationDocumentsDirectory().path` (a platform API, line 46), not from
user input. The `suffix` comes from a hardcoded list. No user-controlled data
reaches this file path. The lint cannot distinguish platform-provided paths from
user-provided strings.

**Suggested improvement:** Recognize well-known platform path APIs
(`getApplicationDocumentsDirectory`, `getTemporaryDirectory`,
`getApplicationSupportDirectory`) as trusted sources that do not require path
traversal sanitization.

---

## 2. `avoid_ref_in_build_body` / `avoid_ref_read_inside_build`

**Files & lines:**
- `lib/features/settings/screens/settings_screen.dart:54-55` (inside `onSelectionChanged` callback)
- `lib/features/stream/screens/stream_screen.dart:24` (inside `onSubmit` callback)
- `lib/features/archive/widgets/archive_search_bar.dart:35` (inside `onChanged` callback)
- `lib/features/archive/widgets/archive_search_bar.dart:46` (inside `onPressed` callback)

**Example code (settings_screen.dart):**
```dart
onSelectionChanged: (selection) {
  ref
      .read(themeModeProvider.notifier)
      .setThemeMode(selection.first);
},
```

**Why false positive:** All flagged `ref.read()` calls are inside event
callbacks (`onSelectionChanged`, `onSubmit`, `onChanged`, `onPressed`) defined
within `build()`. Using `ref.read()` in callbacks is the **correct** Riverpod
pattern — callbacks execute lazily on user interaction, not during the build
phase. Only direct calls in the build body should be flagged.

**Suggested improvement:** Walk the AST to distinguish between direct calls in
the build method body and calls nested inside closure/callback arguments
(`onPressed`, `onChanged`, `onTap`, `onSubmit`, `onSelectionChanged`, etc.).

---

## 3. `avoid_unsafe_collection_methods` (SegmentedButton selection)

**File:** `lib/features/settings/screens/settings_screen.dart:56`
**Code:**
```dart
onSelectionChanged: (selection) {
  ref.read(themeModeProvider.notifier).setThemeMode(selection.first);
},
```

**Why false positive:** `SegmentedButton.onSelectionChanged` provides a
`Set<T>` that is guaranteed to contain at least one element — the widget
enforces a minimum selection of 1. Calling `.first` here cannot throw
`StateError`.

**Suggested improvement:** Maintain a list of Flutter framework callbacks whose
collection parameters are guaranteed non-empty, or at minimum recognize
`SegmentedButton.onSelectionChanged` as a safe context.

---

## 4. `avoid_unsafe_collection_methods` (guarded by early return)

**File:** `lib/shared/painters/donut_chart_painter.dart:25`
**Code:**
```dart
final total = segments.fold<double>(0, (sum, s) => sum + s.value);
if (total == 0) return;           // ← guard: empty list yields total == 0

final bgPaint = Paint()
  ..color = segments.first.color   // ← flagged, but unreachable if empty
```

**Why false positive:** Line 20-21 computes `total` via `fold`. If `segments`
is empty, `total` is 0 and the method returns at line 21. Therefore
`segments.first` on line 25 is only reachable when `segments` is non-empty.

**Suggested improvement:** Perform basic data-flow analysis to recognize that an
early return on a derived emptiness check (fold == 0 when all values are
non-negative) guards subsequent `.first` / `.last` calls.

---

## 5. `avoid_unsafe_reduce` (guarded by length check)

**File:** `lib/shared/painters/sparkline_painter.dart:18`
**Code:**
```dart
if (data.length < 2) return;                        // ← guard
final maxVal = data.reduce((a, b) => a > b ? a : b); // ← flagged
```

**Why false positive:** Line 16 checks `data.length < 2` and returns early.
By line 18, `data` has at least 2 elements, making `reduce()` safe.

**Suggested improvement:** Recognize `if (list.length < N) return` and
`if (list.isEmpty) return` as guards that make subsequent `reduce()`, `.first`,
`.last`, and `.single` calls safe within the same scope.

---

## 6. `require_app_startup_error_handling`

**File:** `lib/main.dart:8-22`
**Code:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LogSanitizer.configure();
  final encryptionKey = await EncryptionKeyService.getOrCreateKey();
  runApp(ProviderScope(...));
}
```

**Why false positive:** The lint recommends wrapping `runApp()` in
`runZonedGuarded` with crash reporting (e.g., Crashlytics). However:
1. The app has no crash reporting service configured.
2. Flutter already has a default `FlutterError.onError` that prints to console.
3. Adding `runZonedGuarded` with a `debugPrint` handler that gets suppressed in
   release mode (via `LogSanitizer`) would silently swallow zone errors —
   making error visibility **worse**, not better.

**Suggested improvement:** Only fire this lint when a crash reporting dependency
is detected in `pubspec.yaml` (e.g., `firebase_crashlytics`, `sentry_flutter`)
but not wired into the startup. Alternatively, reduce severity to info/hint for
apps without a monitoring dependency.

---

## 7. `require_search_debounce` (debounce already implemented)

**File:** `lib/features/archive/widgets/archive_search_bar.dart:34`
**Code (after fix):**
```dart
onChanged: (value) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () {
    ref.read(archiveSearchQueryProvider.notifier).setQuery(value);
  });
},
```

**Why false positive:** The lint continues to fire even after debounce is
correctly implemented via `Timer` in the enclosing `State` class. The lint does
not recognize `Timer`-based debounce patterns.

**Suggested improvement:** Detect common debounce patterns: a `Timer` field on
the State class that is cancelled and re-created inside `onChanged`. Also
recognize `Debouncer` utility classes and `RestartableTimer`.

---

## 8. `require_minimum_contrast` (cannot determine contrast statically)

**File:** `lib/features/stream/widgets/thought_card.dart:137,143`
**Code:**
```dart
Text(label, style: const TextStyle(color: Colors.white)),
```

**Background context:** The text is rendered inside a `Container` whose
background color is a variable (`KyktoColors.swipeDismiss` = `0xFFD32F2F`,
`KyktoColors.swipeExport` = `0xFF2E7D32`). Both now meet WCAG 4.5:1 with white.

**Why partially false positive:** While the original colors (Red 400, Green 400)
did have insufficient contrast (fixed in this same changeset), the lint flags
`Colors.white` without being able to compute the actual contrast ratio — it
cannot resolve the background color from a variable/constant in a different file.

**Suggested improvement:** If the lint cannot resolve the background color at
analysis time, it should either:
1. Not fire (avoiding false positives), or
2. Fire as info/hint severity (not warning) with a message like "contrast ratio
   could not be verified statically — ensure WCAG 4.5:1 compliance at runtime."

---

## Resolution

**Resolved in:** v6.0.5 (unreleased)

| # | Rule | Fix |
|---|------|-----|
| 1 | `avoid_path_traversal`, `require_file_path_sanitization` | Recognize platform path APIs as trusted sources |
| 2 | `avoid_ref_in_build_body`, `avoid_ref_read_inside_build` | Already fixed in v6.0.4 (commit f48215d8) |
| 3 | `avoid_unsafe_collection_methods` | Recognize `SegmentedButton.onSelectionChanged` as non-empty |
| 4 | `avoid_unsafe_collection_methods` | Detect early-return emptiness guards |
| 5 | `avoid_unsafe_reduce` | Detect `isEmpty`/`length` guards (early return + if/ternary) |
| 6 | `require_app_startup_error_handling` | Only fire when crash reporting dependency present |
| 7 | `require_search_debounce` | Check enclosing class for Timer/Debouncer field declarations |
| 8 | `require_minimum_contrast` | Skip when ancestor container has unresolvable background color |
