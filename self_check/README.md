# Self-check package (optional)

This package can run saropa_lints on a small stub that imports the main package. For **validating the saropa_lints app itself** (lib/, test/, etc.) with the full rule set, use the **root** project instead.

## Recommended: validate from repo root

The root `analysis_options.yaml` includes `package:saropa_lints/tiers/pedantic.yaml`, so the plugin is loaded from the same package (no self-dependency). From the **repo root**:

```bash
dart analyze
```

This runs all ~2050 rules on the saropa_lints codebase. To use a lower tier (fewer issues), edit the root `analysis_options.yaml` and change the `include` to e.g. `package:saropa_lints/tiers/recommended.yaml`.

## Optional: run from this package

From the repo root:

```bash
dart pub get --directory self_check
dart analyze self_check
```

This only analyzes the small `self_check` lib; it does not report issues in the saropa_lints dependency. Use the root `dart analyze` to validate the full app.
