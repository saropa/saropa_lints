# PROPOSAL: logd Logging Library Rule Family (12 Rules)

**Status: Open**

Created: 2026-09-02
Type: New rule (family)
Related rules: none

---

## Summary

Add a package-specific rule family covering the `logd` structured-logging library's API contracts, ported from `logd_linters` (pub.dev). `logd` uses checkout/release lifecycle pairs, immutable decorators/formatters, bitmask-based log tags, and an engine/handler configuration model — misuse of any of these produces silent data loss, memory leaks, or crashes that are otherwise invisible until production. This proposal covers all 12 `logd`-specific rules as a single family since they share one dependency gate, one detection strategy (AST matching against `package:logd` API surface), and one implementation review.

**Closes gap:** `logd_linters` (pub.dev) — `avoid_print_sink_in_production`, `checkout_without_release`, `decorator_not_immutable`, `document_retained_across_cycles`, `formatter_not_immutable`, `formatter_performs_string_rendering`, `freeze_on_unconfigured_logger`, `handler_missing_dispose`, `handler_missing_engine`, `log_buffer_not_sunk`, `logtag_use_bitmask`, `missing_release_in_engine`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`logd` is a niche dependency: none of these 12 rules are useful, or even resolvable, in a project that doesn't depend on `package:logd`. Bundling them under one dependency gate (`hasDependency('logd')`) keeps the family cheap to skip for the other 99% of projects while giving `logd` consumers the same coverage as the source package. The rules cluster into four themes:

- **Lifecycle pairing** (`checkout_without_release`, `handler_missing_dispose`, `missing_release_in_engine`) — every `checkout()`/handler acquire needs a matching `release()`/`dispose()`, or logging resources (buffers, file handles) leak.
- **Immutability contracts** (`decorator_not_immutable`, `formatter_not_immutable`) — decorators/formatters are shared across log calls; a mutable one causes cross-call state bleed.
- **Configuration completeness** (`handler_missing_engine`, `freeze_on_unconfigured_logger`, `log_buffer_not_sunk`) — a handler/logger built without its required engine, or a buffer that's frozen/never flushed, silently drops log entries.
- **Performance/production hygiene** (`avoid_print_sink_in_production`, `formatter_performs_string_rendering`, `document_retained_across_cycles`, `logtag_use_bitmask`) — a `PrintSink` left wired in a release build, a formatter doing eager string work instead of lazy rendering, a log `Document` object retained beyond its logging cycle (memory growth), and log tags expressed as loose integers/strings instead of the library's bitmask convention.

---

## Detection / Behavior

Only active when `logd` is a project dependency (`hasDependency('logd')`), same gating pattern used elsewhere in saropa_lints for library-specific rules (Riverpod, GetX, Isar).

### Should flag (bad code)

```dart
// avoid_print_sink_in_production
final logger = Logger(sinks: [PrintSink()]); // LINT — PrintSink left in what looks like production config

// checkout_without_release
final doc = engine.checkout(); // LINT — no matching engine.release(doc) found in scope
doc.write('event');

// decorator_not_immutable
class TimestampDecorator extends LogDecorator {
  DateTime lastSeen; // LINT — mutable field on a decorator shared across log calls
}

// handler_missing_dispose
class MyHandler extends LogHandler {
  final FileSink sink = FileSink('app.log'); // LINT — no dispose() override to close sink
}
```

### Should pass (good code)

```dart
final logger = Logger(sinks: [FileSink('app.log')]); // OK — no PrintSink in production config

final doc = engine.checkout();
try {
  doc.write('event');
} finally {
  engine.release(doc); // OK — paired release
}

class TimestampDecorator extends LogDecorator {
  final DateTime createdAt; // OK — immutable
  TimestampDecorator(this.createdAt);
}

class MyHandler extends LogHandler {
  final FileSink sink = FileSink('app.log');

  @override
  void dispose() {
    sink.close(); // OK — paired dispose
  }
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: Package-specific to a niche logging library; only relevant to `logd` consumers, matching saropa's placement for other narrow third-party-library rule families.

---

## Edge Cases

1. **Project doesn't depend on `logd`** — all 12 rules are inert (dependency gate short-circuits); zero overhead.
2. **`checkout()`/`release()` pair spans an `async` boundary (checkout in one method, release in a callback)** — needs discussion per-rule; the naive same-scope `try/finally` detection will miss legitimate cross-method pairing and needs a conservative fallback (e.g. only flag when no `release`/`dispose` call exists anywhere reachable in the enclosing class, not just the same block).
3. **`PrintSink` used deliberately in `main_debug.dart` / test harness** — `avoid_print_sink_in_production` should exempt files under `test/`, `*_debug.dart`, or gated behind `kDebugMode`/`assert`.
4. **Subclass of a decorator/formatter with only `final` fields but a mutable field added by a further subclass** — should flag at the subclass that introduces the mutable field, not the original base.

---

## Alternatives Considered

- **12 separate proposal files** — rejected per project convention for logd_linters batch (see task instructions); the rules share one dependency gate and one review, so a combined proposal avoids 12 near-duplicate documents.
- **Implement as a single generic "resource lifecycle" rule instead of 12 named rules** — rejected; parity with the source package's rule names/granularity lets users map 1:1 from `logd_linters` docs and selectively disable individual checks.

---

## Decision

---

## Implementation Notes

- Each of the 12 checks should still be its own `SaropaLintRule` class/rule id (for individual enable/disable and tier control) — this proposal groups the *documentation*, not the implementation, into one file.
- Rule ids: `logd_avoid_print_sink_in_production`, `logd_checkout_without_release`, `logd_decorator_not_immutable`, `logd_document_retained_across_cycles`, `logd_formatter_not_immutable`, `logd_formatter_performs_string_rendering`, `logd_freeze_on_unconfigured_logger`, `logd_handler_missing_dispose`, `logd_handler_missing_engine`, `logd_log_buffer_not_sunk`, `logd_logtag_use_bitmask`, `logd_missing_release_in_engine`.

---

## Commits
