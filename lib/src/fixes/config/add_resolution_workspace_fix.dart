// ignore_for_file: depend_on_referenced_packages

import 'dart:io' show File;

import '../../native/saropa_fix.dart';
import '../../project_context.dart';

/// Regex to find the end of the `environment:` block in a pubspec.yaml.
/// Matches the `environment:` header line plus all subsequent indented lines
/// (the `sdk:` and optional `flutter:` sub-keys). Group 0 spans the entire
/// block so its end offset is the insertion point for `resolution: workspace`.
final RegExp _environmentBlockRe = RegExp(
  r'^environment\s*:[ \t]*\n(?:[ \t]+\S[^\n]*\n?)*',
  multiLine: true,
);

/// Quick fix: insert `resolution: workspace` as a top-level key in
/// pubspec.yaml for a package that is listed in a pub workspace but
/// missing the declaration.
///
/// Companion fix for [AddResolutionWorkspaceRule]. Edits pubspec.yaml
/// rather than the Dart source file — uses [ChangeBuilder.addGenericFileEdit]
/// following the same pattern as [RaiseSdkLowerBoundFix].
///
/// Inserts after the `environment:` block when present, or at end of file
/// otherwise. The line `resolution: workspace\n` is a top-level YAML key,
/// sibling to `name:`, `environment:`, and `dependencies:`.
class AddResolutionWorkspaceFix extends SaropaFixProducer {
  AddResolutionWorkspaceFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addResolutionWorkspace',
    40,
    'Add resolution: workspace to pubspec.yaml',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    // Find the project root (same lookup the rule uses).
    final root = ProjectContext.findProjectRoot(file);
    if (root == null) return;

    final pubspecPath = '$root/pubspec.yaml';
    final pubspecFile = File(pubspecPath);
    if (!pubspecFile.existsSync()) return;

    final content = pubspecFile.readAsStringSync();

    // Determine where to insert: after the environment: block if it exists,
    // otherwise at end of file with a leading newline.
    final envMatch = _environmentBlockRe.firstMatch(content);
    final int insertOffset;
    final String insertText;

    if (envMatch != null) {
      // Insert immediately after the environment: block.
      insertOffset = envMatch.end;
      insertText = 'resolution: workspace\n';
    } else {
      // No environment: block found — append at end of file.
      insertOffset = content.length;
      // Ensure a blank line separator before the new key.
      final needsNewline = content.isNotEmpty && !content.endsWith('\n');
      insertText =
          '${needsNewline ? '\n' : ''}resolution: workspace\n';
    }

    // Insert the resolution: workspace line into pubspec.yaml.
    await builder.addGenericFileEdit(pubspecPath, (editBuilder) {
      editBuilder.addSimpleInsertion(insertOffset, insertText);
    });
  }
}
