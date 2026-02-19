# Task: `avoid_large_object_in_state`

## Summary
- **Rule Name**: `avoid_large_object_in_state`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.33 Memory Optimization Rules

## Problem Statement

Storing large objects in Flutter `State` classes (fields on `State<T>`) keeps them in memory for the entire lifecycle of the widget. This causes:

1. **Memory pressure**: Large objects (image data, parsed documents, large lists) held in `State` prevent garbage collection
2. **OOM crashes**: On memory-constrained devices, large state objects push the app over memory limits
3. **Slow garbage collection**: When the widget is finally disposed, freeing large objects takes time
4. **Incorrect semantics**: Large data should typically be in a provider/repository, not in widget state

Common problematic patterns:
```dart
class _DocumentViewerState extends State<DocumentViewer> {
  Uint8List? _pdfBytes;        // ← raw PDF bytes (potentially MBs)
  List<Widget> _renderedPages; // ← all pages rendered at once
  Map<String, dynamic> _fullJsonData; // ← entire API response
}
```

## Description (from ROADMAP)

> Large objects in widget state cause memory issues. Detect >1MB objects in state.

## Trigger Conditions

The "1MB" size threshold cannot be measured statically. The lint uses **type heuristics**:

1. `Uint8List` field in `State` class — raw bytes (images, PDFs, files) can be very large
2. `List<Widget>` field in `State` class — rendered widget trees should use lazy builders
3. Field typed as a data model that is known to contain large data (heuristic: class name contains `Document`, `Image`, `Bytes`, `Data`)
4. `Map<String, dynamic>` fields representing full API responses

**Conservative Phase 1**: Flag `Uint8List` and `List<Uint8List>` fields in `State` classes.

## Implementation Approach

```dart
context.registry.addClassDeclaration((node) {
  if (!_isStateClass(node)) return;

  final fields = node.members.whereType<FieldDeclaration>();
  for (final field in fields) {
    final type = _getFieldType(field);
    if (_isLargeDataType(type)) {
      reporter.atNode(field, code);
    }
  }
});
```

`_isStateClass`: check if class extends `State<T>`.
`_isLargeDataType`: check if type is `Uint8List`, `List<Uint8List>`, `ByteData`, or known large types.

## Code Examples

### Bad (Should trigger)
```dart
class _PdfViewerState extends State<PdfViewer> {
  Uint8List? _pdfBytes;        // ← trigger: raw bytes in state
  List<Uint8List> _pageImages; // ← trigger: list of raw bytes
}
```

### Good (Should NOT trigger)
```dart
// Use a StreamController or provider for large data
class _PdfViewerState extends State<PdfViewer> {
  // Reference to data, not the data itself
  String? _pdfUrl; // ← just a URL, not bytes

  // Or use a lazy loader
  PdfController? _controller; // ← lightweight controller, not bytes
}

// Large data in a provider (correct architecture)
class PdfProvider extends ChangeNotifier {
  Uint8List? _bytes; // ← in a provider, can be evicted from memory
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| `Uint8List` for a small icon (< 1KB) | **Trigger** — can't know size statically | This is a false positive |
| `Uint8List` with size limit enforced elsewhere | **Trigger** — can't know | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |
| Abstract `State` class (base class) | **Suppress** | |

## Unit Tests

### Violations
1. `State` class with `Uint8List` field → 1 lint
2. `State` class with `List<Uint8List>` field → 1 lint

### Non-Violations
1. Non-State class with `Uint8List` → no lint
2. `State` class with `String`, `int`, `bool` fields → no lint

## Quick Fix

Offer "Move to a provider or use a lazy loader":
```dart
// Before (in State)
Uint8List? _imageBytes;

// After: Use a reference/key instead
String? _imageUrl; // load on demand
// or ImageProvider (lazy loaded)
ImageProvider? _imageProvider;
```

## Notes & Issues

1. **Flutter-only**: Only fire if `ProjectContext.isFlutterProject`.
2. **FALSE POSITIVE RISK**: `Uint8List` in state is not always large. A 32-byte hash, a small icon, etc. are all `Uint8List` but not large. The lint trades accuracy for simplicity.
3. **The correct architecture**: Large data belongs in state management (Riverpod, BLoC, Provider) where it can be shared, cached, and evicted. Widget state is for ephemeral, widget-specific state.
4. **`ByteData` vs `Uint8List`**: Both are raw byte representations. Include both.
5. **Consider INFO severity**: Since many `Uint8List` uses are legitimate (small icon bytes, checksums), WARNING may cause frustration. INFO with a good correction message is more appropriate for this broad heuristic.
6. **The ">1MB" claim**: Since we can't measure size statically, the rule is really "avoid raw byte arrays in state" — the ">1MB" is aspirational. Be honest about this in the correction message.
