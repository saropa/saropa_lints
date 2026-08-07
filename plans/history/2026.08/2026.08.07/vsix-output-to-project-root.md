# Move VSIX Output to Project Root

The publish scripts packaged `.vsix` files into `extension/`, making them harder to find after a build. The output path was changed to the project root across all publish modes.

## Finish Report (2026-08-07)

### Changes

- `scripts/modules/_extension_publish.py`: `extension_vsix_path()` returns `project_dir / name` instead of `_extension_dir(project_dir) / name`. `run_extension_package()` cleans stale `.vsix` from root, passes `--out <root path>` to `vsce package`, and searches root for the output.
- `scripts/modules/_publish_workflow.py`: `run_publish_existing_vsix_mode()` globs `project_dir` instead of `project_dir / "extension"` when looking for existing `.vsix` files.
- `scripts/publish.py`: Menu text for mode 7 updated from "newest in extension/" to "newest in project root".
- `CHANGELOG.md`: Maintenance entry added.
- `scripts/README.md`: Updated mode 7 description to reference project root.
- Post-package success message now prints the full absolute path and file size (KB/MB).

### Scope

Scripts only (C). No Dart rules, extension TypeScript, or lint logic touched.

### Testing

No automated tests exist for these publish-script functions. Manual verification required: run mode 6 and confirm the `.vsix` appears in the project root.
