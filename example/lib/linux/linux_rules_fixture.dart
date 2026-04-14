// ignore_for_file: unused_local_variable, unused_element, avoid_print

import 'dart:io';

// =============================================================================
// avoid_hardcoded_unix_paths
// =============================================================================

/// BAD: Hardcoded Unix paths
void badHardcodedUnixPaths() {
  // expect_lint: avoid_hardcoded_unix_paths
  final config = File('/home/user/.config/myapp/settings.json');

  // expect_lint: avoid_hardcoded_unix_paths
  final temp = File('/tmp/myapp_cache.dat');

  // expect_lint: avoid_hardcoded_unix_paths
  final log = File('/var/log/myapp.log');

  // expect_lint: avoid_hardcoded_unix_paths
  final lib = Directory('/usr/lib/myapp');

  // expect_lint: avoid_hardcoded_unix_paths
  final opt = Directory('/opt/myapp/data');

  // expect_lint: avoid_hardcoded_unix_paths
  final etc = File('/etc/myapp.conf');

  // expect_lint: avoid_hardcoded_unix_paths
  final root = File('/root/.ssh/known_hosts');
}

/// GOOD: Using path_provider or environment
Future<void> goodDynamicPaths() async {
  final appDir = await getApplicationSupportDirectory();
  final config = File('${appDir.path}/settings.json');

  final tempDir = await getTemporaryDirectory();
  final temp = File('${tempDir.path}/myapp_cache.dat');

  final home = Platform.environment['HOME'];
  final dataDir = Directory('$home/myapp');
}

// =============================================================================
// prefer_xdg_directory_convention
// =============================================================================

/// BAD: Manual XDG directory construction
void badXdgPaths() {
  final home = Platform.environment['HOME'];

  // expect_lint: prefer_xdg_directory_convention
  final config = '$home/.config/myapp/settings.json';

  // expect_lint: prefer_xdg_directory_convention
  final data = '$home/.local/share/myapp/data.db';

  // expect_lint: prefer_xdg_directory_convention
  final cache = '$home/.cache/myapp/thumbnails';

  // expect_lint: prefer_xdg_directory_convention
  final state = '$home/.local/state/myapp/logs';
}

/// GOOD: Using path_provider
Future<void> goodXdgPaths() async {
  final configDir = await getApplicationSupportDirectory();
  final config = '${configDir.path}/settings.json';

  final cacheDir = await getTemporaryDirectory();
  final cache = '${cacheDir.path}/thumbnails';
}

// =============================================================================
// avoid_x11_only_assumptions
// =============================================================================

/// BAD: X11-only tool usage
Future<void> badX11Tools() async {
  // expect_lint: avoid_x11_only_assumptions
  await Process.run('xdotool', ['getactivewindow']);

  // expect_lint: avoid_x11_only_assumptions
  await Process.run('xclip', ['-selection', 'clipboard']);

  // expect_lint: avoid_x11_only_assumptions
  await Process.run('xrandr', ['--output', 'HDMI-1']);
}

/// BAD: Accessing DISPLAY without checking session type
void badDisplayAccess() {
  // expect_lint: avoid_x11_only_assumptions
  final display = Platform.environment['DISPLAY'];
  print('Display: $display');
}

/// GOOD: Checking session type before using X11 APIs
void goodDisplayAccess() {
  final sessionType = Platform.environment['XDG_SESSION_TYPE'];
  if (sessionType == 'x11') {
    final display = Platform.environment['DISPLAY'];
    print('Display: $display');
  }
}

/// GOOD: Using Flutter abstractions
void goodClipboard() {
  // Flutter's Clipboard works on both X11 and Wayland
  // Clipboard.getData('text/plain');
}

// =============================================================================
// require_linux_font_fallback
// =============================================================================

/// BAD: Platform-specific fonts without fallback
void badFonts() {
  // expect_lint: require_linux_font_fallback
  final style1 = TextStyle(fontFamily: 'Segoe UI');

  // expect_lint: require_linux_font_fallback
  final style2 = TextStyle(fontFamily: 'Helvetica Neue');

  // expect_lint: require_linux_font_fallback
  final style3 = TextStyle(fontFamily: 'San Francisco');

  // expect_lint: require_linux_font_fallback
  final style4 = TextStyle(fontFamily: 'Arial');

  // expect_lint: require_linux_font_fallback
  final style5 = TextStyle(fontFamily: 'Consolas');
}

/// GOOD: Fonts with fallback or cross-platform fonts
void goodFonts() {
  // Has fontFamilyFallback
  final style1 = TextStyle(
    fontFamily: 'Segoe UI',
    fontFamilyFallback: ['Roboto', 'Noto Sans', 'Liberation Sans'],
  );

  // Cross-platform font (bundled in Flutter)
  final style2 = TextStyle(fontFamily: 'Roboto');

  // No fontFamily specified
  final style3 = TextStyle(fontSize: 16);
}

// =============================================================================
// avoid_sudo_shell_commands
// =============================================================================

/// BAD: Using sudo/elevated commands
Future<void> badSudoCommands() async {
  // expect_lint: avoid_sudo_shell_commands
  await Process.run('sudo', ['apt', 'install', 'package']);

  // expect_lint: avoid_sudo_shell_commands
  await Process.run('pkexec', ['some-command']);

  // expect_lint: avoid_sudo_shell_commands
  await Process.run('su', ['-c', 'whoami']);
}

/// GOOD: Non-elevated commands
Future<void> goodNonElevatedCommands() async {
  await Process.run('ls', ['-la']);
  await Process.run('flatpak', ['install', 'com.example.App']);
  await Process.run('echo', ['hello']);
}

// =============================================================================
// Mock types for compilation
// =============================================================================

Future<Directory> getApplicationSupportDirectory() async => Directory('.');
Future<Directory> getTemporaryDirectory() async => Directory('.');

class TextStyle {
  const TextStyle({
    this.fontFamily,
    this.fontFamilyFallback,
    this.fontSize,
  });
  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  final double? fontSize;
}
