// Regression tests for the remaining detection false-positives in
// async_rules.dart, exercised against fully resolved source via the oracle
// harness (test/support/resolved_rule_harness.dart).
//
// Each group reproduces ONE audited false-positive class and pins both the
// real-positive (must still fire) and the false-positive (must NOT fire).
//
// Audited items:
//  - avoid_dialog_context_after_async: a mounted check AFTER the pop was
//    credited as "before" because the rule sliced a re-rendered toSource()
//    string at original-source offsets (whitespace/comments shift them).
//  - prefer_utc_for_storage: an unrelated storage call in an ENCLOSING scope
//    marked a UI-label toIso8601String() as "storage context" because the
//    context scan ran storage regexes against every ancestor's toSource().
//  - require_stream_error_handling: the `controller` name fallback flagged a
//    non-Stream `animationController.listen(...)` for a missing onError.
//  - avoid_unassigned_stream_subscriptions: claimed to never check the
//    variable type — verified it already requires `Stream` static type.
library;

import 'package:saropa_lints/src/rules/core/async_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('avoid_dialog_context_after_async', () {
    // A guarded pop must stay silent. The mounted check sits BEFORE the pop in
    // the original source; the old offset-into-toSource() slice handled this
    // case by luck, so it is the control for the real bug below.
    test(
      'does NOT fire when context.mounted guards the pop (control)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidDialogContextAfterAsyncRule(),
          '''
class Navigator {
  static void pop(Object? context) {}
}

class Svc {
  Future<void> onTap(Object context, bool mounted) async {
    await Future<void>.value();
    if (context == null) return;
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
''',
        );
        expect(codes, isNot(contains('avoid_dialog_context_after_async')));
      },
    );

    // THE BUG: the mounted check is AFTER the pop, so the pop is unguarded and
    // MUST be flagged. Comments + irregular whitespace before the pop make the
    // original-source offset larger than the matching index in the re-rendered
    // toSource() string, so the old slice wrongly included the trailing mounted
    // text and credited it as "before" -> false NEGATIVE (missed the bug).
    test('fires when the mounted check is AFTER the pop', () async {
      final codes = await reportedRuleCodes(
        AvoidDialogContextAfterAsyncRule(),
        '''
class Navigator {
  static void pop(Object? context) {}
}

class Svc {
  Future<void> onTap(Object context, bool mounted) async {
    // a long explanatory comment that toSource() strips, shifting offsets
    await Future<void>.value();
    // another comment here to widen the gap before the pop call below
    Navigator.pop(context);
    if (mounted) {
      return;
    }
  }
}
''',
      );
      expect(codes, contains('avoid_dialog_context_after_async'));
    });
  });

  group('prefer_utc_for_storage', () {
    // Real positive: toIso8601String() of a local DateTime inside an actual
    // storage call must still fire.
    test('fires when toIso8601String() is inside a save() call', () async {
      final codes = await reportedRuleCodes(PreferUtcForStorageRule(), '''
class Db {
  void save(Object value) {}
}

void persist(Db db, DateTime created) {
  db.save(created.toIso8601String());
}
''');
      expect(codes, contains('prefer_utc_for_storage'));
    });

    // THE BUG: a toIso8601String() used for a UI label, where an UNRELATED
    // save()/insert() lives elsewhere in the same enclosing method. The old
    // ancestor scan ran storage regexes against each ancestor's full toSource(),
    // so the enclosing method body (which contains `save(`) marked the label as
    // "storage context" -> false POSITIVE.
    test(
      'does NOT fire on a UI label when an unrelated save() is in scope',
      () async {
        final codes = await reportedRuleCodes(PreferUtcForStorageRule(), '''
class Db {
  void save(Object value) {}
}

class Ui {
  String build(Db db, DateTime created, DateTime shown) {
    db.save('unrelated payload');
    final String label = 'Updated: ' + shown.toIso8601String();
    return label;
  }
}
''');
        expect(codes, isNot(contains('prefer_utc_for_storage')));
      },
    );

    // THE BUG (already_utc_via_upstream_construction), reproducer from the
    // bug report: a `final` field promoted via `this.field` whose only
    // visible construction site always passes a UTC value. The receiver's
    // own source (`at`) never mentions `.toUtc()`/`.utc`.
    //
    // NOT suppressed (unlike the local-variable case below): an earlier
    // version of this rule tried to resolve a field back to its
    // construction site(s) the same way, but that requires whole-program
    // (not just whole-file) analysis to be sound — a field can be set via
    // a redirecting factory constructor, a subclass constructor forwarding
    // through `super(...)`, a mixin-application class alias, a tear-off, or
    // (for any non-private class, including the report's own reproducer) a
    // construction site in another file/part this scan can never see. That
    // approximation was found to still miss several of those paths and was
    // removed rather than patched further, so field access is always
    // flagged — this rule is only PARTIALLY fixed relative to the report.
    test('still fires (NOT fixed) on a constructor-promoted field whose '
        'only visible construction site is already UTC', () async {
      final codes = await reportedRuleCodes(PreferUtcForStorageRule(), '''
class HostStatement {
  const HostStatement({required this.at});

  final DateTime at;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'at': at.toIso8601String(),
  };
}

HostStatement makeEntry() => HostStatement(at: DateTime.now().toUtc());
''');
      expect(codes, contains('prefer_utc_for_storage'));
    });

    // Local-variable counterpart of the fix that IS sound: a `final` local
    // whose initializer is UTC, referenced later by a bare identifier with
    // no `.toUtc()`/`.utc` in its own source. Unlike a field, a local
    // variable's only possible assignment is its own declaration
    // (`final` forbids reassignment), so a single-hop, same-file lookup of
    // its initializer is sufficient to be sound.
    test('does NOT fire on a final local variable whose initializer is '
        'already UTC', () async {
      final codes = await reportedRuleCodes(PreferUtcForStorageRule(), '''
class Db {
  void insert(Object value) {}
}

void persist(Db db) {
  final utcNow = DateTime.now().toUtc();
  db.insert({'timestamp': utcNow.toIso8601String()});
}
''');
      expect(codes, isNot(contains('prefer_utc_for_storage')));
    });

    // Closure-captured counterpart: the `final` local is declared in the
    // outer function but read inside a nested closure. The identifier's
    // nearest enclosing FunctionBody is the closure's own body, which does
    // NOT contain the declaration -- resolution must search the whole
    // compilation unit (not just the nearest FunctionBody) to still find
    // it and correctly suppress.
    test('does NOT fire on a final local variable read inside a nested '
        'closure', () async {
      final codes = await reportedRuleCodes(PreferUtcForStorageRule(), '''
class Db {
  void insert(Object value) {}
}

void persist(Db db) {
  final utcNow = DateTime.now().toUtc();
  void inner() {
    db.insert({'timestamp': utcNow.toIso8601String()});
  }
  inner();
}
''');
      expect(codes, isNot(contains('prefer_utc_for_storage')));
    });

    // Real positive: the local variable's initializer converts to UTC and
    // then back to local time -> the OUTERMOST expression is `.toLocal()`,
    // not `.toUtc()`, so the value is not UTC. Structural (not substring)
    // matching is required: a text search for `.toUtc(` would wrongly
    // treat this as UTC.
    test('still fires on a final local variable whose initializer is '
        '.toUtc().toLocal()', () async {
      final codes = await reportedRuleCodes(PreferUtcForStorageRule(), '''
class Db {
  void insert(Object value) {}
}

void persist(Db db) {
  final localNow = DateTime.now().toUtc().toLocal();
  db.insert({'timestamp': localNow.toIso8601String()});
}
''');
      expect(codes, contains('prefer_utc_for_storage'));
    });

    // Real positive: same structural fix applied to the RECEIVER check
    // itself (not just the upstream-resolution hop) -- a chained
    // `.toUtc().toLocal().toIso8601String()` call inside a storage context
    // must still fire, because the outermost form before
    // `.toIso8601String()` is `.toLocal()`, not `.toUtc()`.
    test(
      'still fires when the receiver itself is .toUtc().toLocal()',
      () async {
        final codes = await reportedRuleCodes(PreferUtcForStorageRule(), '''
class Db {
  void insert(Object value) {}
}

void persist(Db db, DateTime created) {
  db.insert({
    'timestamp': created.toUtc().toLocal().toIso8601String(),
  });
}
''');
        expect(codes, contains('prefer_utc_for_storage'));
      },
    );

    // THE BUG (UTC-preserving arithmetic): `.add(Duration)`/
    // `.subtract(Duration)` don't change a DateTime's UTC-ness, so a
    // `.toUtc()` (or `DateTime.utc(...)`) further back in the chain still
    // makes the whole expression UTC. Requiring the OUTERMOST form to be a
    // bare `.toUtc()` call broke this: `.add(...)` became the outermost
    // call, so these were wrongly flagged again even though the receiver
    // is genuinely UTC.
    test('does NOT fire when .toUtc() is followed by .add(Duration)', () async {
      final codes = await reportedRuleCodes(PreferUtcForStorageRule(), '''
class Db {
  void insert(Object value) {}
}

void persist(Db db) {
  db.insert({
    't': DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
  });
}
''');
      expect(codes, isNot(contains('prefer_utc_for_storage')));
    });

    test(
      'does NOT fire when DateTime.utc(...) is followed by .subtract(Duration)',
      () async {
        final codes = await reportedRuleCodes(PreferUtcForStorageRule(), '''
class Db {
  void insert(Object value) {}
}

void persist(Db db) {
  db.insert({
    't': DateTime.utc(2020).subtract(const Duration(days: 1)).toIso8601String(),
  });
}
''');
        expect(codes, isNot(contains('prefer_utc_for_storage')));
      },
    );

    // Real positive: arithmetic recursion must stop at the first
    // non-add/subtract call. `.toUtc().add(...).toLocal()`'s OUTERMOST
    // form is `.toLocal()`, which is neither UTC nor UTC-preserving
    // arithmetic, so it must still fire.
    test(
      'still fires when .toUtc().add(...) is followed by .toLocal()',
      () async {
        final codes = await reportedRuleCodes(PreferUtcForStorageRule(), '''
class Db {
  void insert(Object value) {}
}

void persist(Db db) {
  db.insert({
    't': DateTime.now().toUtc().add(const Duration(days: 1)).toLocal().toIso8601String(),
  });
}
''');
        expect(codes, contains('prefer_utc_for_storage'));
      },
    );

    // Real positive: `copyWith` is NOT UTC-preserving (it can flip the
    // offset via an `isUtc:` argument), so arithmetic recursion must NOT
    // extend to it -- even though the receiver chain contains `.toUtc()`.
    test('still fires when .toUtc() is followed by .copyWith(...)', () async {
      final codes = await reportedRuleCodes(PreferUtcForStorageRule(), '''
class Db {
  void insert(Object value) {}
}

void persist(Db db) {
  db.insert({
    't': DateTime.now().toUtc().copyWith(year: 2025).toIso8601String(),
  });
}
''');
      expect(codes, contains('prefer_utc_for_storage'));
    });

    // Real positive: a look-alike user type whose name merely starts with
    // "DateTime" (`DateTimeBag`) must NOT be treated as UTC just because it
    // has same-named `.utc()`/`.add()` members. The "is this UTC" check
    // must resolve the real `dart:core.DateTime` element/library, not just
    // prefix-match the type's display string.
    test(
      'still fires on a look-alike DateTimeBag type with .utc()/.add()',
      () async {
        final codes = await reportedRuleCodes(PreferUtcForStorageRule(), '''
class DateTimeBag {
  DateTimeBag.utc(this.year);

  final int year;

  DateTimeBag add(Object duration) => this;

  String toIso8601String() => '\$year';
}

class Db {
  void insert(Object value) {}
}

void persist(Db db) {
  db.insert({
    't': DateTimeBag.utc(2020).add('x').toIso8601String(),
  });
}
''');
        expect(codes, contains('prefer_utc_for_storage'));
      },
    );
  });

  group('require_stream_error_handling', () {
    // Real positive: a genuine Stream.listen() without onError must fire.
    test('fires on Stream.listen() without onError', () async {
      final codes = await reportedRuleCodes(
        RequireStreamErrorHandlingRule(),
        '''
void sub(Stream<int> source) {
  source.listen((int data) {});
}
''',
      );
      expect(codes, contains('require_stream_error_handling'));
    });

    // THE BUG: animationController is NOT a Stream, but its name ends with
    // "controller", so the old name fallback flagged its (unrelated) listen()
    // for a missing onError -> false POSITIVE.
    test(
      'does NOT fire on a non-Stream object whose name ends in "controller"',
      () async {
        final codes = await reportedRuleCodes(
          RequireStreamErrorHandlingRule(),
          '''
class AnimationController {
  void listen(void Function() callback) {}
}

void run(AnimationController animationController) {
  animationController.listen(() {});
}
''',
        );
        expect(codes, isNot(contains('require_stream_error_handling')));
      },
    );

    // The `.stream` access signal must still fire even when the static type of
    // the `.stream` getter is unresolved, so the property-access fallback works.
    test('fires on a .stream access listen() without onError', () async {
      final codes = await reportedRuleCodes(
        RequireStreamErrorHandlingRule(),
        '''
class Bloc {
  Stream<int> get stream => const Stream<int>.empty();
}

void run(Bloc bloc) {
  bloc.stream.listen((int data) {});
}
''',
      );
      expect(codes, contains('require_stream_error_handling'));
    });
  });

  group('avoid_unassigned_stream_subscriptions', () {
    // Real positive: a bare stream.listen() expression statement fires.
    test('fires on an unassigned stream.listen() statement', () async {
      final codes = await reportedRuleCodes(
        AvoidUnassignedStreamSubscriptionsRule(),
        '''
void sub(Stream<int> source) {
  source.listen((int data) {});
}
''',
      );
      expect(codes, contains('avoid_unassigned_stream_subscriptions'));
    });

    // VERIFICATION of the audit claim that the rule "never checks the variable
    // type". It DOES require a Stream static type, so a non-Stream object whose
    // name ends in "stream" must NOT fire. If this passes, the claim is a
    // NON-ISSUE (no false positive on the name; the type guard is present).
    test('does NOT fire on a non-Stream object named like a stream', () async {
      final codes = await reportedRuleCodes(
        AvoidUnassignedStreamSubscriptionsRule(),
        '''
class EventStream {
  void listen(void Function(int) callback) {}
}

void run(EventStream upstream) {
  upstream.listen((int data) {});
}
''',
      );
      expect(codes, isNot(contains('avoid_unassigned_stream_subscriptions')));
    });
  });
}
