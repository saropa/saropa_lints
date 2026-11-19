/// Integrity tests for `lib/src/config/rule_renames.json`, the registry of
/// renamed or removed rules (`new` is null for a removed rule).
library;

import 'dart:convert';
import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

List<int> _version(String v) =>
    v.split('.').map((p) => int.parse(p.split(RegExp('[-+]')).first)).toList();

int _compare(String a, String b) {
  final x = _version(a), y = _version(b);
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return 0;
}

void main() {
  final decoded =
      jsonDecode(File('lib/src/config/rule_renames.json').readAsStringSync())
          as Map<String, dynamic>;
  final renames = (decoded['renames'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final live = getAllDefinedRules();
  final changelog = File('CHANGELOG.md').readAsStringSync();

  test('registry has version 1 and entries', () {
    expect(decoded['version'], 1);
    expect(renames, isNotEmpty);
  });

  test('every non-null new name is a live rule', () {
    final bad = [
      for (final r in renames)
        if (r['new'] != null && !live.contains(r['new'])) r['new'],
    ];
    expect(bad, isEmpty, reason: 'renamed-to rules not in tiers.dart');
  });

  test('no old name is a live rule', () {
    final bad = [
      for (final r in renames)
        if (live.contains(r['old'])) r['old'],
    ];
    expect(bad, isEmpty, reason: 'old names must not be registered');
  });

  test('no rename chain loops', () {
    final next = {for (final r in renames) r['old'] as String: r['new']};
    for (final start in next.keys) {
      final seen = <String>{start};
      var cur = next[start];
      while (cur != null && next.containsKey(cur)) {
        expect(seen.add(cur as String), isTrue, reason: 'loop at $start');
        cur = next[cur];
      }
    }
  });

  test('since is not later than the package version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    var current = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1)!;
    final unreleased = RegExp(
      r'^## \[(\d+\.\d+\.\d+)\]',
      multiLine: true,
    ).allMatches(changelog).map((m) => m.group(1)!);
    for (final v in unreleased) {
      if (_compare(v, current) > 0) current = v;
    }
    for (final r in renames) {
      expect(
        _compare(r['since'] as String, current) <= 0,
        isTrue,
        reason: '${r['old']} since ${r['since']} > $current',
      );
    }
  });

  test('each old name appears in CHANGELOG.md', () {
    final bad = [
      for (final r in renames)
        if (!changelog.contains(r['old'] as String)) r['old'],
    ];
    expect(bad, isEmpty);
  });
}
