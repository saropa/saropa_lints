/// Safe string slicing utilities.
///
/// Wraps String.substring in bounds-checked helpers so callers do not need
/// to repeat the same length guards and cannot accidentally trigger a
/// RangeError. Also used to satisfy the avoid_string_substring lint rule:
/// the lint fires on any `String.substring` call regardless of guards.
library;

/// Adds safe substring helpers to every [String].
///
/// All methods clamp indices into `[0, length]`, returning an empty string
/// when the clamped range collapses. This matches the intent of most
/// substring callers (prefix/suffix slicing for display or parsing) and
/// avoids throwing RangeError on edge cases like empty strings or
/// API responses with unexpected lengths.
extension SaropaStringSlice on String {
  /// Clamped prefix: returns at most [end] characters from the start.
  ///
  /// If [end] is negative, returns an empty string. If [end] is greater
  /// than the string length, returns the whole string.
  String prefix(int end) {
    if (end <= 0) return '';
    if (end >= length) return this;
    return substring(0, end);
  }

  /// Clamped suffix: returns at most [count] characters from the end.
  ///
  /// If [count] is negative, returns an empty string. If [count] is greater
  /// than the string length, returns the whole string.
  String suffix(int count) {
    if (count <= 0) return '';
    if (count >= length) return this;
    return substring(length - count);
  }

  /// Clamped substring: returns characters between [start] and [end],
  /// clamping both indices to the valid range. If [end] is null, slices
  /// to the end of the string.
  String slice(int start, [int? end]) {
    final int effectiveStart = start < 0
        ? 0
        : (start > length ? length : start);
    final int effectiveEnd = end == null
        ? length
        : (end < 0 ? 0 : (end > length ? length : end));
    if (effectiveEnd <= effectiveStart) return '';
    return substring(effectiveStart, effectiveEnd);
  }

  /// Returns the substring after [prefixString], or the original string if
  /// the prefix is not present. Safe alternative to `substring(prefixString.length)`.
  String afterPrefix(String prefixString) {
    if (!startsWith(prefixString)) return this;
    return substring(prefixString.length);
  }

  /// Clamped: returns characters from [start] to end of string.
  /// Clamps [start] into `[0, length]`.
  String afterIndex(int start) {
    if (start <= 0) return this;
    if (start >= length) return '';
    return substring(start);
  }

  /// Clamped: returns characters from 0 to [end] (exclusive).
  /// Clamps [end] into `[0, length]`. Equivalent to [prefix] but named so
  /// replacement for `substring(0, N)` reads naturally.
  String sliceHead(int end) => prefix(end);
}
