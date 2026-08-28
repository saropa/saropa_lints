/// Annotations for use with saropa_lints rules.
///
/// Import this library to annotate your code with hints that saropa_lints
/// rules will recognize, reducing false positives without suppressing the
/// entire rule.
///
/// ```dart
/// import 'package:saropa_lints/annotations.dart';
/// ```
library;

/// Marks a method as a cache-method that returns a stored Future rather than
/// creating a new one on each call.
///
/// When `pass_existing_future_to_future_builder` sees a method annotated with
/// `@cachedFuture` passed to `FutureBuilder(future:)`, it will not flag the
/// call — the annotation is an explicit signal that the method manages its
/// own caching internally.
///
/// Use this when the heuristic-based exemption (private method on a class
/// with a `Future<T>?` field) does not apply to your naming convention.
///
/// ```dart
/// class _MyState extends State<MyWidget> {
///   Future<Data>? _cache;
///
///   @cachedFuture
///   Future<Data> _load(String id) {
///     return _cache ??= _repository.fetch(id);
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return FutureBuilder<Data>(
///       future: _load(widget.id), // OK — @cachedFuture suppresses the lint
///       builder: (context, snapshot) => ...,
///     );
///   }
/// }
/// ```
const cachedFuture = CachedFuture();

/// Annotation class backing [cachedFuture]. Do not instantiate directly;
/// use the [cachedFuture] constant instead.
class CachedFuture {
  /// Creates a CachedFuture annotation instance.
  const CachedFuture();
}
