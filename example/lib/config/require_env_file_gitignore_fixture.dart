// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Fixture for `require_env_file_gitignore`.
///
/// Triggers when `.env` exists at project root and `.gitignore` omits it.
Future<void> loadSecrets() async {
  // LINT: Only when root `.env` exists without matching gitignore lines.
  await dotenv.load(fileName: '.env');
}
