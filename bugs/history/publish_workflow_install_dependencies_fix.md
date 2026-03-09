# Publish workflow: Install dependencies failure — resolved

**Summary:** GitHub Actions publish workflow was failing at the "Install dependencies" step. Root cause was use of an exact Dart/Flutter SDK version that could be missing or unreliable in the runner; the workflow also did not auto-commit the workflow file, so users had to run git commands manually.

**Fix (applied):**

<!-- cspell:ignore subosito -->

1. **.github/workflows/publish.yml**
   - Switched from `subosito/flutter-action` with `flutter-version: '3.27.0'` to `dart-lang/setup-dart` with `sdk: stable` so the SDK is always available.
   - Added a "Verify Dart SDK" step (`dart --version`) to fail fast with a clear error if setup fails.
   - Added a single retry (with 10s delay) for `dart pub get` to handle transient network/pub.dev issues.

2. **scripts/publish.py**
   - When the release tag already exists on the remote: auto-bump pubspec to the next version and add a "Release version" CHANGELOG section instead of exiting with an error.
   - New step after Remote sync: if `.github/workflows/publish.yml` has uncommitted changes, the script commits and pushes it (message: `chore: update publish workflow`) so the workflow used by the tag is always on the remote without manual git.

3. **scripts/modules/\_git_ops.py**
   - New `ensure_publish_workflow_committed(project_dir, branch)` to detect uncommitted changes in the publish workflow file and perform add/commit/push.

No new unit tests were added; the publish script is exercised by the release process. Logic is sequential with no race conditions or recursion.
