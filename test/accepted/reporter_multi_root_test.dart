// Drives a real rule through the reporter with two project roots active at
// once, the shape of one analysis server hosting several projects: accepted
// entries and baseline paths of one project must not hide the other's.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/accepted/accepted_findings_runtime.dart';
import 'package:saropa_lints/src/baseline/baseline_config.dart';
import 'package:saropa_lints/src/baseline/baseline_manager.dart';
import 'package:saropa_lints/src/project_context.dart' show ProjectContext;
import 'package:saropa_lints/src/rules/data/json_datetime_rules.dart';
import 'package:test/test.dart';

import '../support/resolved_rule_harness.dart';
import '../support/safe_delete.dart';

const String _rule = 'prefer_try_parse_for_dynamic_data';
const String _code = 'void f(String s) { int.parse(s); }';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('saropa_reporter_roots_');
    AcceptedFindingsRuntime.reset();
    BaselineManager.reset();
    ProjectContext.clearCache();
  });

  tearDown(() {
    AcceptedFindingsRuntime.reset();
    BaselineManager.reset();
    safeDeleteDir(dir);
  });

  /// Creates a package directory under the temp dir.
  Directory package(String name) {
    final root = Directory('${dir.path}/$name')..createSync();
    File('${root.path}/pubspec.yaml').writeAsStringSync('name: $name\n');
    return root;
  }

  /// Findings of the rule when [_code] is analyzed inside [root].
  Future<int> findings(Directory root) async => (await runRuleResolved(
    PreferTryParseForDynamicDataRule(),
    _code,
    projectRoot: root,
  )).length;

  test(
    'a baseline path entry hides findings in its own project only',
    () async {
      final a = package('a');
      final b = package('b');
      // The first rule run in an isolate triggers a one-time lazy config load,
      // which resets BaselineManager. Spend it before installing the reader,
      // or it wipes the reader (the real plugin reinstalls it itself).
      await findings(b);
      BaselineManager.enablePerRoot(
        // basename, not a string suffix: roots arrive in either slash style.
        (root) => p.basename(root) == 'a'
            ? const BaselineConfig(paths: <String>['lib/'])
            : null,
      );
      expect(await findings(a), 0);
      expect(await findings(b), 1);
      expect(await findings(a), 0);
    },
  );

  test('an accepted entry hides findings in its own project only', () async {
    final a = package('a');
    final b = package('b');
    // The harness names fixtures lib/__rule_harness__/h<pid>_<n>/, counting
    // from 0 per isolate; list every number this file can reach.
    final entries = StringBuffer('accepted:\n');
    for (int i = 0; i < 8; i++) {
      entries.write(
        '  - rule: $_rule\n'
        '    file: lib/__rule_harness__/h${pid}_$i/fixture.dart\n'
        '    reason: Test.\n',
      );
    }
    File('${a.path}/saropa_accepted.yaml').writeAsStringSync('$entries');
    AcceptedFindingsRuntime.enable();
    expect(await findings(a), 0);
    expect(await findings(b), 1);
  });
}
