/// Minimal stable surface for **composite** analyzer plugins (org rules + Saropa).
///
/// See `doc/guides/composite_analyzer_plugin.md` in the `saropa_lints` repository.
///
/// This package exists so meta-plugins can depend on a small, versioned facade
/// that tracks compatible `saropa_lints` releases; it re-exports the same APIs
/// as `package:saropa_lints/saropa_lints.dart` for the symbols below.
library;

export 'package:saropa_lints/saropa_lints.dart'
    show
        loadNativePluginConfig,
        loadOutputConfigFromProjectRoot,
        loadRulePacksConfigFromProjectRoot,
        registerSaropaLintRules,
        SaropaLintRule;
