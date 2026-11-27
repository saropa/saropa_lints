import 'dart:io';

import 'package:test/test.dart';

/// Date of every commit made by [tempGit] unless the caller passes another.
const String kOldCommitDate = '2020-01-01T12:00:00';

/// Runs git in the temporary repository [repo] with a fixed identity and
/// commit [date]. `GIT_*` variables are dropped so a test run from a git hook
/// cannot touch the surrounding repository.
void tempGit(String repo, List<String> args, {String date = kOldCommitDate}) {
  final env = Map.of(Platform.environment)
    ..removeWhere((k, _) => k.toUpperCase().startsWith('GIT_'));
  final config = [
    'user.name=t',
    'user.email=t@example.com',
    'commit.gpgsign=false',
    'core.autocrlf=false',
    // The developer's global hooks must not run in a throwaway repository.
    'core.hooksPath=none',
  ];
  final result = Process.runSync(
    'git',
    [
      for (final c in config) ...['-c', c],
      ...args,
    ],
    workingDirectory: repo,
    environment: {...env, 'GIT_AUTHOR_DATE': date, 'GIT_COMMITTER_DATE': date},
    includeParentEnvironment: false,
  );
  expect(result.exitCode, 0, reason: '${args.join(' ')}: ${result.stderr}');
}

/// Stages everything in [repo] and commits it.
void tempCommit(String repo, String message, {String date = kOldCommitDate}) {
  tempGit(repo, ['add', '-A']);
  tempGit(repo, ['commit', '-q', '-m', message], date: date);
}
