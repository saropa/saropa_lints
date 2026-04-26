/// Helpers for the `require_notification_for_long_tasks` lint rule.
///
/// Detects long-operation *tokens* inside Dart identifiers using camelCase
/// boundaries so substrings like `import` + `all` inside `ImportAllowed` do
/// not count as `importAll`.
library;

bool _asciiLowerCase(int unit) => unit >= 0x61 && unit <= 0x7a;

bool _asciiUpperCase(int unit) => unit >= 0x41 && unit <= 0x5a;

/// Two ASCII letters at [start]..[start+1] equal [a][b], case-insensitive.
bool _asciiPairAtIgnoreCase(String s, int start, int aLower, int bLower) {
  if (start < 0 || start + 2 > s.length) {
    return false;
  }
  int u0 = s.codeUnitAt(start);
  int u1 = s.codeUnitAt(start + 1);
  if (u0 >= 0x41 && u0 <= 0x5a) {
    u0 += 0x20;
  }
  if (u1 >= 0x41 && u1 <= 0x5a) {
    u1 += 0x20;
  }
  return u0 == aLower && u1 == bLower;
}

bool _longOpNameLeftBoundary(String methodName, int index) {
  if (index == 0) {
    return true;
  }
  final int prev = methodName.codeUnitAt(index - 1);
  final int curr = methodName.codeUnitAt(index);
  if (prev == 0x5f) {
    return true;
  }
  return _asciiLowerCase(prev) && _asciiUpperCase(curr);
}

bool _longOpNameRightBoundary(String methodName, int endExclusive) {
  if (endExclusive >= methodName.length) {
    return true;
  }
  final int next = methodName.codeUnitAt(endExclusive);
  if (next == 0x5f) {
    return true;
  }
  return _asciiUpperCase(next);
}

/// True when [methodName] contains [pattern] as a camelCase-aligned substring.
///
/// Used by `require_notification_for_long_tasks` and covered by unit tests
/// so boundary tweaks stay regression-safe.
bool longOperationMethodNameMatchesPattern(String methodName, String pattern) {
  if (pattern.isEmpty || methodName.isEmpty) {
    return false;
  }
  final String lowerName = methodName.toLowerCase();
  final String lowerPattern = pattern.toLowerCase();
  var start = 0;
  while (true) {
    final int index = lowerName.indexOf(lowerPattern, start);
    if (index < 0) {
      return false;
    }
    if (_longOpNameLeftBoundary(methodName, index) &&
        _longOpNameRightBoundary(methodName, index + pattern.length)) {
      if (lowerPattern == 'processall' &&
          _asciiPairAtIgnoreCase(methodName, index - 2, 0x64, 0x62)) {
        start = index + 1;
        continue;
      }
      return true;
    }
    start = index + 1;
  }
}
