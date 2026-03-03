/// Ignore-comment quick fixes are provided automatically by the native
/// analyzer plugin framework.
///
/// The framework registers `IgnoreDiagnosticOnLine`, `IgnoreDiagnosticInFile`,
/// and `IgnoreDiagnosticInAnalysisOptionsFile` for ALL plugin diagnostics.
/// These provide "Ignore for this line" and "Ignore for the whole file".
/// No custom fix implementation is needed.
///
/// **Prohibition:** Do not add quick fixes that insert
/// `// ignore:` or `// ignore_for_file:` (e.g. "Add // ignore: rule_name").
/// Use [IgnoreUtils] in rules when a rule must respect existing ignore comments.
library;
