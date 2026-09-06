/// Pure-function tests for the pubspec version-constraint parser and
/// workspace-resolution helpers.
///
/// The five constraint-reviewer rules in `pubspec_constraint_rules.dart` are
/// thin wrappers over [parseConstraint] / [parsePubspecConstraints], so testing
/// the parser directly exercises the real decision logic (the rules themselves
/// can only be checked through the scan CLI, since custom_lint analyzes `.dart`,
/// not `.yaml`). Both positive (violating) and negative (compliant) shapes are
/// covered so the parser cannot regress to a defensive empty-result stub.
///
/// The workspace groups cover [resolutionWorkspaceRe] (detection regex) and
/// [ProjectContext.getWorkspaceMembers] / [ProjectContext.getWorkspaceRoot]
/// (workspace parsing and membership detection) with both block- and flow-style
/// YAML, including edge cases that have caused false positives in practice.
library;

import 'dart:io' show Directory, File;

import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/config/pubspec_constraint_parser.dart';
import 'package:saropa_lints/src/fixes/config/add_resolution_workspace_fix.dart'
    show resolutionWorkspaceRe;
import 'package:test/test.dart';

void main() {
  // The five constraint rules can only fire through the scan CLI (they target
  // .yaml, not .dart), so this group pins their metadata — name, prefixed
  // problem message, correction message — the way every other category test
  // does. Behavioral coverage lives in the parser groups below.
  group('Pubspec Constraint - Rule Instantiation', () {
    void expectMetadata(SaropaLintRule rule, String name) {
      expect(rule.code.lowerCaseName, name);
      expect(rule.code.problemMessage, contains('[$name]'));
      // Project convention: problem messages exceed 200 chars.
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    }

    test('RequireSdkUpperBoundRule reports correct name and messages', () {
      expectMetadata(RequireSdkUpperBoundRule(), 'require_sdk_upper_bound');
    });
    test('AvoidUnboundedDependencyRule reports correct name and messages', () {
      expectMetadata(
        AvoidUnboundedDependencyRule(),
        'avoid_unbounded_dependency',
      );
    });
    test(
      'RequireDependencyLowerBoundRule reports correct name and messages',
      () {
        expectMetadata(
          RequireDependencyLowerBoundRule(),
          'require_dependency_lower_bound',
        );
      },
    );
    test(
      'PreferCaretConstraintInAppRule reports correct name and messages',
      () {
        expectMetadata(
          PreferCaretConstraintInAppRule(),
          'prefer_caret_constraint_in_app',
        );
      },
    );
    test(
      'AvoidOverlyWideAppConstraintRule reports correct name and messages',
      () {
        expectMetadata(
          AvoidOverlyWideAppConstraintRule(),
          'avoid_overly_wide_app_constraint',
        );
      },
    );
    test('RequireSdkSyntaxMatchRule reports correct name and messages', () {
      expectMetadata(RequireSdkSyntaxMatchRule(), 'require_sdk_syntax_match');
    });
    test('AddResolutionWorkspaceRule reports correct name and messages', () {
      expectMetadata(
        AddResolutionWorkspaceRule(),
        'add_resolution_workspace',
      );
    });
    test(
      'FlagMissingWorkspaceMemberRule reports correct name and messages',
      () {
        expectMetadata(
          FlagMissingWorkspaceMemberRule(),
          'flag_missing_workspace_member',
        );
      },
    );
    test(
      'WorkspaceDependencyVersionSyncRule reports correct name and messages',
      () {
        expectMetadata(
          WorkspaceDependencyVersionSyncRule(),
          'workspace_dependency_version_sync',
        );
      },
    );
    test(
      'WorkspaceMemberOrderRule reports correct name and messages',
      () {
        expectMetadata(
          WorkspaceMemberOrderRule(),
          'workspace_member_order',
        );
      },
    );
    test(
      'AvoidDependencyOverridesRule reports correct name and messages',
      () {
        expectMetadata(
          AvoidDependencyOverridesRule(),
          'avoid_dependency_overrides',
        );
      },
    );
    test(
      'PreferPinnedVersionSyntaxRule reports correct name and messages',
      () {
        expectMetadata(
          PreferPinnedVersionSyntaxRule(),
          'prefer_pinned_version_syntax',
        );
      },
    );
    test(
      'PreferPublishToNoneRule reports correct name and messages',
      () {
        expectMetadata(
          PreferPublishToNoneRule(),
          'prefer_publish_to_none',
        );
      },
    );
  });

  group('parseConstraint', () {
    test('caret constraint has both bounds and a synthesized upper', () {
      final c = parseConstraint('^1.2.3');
      expect(c.isCaret, isTrue);
      expect(c.hasLower, isTrue);
      expect(c.hasUpper, isTrue);
      expect(c.lower?.major, 1);
      expect(c.upper?.major, 2);
      expect(c.upper?.minor, 0);
      expect(c.majorSpan, 1);
    });

    test('0.x caret stops at the next minor, not the next major', () {
      final c = parseConstraint('^0.2.3');
      expect(c.upper?.major, 0);
      expect(c.upper?.minor, 3);
      expect(c.majorSpan, 0);
    });

    test('explicit range parses both bounds', () {
      final c = parseConstraint('>=1.0.0 <2.0.0');
      expect(c.hasLower, isTrue);
      expect(c.hasUpper, isTrue);
      expect(c.lower?.major, 1);
      expect(c.upper?.major, 2);
      expect(c.majorSpan, 1);
    });

    test('lower-only range has no upper bound', () {
      final c = parseConstraint('>=3.0.0');
      expect(c.hasLower, isTrue);
      expect(c.hasUpper, isFalse);
      expect(c.majorSpan, isNull);
    });

    test('upper-only range has no lower bound', () {
      final c = parseConstraint('<2.0.0');
      expect(c.hasLower, isFalse);
      expect(c.hasUpper, isTrue);
    });

    test('any constraint is flagged as unbounded', () {
      final c = parseConstraint('any');
      expect(c.isAny, isTrue);
      expect(c.hasLower, isFalse);
      expect(c.hasUpper, isFalse);
    });

    test('exact pin bounds both ends at the same version', () {
      final c = parseConstraint('1.2.3');
      expect(c.hasLower, isTrue);
      expect(c.hasUpper, isTrue);
      expect(c.lower?.patch, 3);
      expect(c.upper?.patch, 3);
    });

    test('empty value is treated as a block (git/path/sdk follows)', () {
      final c = parseConstraint('');
      expect(c.isBlock, isTrue);
    });

    test('quotes and trailing comments are stripped', () {
      final c = parseConstraint('">=1.0.0 <2.0.0"  # pinned for CI');
      expect(c.lower?.major, 1);
      expect(c.upper?.major, 2);
    });

    test('caret-equivalent range is detected for 1.x', () {
      expect(parseConstraint('>=1.2.3 <2.0.0').isCaretEquivalentRange, isTrue);
      expect(parseConstraint('>=1.2.3 <3.0.0').isCaretEquivalentRange, isFalse);
      // A real caret is not "equivalent to a caret" — it already is one.
      expect(parseConstraint('^1.2.3').isCaretEquivalentRange, isFalse);
    });

    test('caret-equivalent range is detected for 0.x', () {
      expect(parseConstraint('>=0.2.3 <0.3.0').isCaretEquivalentRange, isTrue);
      expect(parseConstraint('>=0.2.3 <0.4.0').isCaretEquivalentRange, isFalse);
    });

    test('wide range spanning multiple majors reports a large span', () {
      expect(parseConstraint('>=1.0.0 <4.0.0').majorSpan, 3);
      expect(parseConstraint('>=1.0.0 <3.0.0').majorSpan, 2);
    });
  });

  group('parsePubspecConstraints', () {
    const appPubspec = '''
name: my_app
publish_to: none

environment:
  sdk: ">=3.0.0"

dependencies:
  flutter:
    sdk: flutter
  http: any
  collection: ">=1.0.0 <4.0.0"
  args: ">=2.0.0 <3.0.0"
  meta: "<2.0.0"

dev_dependencies:
  test: ^1.24.0
''';

    test('detects an application from publish_to: none', () {
      expect(parsePubspecConstraints(appPubspec).isApp, isTrue);
    });

    test('a published package (no publish_to) is not an app', () {
      const pkg = 'name: my_pkg\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\n';
      expect(parsePubspecConstraints(pkg).isApp, isFalse);
    });

    test('captures the SDK constraint and its missing upper bound', () {
      final sdk = parsePubspecConstraints(appPubspec).sdkConstraint;
      expect(sdk, isNotNull);
      expect(sdk!.hasLower, isTrue);
      expect(sdk.hasUpper, isFalse);
    });

    test('skips block dependencies and the flutter SDK marker', () {
      final deps = parsePubspecConstraints(appPubspec).dependencies;
      final names = deps.map((d) => d.name).toList();
      expect(names, isNot(contains('flutter')));
      expect(
        names,
        containsAll(<String>['http', 'collection', 'args', 'meta']),
      );
    });

    test('collects inline constraints across dependency sections', () {
      final deps = parsePubspecConstraints(appPubspec).dependencies;
      final names = deps.map((d) => d.name).toList();
      // dev_dependencies entries are included alongside dependencies.
      expect(names, contains('test'));
    });

    test('finds the unbounded, wide, and upper-only offenders', () {
      final deps = parsePubspecConstraints(appPubspec).dependencies;
      final byName = {for (final d in deps) d.name: d.constraint};
      expect(byName['http']!.isAny, isTrue);
      expect(byName['collection']!.majorSpan, 3);
      expect(byName['meta']!.hasLower, isFalse);
      expect(byName['meta']!.hasUpper, isTrue);
      // A normal caret-equivalent range that is not over-wide.
      expect(byName['args']!.isCaretEquivalentRange, isTrue);
    });

    test('a clean package pubspec yields no offenders', () {
      const clean = '''
name: clean_pkg
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  http: ^1.2.0
  collection: ^1.19.0
''';
      final parsed = parsePubspecConstraints(clean);
      expect(parsed.sdkConstraint!.hasUpper, isTrue);
      expect(parsed.dependencies.every((d) => !d.constraint.isAny), isTrue);
      expect(
        parsed.dependencies.every((d) => (d.constraint.majorSpan ?? 0) < 2),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // findDivergentDependencyConstraints — the pure comparison logic behind
  // workspace_dependency_version_sync. The rule itself only adds file I/O
  // (reading each member's pubspec.yaml) around this function, so exercising
  // it directly is the real behavioral coverage for that rule (it can only be
  // fired end-to-end through the scan CLI, since it targets a workspace root's
  // .dart file, not .yaml content).
  // ---------------------------------------------------------------------------
  group('findDivergentDependencyConstraints', () {
    test('flags a dependency with different constraints across members', () {
      const memberA = '''
name: foo
dependencies:
  http: ^1.2.0
''';
      const memberB = '''
name: bar
dependencies:
  http: ^0.13.0
''';
      final divergent = findDivergentDependencyConstraints([memberA, memberB]);
      expect(divergent, containsPair('http', {'^1.2.0', '^0.13.0'}));
    });

    test('does not flag a dependency declared identically everywhere', () {
      const memberA = '''
name: foo
dependencies:
  http: ^1.2.0
''';
      const memberB = '''
name: bar
dependencies:
  http: ^1.2.0
''';
      final divergent = findDivergentDependencyConstraints([memberA, memberB]);
      expect(divergent, isEmpty);
    });

    test('does not flag a dependency used by only one member', () {
      // Nothing to diverge from when only one member declares it at all.
      const memberA = '''
name: foo
dependencies:
  http: ^1.2.0
''';
      const memberB = '''
name: bar
dependencies:
  collection: ^1.19.0
''';
      final divergent = findDivergentDependencyConstraints([memberA, memberB]);
      expect(divergent, isEmpty);
    });

    test('skips block dependencies (git/path/sdk) entirely', () {
      // Two members point the same package name at different git refs —
      // block entries carry no comparable version string, so this must not
      // be treated as a divergent constraint.
      const memberA = '''
name: foo
dependencies:
  shared_pkg:
    git:
      url: https://example.com/shared_pkg.git
      ref: main
''';
      const memberB = '''
name: bar
dependencies:
  shared_pkg:
    path: ../shared_pkg
''';
      final divergent = findDivergentDependencyConstraints([memberA, memberB]);
      expect(divergent, isEmpty);
    });

    test('returns empty for no members (empty workspace)', () {
      expect(findDivergentDependencyConstraints(const <String>[]), isEmpty);
    });

    test('reports only the offending dependency among several shared ones', () {
      // args agrees across members; http diverges. Only http should surface.
      const memberA = '''
name: foo
dependencies:
  args: ^2.0.0
  http: ^1.2.0
''';
      const memberB = '''
name: bar
dependencies:
  args: ^2.0.0
  http: ^1.5.0
''';
      final divergent = findDivergentDependencyConstraints([memberA, memberB]);
      expect(divergent.keys, ['http']);
      expect(divergent['http'], {'^1.2.0', '^1.5.0'});
    });

    test('collects three distinct constraints across three members', () {
      const memberA = 'name: a\ndependencies:\n  http: ^1.0.0\n';
      const memberB = 'name: b\ndependencies:\n  http: ^1.1.0\n';
      const memberC = 'name: c\ndependencies:\n  http: ^1.2.0\n';
      final divergent = findDivergentDependencyConstraints([
        memberA,
        memberB,
        memberC,
      ]);
      expect(divergent['http'], {'^1.0.0', '^1.1.0', '^1.2.0'});
    });
  });

  // ---------------------------------------------------------------------------
  // Workspace resolution regex — tests the shared resolutionWorkspaceRe that
  // both AddResolutionWorkspaceRule and AddResolutionWorkspaceFix use.
  // ---------------------------------------------------------------------------
  group('resolutionWorkspaceRe', () {
    test('matches bare workspace at column 0', () {
      expect(resolutionWorkspaceRe.hasMatch('resolution: workspace'), isTrue);
    });

    test('matches with trailing whitespace', () {
      expect(
        resolutionWorkspaceRe.hasMatch('resolution: workspace   '),
        isTrue,
      );
    });

    test('matches with trailing YAML comment', () {
      expect(
        resolutionWorkspaceRe.hasMatch('resolution: workspace # pub'),
        isTrue,
      );
    });

    test('matches double-quoted workspace', () {
      expect(
        resolutionWorkspaceRe.hasMatch('resolution: "workspace"'),
        isTrue,
      );
    });

    test('matches single-quoted workspace', () {
      expect(
        resolutionWorkspaceRe.hasMatch("resolution: 'workspace'"),
        isTrue,
      );
    });

    test('does not match indented line (not top-level)', () {
      // Indented resolution: is a YAML value inside another mapping, not a
      // top-level key — must not match.
      expect(
        resolutionWorkspaceRe.hasMatch('  resolution: workspace'),
        isFalse,
      );
    });

    test('does not match a different resolution value', () {
      expect(
        resolutionWorkspaceRe.hasMatch('resolution: local'),
        isFalse,
      );
    });

    test('does not match mismatched quotes', () {
      // "workspace' and 'workspace" are not valid YAML — the regex must
      // require matching pairs.
      expect(
        resolutionWorkspaceRe.hasMatch('resolution: "workspace\''),
        isFalse,
      );
      expect(
        resolutionWorkspaceRe.hasMatch("resolution: 'workspace\""),
        isFalse,
      );
    });

    test('matches inside a multi-line pubspec', () {
      const pubspec = '''
name: foo
environment:
  sdk: ^3.6.0
resolution: workspace
dependencies:
  bar: ^1.0.0
''';
      expect(resolutionWorkspaceRe.hasMatch(pubspec), isTrue);
    });

    test('does not match when resolution key is absent', () {
      const pubspec = '''
name: foo
environment:
  sdk: ^3.6.0
''';
      expect(resolutionWorkspaceRe.hasMatch(pubspec), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Workspace member parsing — exercises _parseWorkspaceEntries indirectly
  // through the public getWorkspaceMembers API. Covers block-style, flow-style,
  // comments, and edge cases.
  // ---------------------------------------------------------------------------
  group('getWorkspaceMembers', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('workspace_test_');
    });

    tearDown(() {
      // Clear the project context cache between tests so stale entries from
      // previous temp dirs don't interfere.
      ProjectContext.clearCache();
      tmpDir.deleteSync(recursive: true);
    });

    /// Helper: write a pubspec.yaml at the given root path with the specified
    /// content, then call getWorkspaceMembers.
    List<String> membersFrom(String pubspecContent) {
      File('${tmpDir.path}/pubspec.yaml')
          .writeAsStringSync(pubspecContent);
      return ProjectContext.getWorkspaceMembers(tmpDir.path);
    }

    test('parses block-style workspace list', () {
      final members = membersFrom('''
name: monorepo
workspace:
  - packages/foo
  - packages/bar
''');
      expect(members, ['packages/foo', 'packages/bar']);
    });

    test('parses flow-style workspace list', () {
      final members = membersFrom('''
name: monorepo
workspace: [packages/foo, packages/bar]
''');
      expect(members, ['packages/foo', 'packages/bar']);
    });

    test('tolerates column-0 comments inside workspace block', () {
      // Column-0 comments must not terminate the block — they are valid YAML.
      final members = membersFrom('''
name: monorepo
workspace:
  - packages/foo
# This is a comment at column 0
  - packages/bar
''');
      expect(members, ['packages/foo', 'packages/bar']);
    });

    test('returns empty list when no workspace key exists', () {
      final members = membersFrom('''
name: standalone
environment:
  sdk: ^3.6.0
''');
      expect(members, isEmpty);
    });

    test('returns empty list when workspace list is empty', () {
      final members = membersFrom('''
name: monorepo
workspace:
dependencies:
  foo: ^1.0.0
''');
      expect(members, isEmpty);
    });

    test('stops block at next top-level key', () {
      // The workspace block ends at the next non-indented, non-comment line.
      final members = membersFrom('''
name: monorepo
workspace:
  - packages/foo
environment:
  sdk: ^3.6.0
''');
      expect(members, ['packages/foo']);
    });

    test('returns null root for nonexistent directory', () {
      final members = ProjectContext.getWorkspaceMembers(
        '${tmpDir.path}/nonexistent',
      );
      expect(members, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Workspace root detection — exercises getWorkspaceRoot with real temp
  // directory trees. Tests the ancestor walk, membership matching, and the
  // stop-at-first-ancestor guard that prevents example/ false positives.
  // ---------------------------------------------------------------------------
  group('getWorkspaceRoot', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('ws_root_test_');
    });

    tearDown(() {
      ProjectContext.clearCache();
      tmpDir.deleteSync(recursive: true);
    });

    test('finds workspace root when package is a listed member', () {
      // Create workspace root with pubspec listing packages/foo.
      File('${tmpDir.path}/pubspec.yaml').writeAsStringSync('''
name: monorepo
workspace:
  - packages/foo
''');
      // Create the member package's pubspec.
      final memberDir = Directory('${tmpDir.path}/packages/foo');
      memberDir.createSync(recursive: true);
      File('${memberDir.path}/pubspec.yaml').writeAsStringSync('''
name: foo
environment:
  sdk: ^3.6.0
''');

      final root = ProjectContext.getWorkspaceRoot(memberDir.path);
      expect(root, isNotNull);
    });

    test('returns null when package is not listed', () {
      // Create workspace root listing packages/foo but not packages/bar.
      File('${tmpDir.path}/pubspec.yaml').writeAsStringSync('''
name: monorepo
workspace:
  - packages/foo
''');
      final memberDir = Directory('${tmpDir.path}/packages/bar');
      memberDir.createSync(recursive: true);
      File('${memberDir.path}/pubspec.yaml').writeAsStringSync('''
name: bar
''');

      final root = ProjectContext.getWorkspaceRoot(memberDir.path);
      expect(root, isNull);
    });

    test('returns null when ancestor has no workspace key', () {
      // Ancestor pubspec exists but has no workspace: key — walk should stop
      // at the first ancestor, not continue searching further up.
      File('${tmpDir.path}/pubspec.yaml').writeAsStringSync('''
name: parent
environment:
  sdk: ^3.6.0
''');
      final memberDir = Directory('${tmpDir.path}/packages/foo');
      memberDir.createSync(recursive: true);
      File('${memberDir.path}/pubspec.yaml').writeAsStringSync('''
name: foo
''');

      final root = ProjectContext.getWorkspaceRoot(memberDir.path);
      expect(root, isNull);
    });

    test('stops at nearest ancestor — prevents example/ false positive', () {
      // Grand-workspace at tmpDir, member packages/foo, and a nested
      // packages/foo/example/ that should NOT resolve to the grand-workspace.
      File('${tmpDir.path}/pubspec.yaml').writeAsStringSync('''
name: monorepo
workspace:
  - packages/foo
  - packages/foo/example
''');
      final memberDir = Directory('${tmpDir.path}/packages/foo');
      memberDir.createSync(recursive: true);
      File('${memberDir.path}/pubspec.yaml').writeAsStringSync('''
name: foo
environment:
  sdk: ^3.6.0
''');
      // example/ sits UNDER foo, so its nearest ancestor pubspec is foo's,
      // which has no workspace: key — walk must stop there.
      final exampleDir = Directory('${memberDir.path}/example');
      exampleDir.createSync(recursive: true);
      File('${exampleDir.path}/pubspec.yaml').writeAsStringSync('''
name: foo_example
''');

      final root = ProjectContext.getWorkspaceRoot(exampleDir.path);
      // Must be null because the walk stops at packages/foo/pubspec.yaml
      // (no workspace: key), not at the grand-workspace root.
      expect(root, isNull);
    });

    test('matches case-insensitively on Windows', () {
      // On Windows, filesystem paths are case-insensitive. The workspace
      // entry might use different casing than the actual directory path.
      File('${tmpDir.path}/pubspec.yaml').writeAsStringSync('''
name: monorepo
workspace:
  - Packages/Foo
''');
      final memberDir = Directory('${tmpDir.path}/packages/foo');
      memberDir.createSync(recursive: true);
      File('${memberDir.path}/pubspec.yaml').writeAsStringSync('''
name: foo
''');

      final root = ProjectContext.getWorkspaceRoot(memberDir.path);
      if (ProjectContext.isCaseInsensitiveFs) {
        // Case-insensitive match on Windows and macOS (default APFS).
        expect(root, isNotNull);
      } else {
        // Case-sensitive on Linux — Packages/Foo != packages/foo.
        expect(root, isNull);
      }
    });

    test('returns null for null or empty input', () {
      expect(ProjectContext.getWorkspaceRoot(null), isNull);
      expect(ProjectContext.getWorkspaceRoot(''), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // canonicalRelativePath — public path normalization helper used by workspace
  // rules to ensure consistent member-path comparison.
  // ---------------------------------------------------------------------------
  group('canonicalRelativePath', () {
    test('normalizes backslashes to forward slashes', () {
      expect(
        ProjectContext.canonicalRelativePath(r'packages\foo\bar'),
        'packages/foo/bar',
      );
    });

    test('strips leading ./ prefix', () {
      expect(
        ProjectContext.canonicalRelativePath('./packages/foo'),
        'packages/foo',
      );
    });

    test('strips trailing /', () {
      expect(
        ProjectContext.canonicalRelativePath('packages/foo/'),
        'packages/foo',
      );
    });

    test('handles all normalizations together', () {
      expect(
        ProjectContext.canonicalRelativePath(r'.\packages\foo\'),
        'packages/foo',
      );
    });

    test('returns empty string for empty input', () {
      expect(ProjectContext.canonicalRelativePath(''), isEmpty);
    });

    test('preserves simple paths unchanged', () {
      expect(
        ProjectContext.canonicalRelativePath('packages/foo'),
        'packages/foo',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // hasDependencyOverridesEntries — the pure decision logic behind
  // avoid_dependency_overrides. An empty section (no children, or `{}`) must
  // NOT flag: nothing is actually being overridden in that case, so flagging
  // it would be a false positive on a pubspec that merely has a leftover
  // empty header.
  // ---------------------------------------------------------------------------
  group('hasDependencyOverridesEntries', () {
    test('non-empty dependency_overrides section is flagged', () {
      const pubspec = '''
name: my_pkg
dependencies:
  http: ^1.2.0
dependency_overrides:
  http: ^1.0.0
''';
      final parsed = parsePubspecConstraints(pubspec);
      expect(hasDependencyOverridesEntries(parsed), isTrue);
    });

    test('no dependency_overrides section at all is not flagged', () {
      const pubspec = '''
name: my_pkg
dependencies:
  http: ^1.2.0
''';
      final parsed = parsePubspecConstraints(pubspec);
      expect(hasDependencyOverridesEntries(parsed), isFalse);
    });

    test('dependency_overrides header with no children is not flagged', () {
      const pubspec = '''
name: my_pkg
dependencies:
  http: ^1.2.0
dependency_overrides:
dev_dependencies:
  test: ^1.24.0
''';
      final parsed = parsePubspecConstraints(pubspec);
      expect(hasDependencyOverridesEntries(parsed), isFalse);
    });

    test('empty flow-map dependency_overrides: {} is not flagged', () {
      const pubspec = '''
name: my_pkg
dependencies:
  http: ^1.2.0
dependency_overrides: {}
''';
      final parsed = parsePubspecConstraints(pubspec);
      expect(hasDependencyOverridesEntries(parsed), isFalse);
    });

    test('path override entry is flagged', () {
      const pubspec = '''
name: my_pkg
dependencies:
  http: ^1.2.0
dependency_overrides:
  http:
    path: ../http
''';
      final parsed = parsePubspecConstraints(pubspec);
      expect(hasDependencyOverridesEntries(parsed), isTrue);
    });

    test('git override entry is flagged', () {
      const pubspec = '''
name: my_pkg
dependencies:
  http: ^1.2.0
dependency_overrides:
  http:
    git:
      url: https://github.com/dart-lang/http.git
      ref: main
''';
      final parsed = parsePubspecConstraints(pubspec);
      expect(hasDependencyOverridesEntries(parsed), isTrue);
    });
  });

  // Behavioral coverage for `prefer_pinned_version_syntax` (the deliberate
  // stylistic opposite of `prefer_caret_constraint_in_app`): fires only for
  // apps (publish_to: none) that have at least one caret-syntax dependency.
  group('hasCaretDependenciesInApp', () {
    test('app with a caret dependency is flagged', () {
      const pubspec = '''
name: my_app
publish_to: none
dependencies:
  http: ^1.2.3
''';
      final parsed = parsePubspecConstraints(pubspec);
      expect(hasCaretDependenciesInApp(parsed), isTrue);
    });

    test('app with only an exact-pinned dependency is not flagged', () {
      const pubspec = '''
name: my_app
publish_to: none
dependencies:
  http: 1.2.3
''';
      final parsed = parsePubspecConstraints(pubspec);
      expect(hasCaretDependenciesInApp(parsed), isFalse);
    });

    test('non-app (published package) with caret deps is not flagged', () {
      // No `publish_to: none` — this is a publishable package, which needs
      // caret ranges for consumer compatibility, so the rule stays silent.
      const pubspec = '''
name: my_package
dependencies:
  http: ^1.2.3
''';
      final parsed = parsePubspecConstraints(pubspec);
      expect(hasCaretDependenciesInApp(parsed), isFalse);
    });

    test('app with mixed caret and exact deps is flagged', () {
      const pubspec = '''
name: my_app
publish_to: none
dependencies:
  http: ^1.2.3
  path: 1.9.0
''';
      final parsed = parsePubspecConstraints(pubspec);
      expect(hasCaretDependenciesInApp(parsed), isTrue);
    });

    test('app with no dependencies is not flagged', () {
      const pubspec = '''
name: my_app
publish_to: none
''';
      final parsed = parsePubspecConstraints(pubspec);
      expect(hasCaretDependenciesInApp(parsed), isFalse);
    });

    test('app with an unbounded "any" dependency is not flagged', () {
      // `any` has no caret syntax to pin — this is avoid_unbounded_dependency's
      // concern, not prefer_pinned_version_syntax's.
      const pubspec = '''
name: my_app
publish_to: none
dependencies:
  http: any
''';
      final parsed = parsePubspecConstraints(pubspec);
      expect(hasCaretDependenciesInApp(parsed), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // shouldFlagMissingPublishToNone — prefer_publish_to_none's decision logic.
  // ---------------------------------------------------------------------------
  group('shouldFlagMissingPublishToNone', () {
    test(
      'flags a pubspec with no publish_to and no homepage/repository',
      () {
        const pubspec = '''
name: my_app
environment:
  sdk: ^3.6.0
''';
        final parsed = parsePubspecConstraints(pubspec);
        expect(shouldFlagMissingPublishToNone(parsed), isTrue);
      },
    );

    test('does not flag a pubspec with publish_to: none', () {
      const pubspec = '''
name: my_app
publish_to: none
''';
      final parsed = parsePubspecConstraints(pubspec);
      expect(shouldFlagMissingPublishToNone(parsed), isFalse);
    });

    test(
      'does not flag a pubspec with publish_to set to a custom server',
      () {
        const pubspec = '''
name: my_package
publish_to: https://custom.server
''';
        final parsed = parsePubspecConstraints(pubspec);
        expect(shouldFlagMissingPublishToNone(parsed), isFalse);
      },
    );

    test(
      'does not flag a pubspec with no publish_to but full publish metadata '
      '(likely a library)',
      () {
        const pubspec = '''
name: my_package
homepage: https://example.com/my_package
repository: https://github.com/example/my_package
''';
        final parsed = parsePubspecConstraints(pubspec);
        expect(shouldFlagMissingPublishToNone(parsed), isFalse);
      },
    );

    test(
      'flags a pubspec with homepage but no repository (incomplete metadata)',
      () {
        const pubspec = '''
name: my_package
homepage: https://example.com/my_package
''';
        final parsed = parsePubspecConstraints(pubspec);
        expect(shouldFlagMissingPublishToNone(parsed), isTrue);
      },
    );

    test('flags a bare pubspec with only a name field', () {
      const pubspec = '''
name: my_app
''';
      final parsed = parsePubspecConstraints(pubspec);
      expect(shouldFlagMissingPublishToNone(parsed), isTrue);
    });
  });
}
