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
    test('does NOT fire when context.mounted guards the pop (control)', () async {
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
    });

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
    test('does NOT fire on a UI label when an unrelated save() is in scope', () async {
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
    });
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
    test('does NOT fire on a non-Stream object whose name ends in "controller"', () async {
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
    });

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
