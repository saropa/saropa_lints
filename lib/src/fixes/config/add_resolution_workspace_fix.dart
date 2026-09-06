// ignore_for_file: depend_on_referenced_packages

import 'dart:io' show File;

import '../../native/saropa_fix.dart';
import '../../project_context.dart';

/// Regex to detect a top-level `resolution: workspace` line in a pubspec.
/// Anchored to column 0 so indented YAML values (inside environment: etc.)
/// cannot match. Accepts bare `workspace` and quoted forms (`"workspace"`,
/// `'workspace'`) — the alternation requires matching pairs so `"workspace'`
/// does not slip through. Allows trailing whitespace and YAML comments.
/// Shared between [AddResolutionWorkspaceRule] and [AddResolutionWorkspaceFix].
final RegExp resolutionWorkspaceRe = RegExp(
  r'''^resolution:\s+(?:workspace|"workspace"|'workspace')\s*(?:#.*)?$''',
  multiLine: true,
);

/// Regex to find the end of the `environment:` block in a pubspec.yaml.
/// Matches the `environment:` header line plus all subsequent indented lines
/// (the `sdk:` and optional `flutter:` sub-keys). Tolerates blank or
/// whitespace-only continuation lines inside the block — a legal YAML style
/// choice that should not end the match early. Group 0 spans the entire
/// block so its end offset is the insertion point for `resolution: workspace`.
final RegExp _environmentBlockRe = RegExp(
  r'^environment\s*:[ \t]*\n(?:(?:[ \t]+\S[^\n]*|[ \t]*)\n)*',
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

    // Re-verify: if the pubspec already has `resolution: workspace`, bail out.
    // Guards against stale diagnostics (user edited pubspec since last analysis)
    // and "fix all" batch applies that would otherwise insert a duplicate key.
    if (resolutionWorkspaceRe.hasMatch(content)) return;

    // Determine where to insert: after the environment: block if it exists,
    // otherwise at end of file with a leading newline.
    final envMatch = _environmentBlockRe.firstMatch(content);
    final int insertOffset;
    final String insertText;

    if (envMatch != null) {
      // Insert immediately after the environment: block. If the matched block
      // does not end with a newline (e.g. environment: is the last content in
      // a file that lacks a trailing newline), prepend one to avoid corrupting
      // the previous line.
      insertOffset = envMatch.end;
      final matchedText = content.substring(envMatch.start, envMatch.end);
      final needsNewline = !matchedText.endsWith('\n');
      insertText = '${needsNewline ? '\n' : ''}resolution: workspace\n';
    } else {
      // No environment: block found — append at end of file.
      insertOffset = content.length;
      // Ensure a blank line separator before the new key.
      final needsNewline = content.isNotEmpty && !content.endsWith('\n');
      insertText = '${needsNewline ? '\n' : ''}resolution: workspace\n';
    }

    // Insert the resolution: workspace line into pubspec.yaml.
    await builder.addGenericFileEdit(pubspecPath, (editBuilder) {
      editBuilder.addSimpleInsertion(insertOffset, insertText);
    });
  }
}
