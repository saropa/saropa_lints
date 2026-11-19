// Resolved-analyzer tests for `avoid_unused_assignment`.
//
// Runs the rule against inline fixture source with full type resolution,
// validating that:
// - A same-invocation dead write (assigned, then overwritten before any
//   read) fires (BAD). Note: the rule's `_AssignmentUsageVisitor` only
//   records `AssignmentExpression` nodes, not variable-declaration
//   initializers, so the flagged pair must be two plain reassignments —
//   `var x = 0; x = 1; x = 2;` (with the *first* reassignment flagged), not
//   `var x = 1; x = 2;` (only one recorded assignment, can't compare).
// - A write read afterward does NOT fire (GOOD)
// - A closure-captured variable that a closure both reads and resets for
//   its OWN next invocation (called repeatedly from a loop) does NOT fire,
//   even when an unrelated write to the same variable name appears later
//   in the enclosing block's source order (regression for the false
//   positive where nested-closure assignments were merged into the outer
//   block's flat, source-ordered assignment list)
//
// Uses `assertFixtureMarkers` for declarative marker-driven assertions.
library;

import 'package:saropa_lints/src/rules/code_quality/code_quality_variables_rules.dart';
import 'package:test/test.dart';

import '../../support/fixture_message_harness.dart';

void main() {
  group('AvoidUnusedAssignmentRule - resolved', () {
    final rule = AvoidUnusedAssignmentRule();

    test('fires on a same-invocation dead write', () async {
      await assertFixtureMarkers(rule, '''
void f() {
  var count = 0;
  // LINT: avoid_unused_assignment
  count = 1; // never read before being overwritten below
  count = 2;
}
''');
    });

    test('does NOT fire when the write is read afterward', () async {
      await assertFixtureMarkers(rule, '''
void f() {
  var count = 1;
  // LINT_NOT: avoid_unused_assignment
  count = 2;
  print(count);
}
''');
    });

    // Regression for the false-positive bug report: `endField()` is a local
    // closure invoked repeatedly from the `while` loop. Its own
    // `fieldWasQuoted = false;` resets state for the closure's NEXT
    // invocation (read via the ternary on the next call), not for the
    // unrelated `fieldWasQuoted = true;` write inside the loop below it.
    test('does NOT fire on closure-captured variable reset read by the '
        'closure\'s own next invocation', () async {
      await assertFixtureMarkers(rule, '''
List<String> f(String csv) {
  final row = <String>[];
  var fieldWasQuoted = false;

  void endField() {
    row.add(fieldWasQuoted ? 'quoted' : 'plain');
    // LINT_NOT: avoid_unused_assignment
    fieldWasQuoted = false;
  }

  var i = 0;
  while (i < csv.length) {
    if (csv[i] == '"') {
      fieldWasQuoted = true;
    } else if (csv[i] == ',') {
      endField();
    }
    i++;
  }
  return row;
}
''');
    });

    // Contrasting case from the report's "Fixture Gap" section: a genuine
    // same-invocation dead write INSIDE a closure must still fire — the
    // nested-function boundary must not over-suppress real dead writes.
    test(
      'fires on a genuinely dead write inside a closure (same invocation)',
      () async {
        await assertFixtureMarkers(rule, '''
void f() {
  void inner() {
    var total = 0;
    // LINT: avoid_unused_assignment
    total = 1; // never read before being overwritten below
    total = 2;
  }

  inner();
}
''');
      },
    );
  });
}
