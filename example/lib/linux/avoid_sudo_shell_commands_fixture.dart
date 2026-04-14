// ignore_for_file: unused_local_variable, unused_element
// Test fixture for avoid_sudo_shell_commands rule (OWASP M1)
//
// Rule: avoid_sudo_shell_commands
// Severity: ERROR | Impact: Critical | Tier: Essential
//
// Flags Process.run/start calls where the first argument is a privilege-
// escalation command (sudo, pkexec, gksudo, kdesudo, su).
// Sandboxed Linux apps cannot gain root; the call will fail or mislead users.

import 'dart:io';

// =============================================================================
// BAD: Elevated privilege commands — should trigger
// =============================================================================

Future<void> testSudoCommands() async {
  // BAD: sudo — assumes root access not available in sandboxed apps
  // expect_lint: avoid_sudo_shell_commands
  await Process.run('sudo', <String>['apt-get', 'install', 'curl']);

  // BAD: pkexec — privilege escalation without a polkit policy file
  // expect_lint: avoid_sudo_shell_commands
  await Process.run('pkexec', <String>['apt-get', 'upgrade']);

  // BAD: su — switch to root user
  // expect_lint: avoid_sudo_shell_commands
  await Process.start('su', <String>['-c', 'rm -rf /tmp/lockfile']);

  // BAD: gksudo — GTK graphical sudo frontend
  // expect_lint: avoid_sudo_shell_commands
  await Process.run('gksudo', <String>['gedit', '/etc/hosts']);

  // BAD: kdesudo — KDE graphical sudo frontend
  // expect_lint: avoid_sudo_shell_commands
  await Process.run('kdesudo', <String>['kate', '/etc/fstab']);
}

// =============================================================================
// GOOD: Non-elevated user-space commands — should NOT trigger
// =============================================================================

Future<void> testNonElevatedCommands() async {
  // GOOD: Standard file-system operations — no elevated privileges
  await Process.run('ls', <String>['-la']);
  await Process.run('git', <String>['status']);
  await Process.run('myapp', <String>['--help']);
  await Process.run('xdg-open', <String>['https://example.com']);

  // GOOD: 'sudoers' as data — the literal does not begin with an elevated cmd
  final content = await Process.run('cat', <String>['/etc/sudoers.d/myapp']);
}
