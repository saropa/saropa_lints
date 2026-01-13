/// OWASP security compliance definitions and utilities.
///
/// This library provides OWASP Mobile Top 10 (2024) and OWASP Top 10 (2021)
/// category definitions for mapping lint rules to security compliance
/// standards.
///
/// ## Usage
///
/// ```dart
/// import 'package:saropa_lints/src/owasp/owasp.dart';
///
/// // Create an OWASP mapping for a rule
/// const mapping = OwaspMapping(
///   mobile: {OwaspMobile.m1, OwaspMobile.m10},
///   web: {OwaspWeb.a02, OwaspWeb.a07},
/// );
///
/// // Generate a compliance report
/// final report = generateComplianceReport(ruleMappings);
/// ```
library;

export 'owasp_category.dart';
export 'owasp_mapping.dart';
