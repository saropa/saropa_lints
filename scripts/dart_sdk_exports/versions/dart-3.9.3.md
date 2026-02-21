# Dart SDK 3.9.3

## 3.9.3

**Released on:** 2025-09-09

### Tools

#### Development JavaScript compiler (DDC)

- Fixes a pattern that could lead to exponentially slow compile times when
  static calls are deeply nested within a closure.
  When present this led to builds timing out or
  taking several minutes rather than several seconds.
