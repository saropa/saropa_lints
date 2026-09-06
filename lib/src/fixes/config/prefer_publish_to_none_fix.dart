// ignore_for_file: depend_on_referenced_packages

import 'dart:io' show File;

import '../../native/saropa_fix.dart';
import '../../project_context.dart';

/// Any `publish_to:` key at column 0, whatever its value. Re-verified here
/// (rather than trusting the diagnostic that triggered the fix) because the
/// fix runs against whatever pubspec.yaml looks like NOW — the user may have
/// hand-added `publish_to:` since the last analysis pass, or the fix may be
/// invoked as part of a stale "fix all" batch. Requires a non-whitespace,
/// non-comment character after the colon so a bare `publish_to:` (no value
/// yet) does not count as already-decided — same reasoning as the parser's
/// private `_publishToAny` in pubspec_constraint_parser.dart, duplicated here
/// because that regex is private to the parser file.
final RegExp publishToAnyRe = RegExp(
  r'''^publish_to:[ \t]*[^\s#]''',
  multiLine: true,
);

/// Matches the `description:` key's header line plus any indented
/// continuation lines that follow it — covers both a single-line value
/// (`description: A thing.`) and a YAML block scalar (`description: |` /
/// `description: >` followed by indented body lines). Mirrors the
/// `environment:` block regex in add_resolution_workspace_fix.dart: matching
/// the whole block (not just the header line) means the insertion point
/// lands after the description's body, never in the middle of it.
final RegExp _descriptionBlockRe = RegExp(
  r'^description\s*:[^\n]*\n(?:(?:[ \t]+\S[^\n]*|[ \t]*)\n)*',
  multiLine: true,
);

/// Matches the single-line `name:` key. `name:` is a required, always
/// single-line pubspec key (never a YAML block scalar), so no multi-line
/// continuation handling is needed here — unlike [_descriptionBlockRe].
final RegExp _nameLineRe = RegExp(r'^name\s*:[^\n]*\n?', multiLine: true);

/// An insertion the fix should make: `text` goes at `offset` in the
/// pubspec.yaml source.
class PublishToNoneInsertion {
  const PublishToNoneInsertion({required this.offset, required this.text});

  final int offset;
  final String text;
}

/// Pure computation of where (and what) to insert for `publish_to: none`,
/// factored out of [PreferPublishToNoneFix.compute] so it is unit-testable
/// without standing up a real analyzer `ChangeBuilder`/`CorrectionProducerContext`
/// (mirrors the regex-only test seam used for [AddResolutionWorkspaceFix]).
/// Returns null when no insertion should happen: either `publish_to:` is
/// already present (stale diagnostic / duplicate "fix all" apply), or the
/// pubspec has neither `description:` nor `name:` to anchor on.
PublishToNoneInsertion? computePublishToNoneInsertion(String content) {
  // Re-verify: if the pubspec already declares publish_to (any value), bail
  // out rather than insert a duplicate, conflicting key.
  if (publishToAnyRe.hasMatch(content)) return null;

  // Prefer inserting after description: (conventional pubspec.yaml key
  // ordering places publish_to right after description), falling back to
  // right after name: (always present) when there is no description.
  final descMatch = _descriptionBlockRe.firstMatch(content);
  final anchorMatch = descMatch ?? _nameLineRe.firstMatch(content);
  if (anchorMatch == null) {
    // Malformed pubspec with neither description: nor name: — nothing sane
    // to anchor on, so signal "do nothing" rather than guess.
    return null;
  }

  final insertOffset = anchorMatch.end;
  final matchedText = content.substring(anchorMatch.start, anchorMatch.end);
  // If the matched anchor doesn't end with a newline (e.g. it is the last
  // content in a file lacking a trailing newline), prepend one so the new
  // key starts on its own line instead of corrupting the previous line.
  final needsNewline = !matchedText.endsWith('\n');
  final insertText = '${needsNewline ? '\n' : ''}publish_to: none\n';

  return PublishToNoneInsertion(offset: insertOffset, text: insertText);
}

/// Quick fix: insert `publish_to: none` into pubspec.yaml for a project the
/// [PreferPublishToNoneRule] heuristic has identified as an application
/// missing that declaration.
///
/// Companion fix for `PreferPublishToNoneRule`. Edits pubspec.yaml rather
/// than the Dart source file the diagnostic is attached to — same
/// `addGenericFileEdit` pattern used by [AddResolutionWorkspaceFix] and
/// `RaiseSdkLowerBoundFix`, since pubspec.yaml is not a Dart file the
/// `ChangeBuilder`'s Dart-specific helpers can target.
///
/// Insertion point, in priority order: immediately after the `description:`
/// block if present (the conventional position for `publish_to:` in a
/// pub.dev-style pubspec), otherwise immediately after the `name:` line
/// (always present — `name:` is a required pubspec key).
class PreferPublishToNoneFix extends SaropaFixProducer {
  PreferPublishToNoneFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferPublishToNone',
    40,
    'Add publish_to: none to pubspec.yaml',
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

    // Delegate to the pure, unit-tested computation. Handles the
    // already-has-publish_to guard and the description:/name: anchor choice;
    // returns null when there is nothing sane to do (see its doc comment).
    final insertion = computePublishToNoneInsertion(content);
    if (insertion == null) return;

    // Insert the publish_to: none line into pubspec.yaml.
    await builder.addGenericFileEdit(pubspecPath, (editBuilder) {
      editBuilder.addSimpleInsertion(insertion.offset, insertion.text);
    });
  }
}
