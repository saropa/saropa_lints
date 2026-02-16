/// Ignore-comment quick fixes are provided automatically by the native
/// analyzer plugin framework.
///
/// The framework registers `IgnoreDiagnosticOnLine`, `IgnoreDiagnosticInFile`,
/// and `IgnoreDiagnosticInAnalysisOptionsFile` for ALL plugin diagnostics.
/// These provide:
/// - "Ignore 'X' for this line" — adds `// ignore: rule_name`
/// - "Ignore 'X' for the whole file" — adds `// ignore_for_file: rule_name`
/// - "Ignore 'X' in analysis_options.yaml"
///
/// No custom implementation is needed in saropa_lints v5.
///
/// The old v4 classes (`AddIgnoreCommentFix`, `AddIgnoreForFileFix`,
/// `WrapInTryCatchFix`) have been removed as they are superseded by the
/// native implementation.
library;
