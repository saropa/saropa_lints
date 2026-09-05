# Frequently Asked Questions

<!--
  Extracted from README.md's "Frequently Asked Questions" section (previously
  the only copy of this content) so the README can stay focused on install /
  quick-start and the deep troubleshooting doc can link here instead of
  growing a second FAQ. Kept as a standalone file rather than a new
  troubleshooting.md section because troubleshooting.md already covers ten
  numbered scenarios plus the native-plugin deep dives — a further FAQ block
  would push that doc past a comfortable single-topic length.
-->

General questions about what saropa_lints is, how it compares to other tooling, and how to adopt it. For IDE-specific problems (warnings not showing, quick fixes missing, native crashes), see [doc/troubleshooting.md](troubleshooting.md).

**Q: Does this replace `flutter_lints`?**
A: You can run them side-by-side, but Saropa Lints covers everything in `flutter_lints` plus 2000+ additional behavioral and security checks. Most teams replace `flutter_lints` entirely. With v5, you no longer need `custom_lint` either — just `saropa_lints` in your dev_dependencies.

**Q: Will this slow down my CI/CD pipeline?**
A: Saropa Lints runs as a native analyzer plugin, integrated directly into `dart analyze`. The **Tier System** allows you to balance speed and strictness. The `essential` tier is designed to be fast for CI environments.

**Q: Can I use this with existing legacy projects?**
A: Yes! Use the **Baseline** feature (`dart run saropa_lints:baseline`) to suppress existing issues instantly. This lets you enforce quality on _new_ code without having to fix 500+ legacy errors first.

**Q: I'm upgrading from v4 — what changed?**
A: v5 uses the native Dart analyzer plugin system instead of `custom_lint`. Remove `custom_lint` from your dependencies, replace `custom_lint: rules:` with `plugins: saropa_lints: diagnostics:` in your config (or just use a tier preset), and run `dart analyze` instead of `dart run custom_lint`. The init tool handles the config migration automatically.

**Q: Can I add my own lint rules for my app (e.g. require `CommonText` instead of `Text`)?**
A: [Rule packs](guides/rule_packs.md) only enable rules already shipped in `saropa_lints`; there is no YAML-only "load arbitrary external rules" switch. The analyzer allows **one plugin per context** ([dart-lang/sdk#50981](https://github.com/dart-lang/sdk/issues/50981)), so use a **composite plugin**: one package that depends on `saropa_lints` and your rules, exposes the single `plugin` entrypoint, calls `loadNativePluginConfig` / `registerSaropaLintRules` from `package:saropa_lints/saropa_lints.dart`, then registers your rules. See [Composite analyzer plugin](guides/composite_analyzer_plugin.md). Alternatives: **private fork** of `saropa_lints`, **non-analyzer** enforcement (codemod, CI), or [professional / upstream](../PROFESSIONAL_SERVICES.md).
