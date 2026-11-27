/**
 * Text identifying the `plugins:` block this extension commented out. It is
 * already written in users' analysis_options.yaml files, so it must never
 * change; `kIntegrationOffSentinel` in `lib/src/native/config_loader.dart`
 * holds the same words for the Dart side. Kept in its own module so pure code
 * can read it without importing `vscode` through `setup.ts`.
 */
export const INTEGRATION_OFF_SENTINEL = 'saropa_lints integration turned OFF by the VS Code extension';
