/// OWASP category definitions for security compliance mapping.
///
/// This file defines enums for both OWASP Mobile Top 10 (2024) and
/// OWASP Top 10 (2021) web application security standards.
library;

/// OWASP Mobile Application Security Top 10 (2024).
///
/// Reference: https://owasp.org/www-project-mobile-top-10/
enum OwaspMobile {
  /// M1: Improper Credential Usage
  ///
  /// Hardcoded credentials, insecure credential storage, or improper
  /// credential transmission.
  m1(
    id: 'M1',
    name: 'Improper Credential Usage',
    description:
        'Hardcoded credentials, insecure credential storage, '
        'or improper credential transmission.',
    url:
        'https://owasp.org/www-project-mobile-top-10/2024-risks/m1-improper-credential-usage',
  ),

  /// M2: Inadequate Supply Chain Security
  ///
  /// Vulnerabilities in third-party libraries, SDKs, or dependencies.
  m2(
    id: 'M2',
    name: 'Inadequate Supply Chain Security',
    description:
        'Vulnerabilities in third-party libraries, SDKs, '
        'or dependencies.',
    url:
        'https://owasp.org/www-project-mobile-top-10/2024-risks/m2-inadequate-supply-chain-security',
  ),

  /// M3: Insecure Authentication/Authorization
  ///
  /// Weak authentication mechanisms or improper authorization controls.
  m3(
    id: 'M3',
    name: 'Insecure Authentication/Authorization',
    description:
        'Weak authentication mechanisms or improper '
        'authorization controls.',
    url:
        'https://owasp.org/www-project-mobile-top-10/2024-risks/m3-insecure-authentication-authorization',
  ),

  /// M4: Insufficient Input/Output Validation
  ///
  /// Failure to properly validate, filter, or sanitize user input
  /// and output data.
  m4(
    id: 'M4',
    name: 'Insufficient Input/Output Validation',
    description:
        'Failure to properly validate, filter, or sanitize '
        'user input and output data.',
    url:
        'https://owasp.org/www-project-mobile-top-10/2024-risks/m4-insufficient-input-output-validation',
  ),

  /// M5: Insecure Communication
  ///
  /// Transmitting sensitive data over unencrypted channels or
  /// improper certificate validation.
  m5(
    id: 'M5',
    name: 'Insecure Communication',
    description:
        'Transmitting sensitive data over unencrypted channels '
        'or improper certificate validation.',
    url:
        'https://owasp.org/www-project-mobile-top-10/2024-risks/m5-insecure-communication',
  ),

  /// M6: Inadequate Privacy Controls
  ///
  /// Improper handling of PII, excessive data collection, or
  /// insufficient privacy protections.
  m6(
    id: 'M6',
    name: 'Inadequate Privacy Controls',
    description:
        'Improper handling of PII, excessive data collection, '
        'or insufficient privacy protections.',
    url:
        'https://owasp.org/www-project-mobile-top-10/2024-risks/m6-inadequate-privacy-controls',
  ),

  /// M7: Insufficient Binary Protections
  ///
  /// Lack of code obfuscation, anti-tampering, or reverse engineering
  /// protections.
  m7(
    id: 'M7',
    name: 'Insufficient Binary Protections',
    description:
        'Lack of code obfuscation, anti-tampering, or '
        'reverse engineering protections.',
    url:
        'https://owasp.org/www-project-mobile-top-10/2024-risks/m7-insufficient-binary-protections',
  ),

  /// M8: Security Misconfiguration
  ///
  /// Insecure default settings, overly permissive configurations, or
  /// improper security controls.
  m8(
    id: 'M8',
    name: 'Security Misconfiguration',
    description:
        'Insecure default settings, overly permissive configurations, '
        'or improper security controls.',
    url:
        'https://owasp.org/www-project-mobile-top-10/2024-risks/m8-security-misconfiguration',
  ),

  /// M9: Insecure Data Storage
  ///
  /// Storing sensitive data insecurely on the device, including
  /// unencrypted storage or world-readable files.
  m9(
    id: 'M9',
    name: 'Insecure Data Storage',
    description:
        'Storing sensitive data insecurely on the device, '
        'including unencrypted storage or world-readable files.',
    url:
        'https://owasp.org/www-project-mobile-top-10/2024-risks/m9-insecure-data-storage',
  ),

  /// M10: Insufficient Cryptography
  ///
  /// Use of weak cryptographic algorithms, improper key management,
  /// or flawed cryptographic implementations.
  m10(
    id: 'M10',
    name: 'Insufficient Cryptography',
    description:
        'Use of weak cryptographic algorithms, improper key management, '
        'or flawed cryptographic implementations.',
    url:
        'https://owasp.org/www-project-mobile-top-10/2024-risks/m10-insufficient-cryptography',
  );

  const OwaspMobile({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
  });

  /// Short identifier (e.g., 'M1', 'M2').
  final String id;

  /// Full category name.
  final String name;

  /// Description of the security risk.
  final String description;

  /// URL to OWASP documentation.
  final String url;

  @override
  String toString() => '$id: $name';
}

/// OWASP Top 10 Web Application Security Risks (2021).
///
/// Reference: https://owasp.org/Top10/
enum OwaspWeb {
  /// A01: Broken Access Control
  ///
  /// Failures in access control enforcement allowing unauthorized
  /// access to resources or functions.
  a01(
    id: 'A01',
    name: 'Broken Access Control',
    description:
        'Failures in access control enforcement allowing '
        'unauthorized access to resources or functions.',
    url: 'https://owasp.org/Top10/A01_2021-Broken_Access_Control/',
  ),

  /// A02: Cryptographic Failures
  ///
  /// Failures related to cryptography that expose sensitive data,
  /// including weak algorithms or improper key handling.
  a02(
    id: 'A02',
    name: 'Cryptographic Failures',
    description:
        'Failures related to cryptography that expose '
        'sensitive data, including weak algorithms or improper key handling.',
    url: 'https://owasp.org/Top10/A02_2021-Cryptographic_Failures/',
  ),

  /// A03: Injection
  ///
  /// User-supplied data interpreted as commands or queries,
  /// including SQL, NoSQL, OS, and LDAP injection.
  a03(
    id: 'A03',
    name: 'Injection',
    description:
        'User-supplied data interpreted as commands or queries, '
        'including SQL, NoSQL, OS, and LDAP injection.',
    url: 'https://owasp.org/Top10/A03_2021-Injection/',
  ),

  /// A04: Insecure Design
  ///
  /// Missing or ineffective security controls due to design flaws,
  /// rather than implementation bugs.
  a04(
    id: 'A04',
    name: 'Insecure Design',
    description:
        'Missing or ineffective security controls due to '
        'design flaws, rather than implementation bugs.',
    url: 'https://owasp.org/Top10/A04_2021-Insecure_Design/',
  ),

  /// A05: Security Misconfiguration
  ///
  /// Insecure default configurations, incomplete configurations,
  /// or ad hoc configurations.
  a05(
    id: 'A05',
    name: 'Security Misconfiguration',
    description:
        'Insecure default configurations, incomplete configurations, '
        'or ad hoc configurations.',
    url: 'https://owasp.org/Top10/A05_2021-Security_Misconfiguration/',
  ),

  /// A06: Vulnerable and Outdated Components
  ///
  /// Using components with known vulnerabilities or without
  /// proper version management.
  a06(
    id: 'A06',
    name: 'Vulnerable and Outdated Components',
    description:
        'Using components with known vulnerabilities '
        'or without proper version management.',
    url: 'https://owasp.org/Top10/A06_2021-Vulnerable_and_Outdated_Components/',
  ),

  /// A07: Identification and Authentication Failures
  ///
  /// Weaknesses in authentication and session management that
  /// allow attackers to compromise identities.
  a07(
    id: 'A07',
    name: 'Identification and Authentication Failures',
    description:
        'Weaknesses in authentication and session management '
        'that allow attackers to compromise identities.',
    url:
        'https://owasp.org/Top10/A07_2021-Identification_and_Authentication_Failures/',
  ),

  /// A08: Software and Data Integrity Failures
  ///
  /// Code and infrastructure that does not protect against
  /// integrity violations.
  a08(
    id: 'A08',
    name: 'Software and Data Integrity Failures',
    description:
        'Code and infrastructure that does not protect '
        'against integrity violations.',
    url:
        'https://owasp.org/Top10/A08_2021-Software_and_Data_Integrity_Failures/',
  ),

  /// A09: Security Logging and Monitoring Failures
  ///
  /// Insufficient logging, detection, monitoring, and active
  /// response capabilities.
  a09(
    id: 'A09',
    name: 'Security Logging and Monitoring Failures',
    description:
        'Insufficient logging, detection, monitoring, '
        'and active response capabilities.',
    url:
        'https://owasp.org/Top10/A09_2021-Security_Logging_and_Monitoring_Failures/',
  ),

  /// A10: Server-Side Request Forgery (SSRF)
  ///
  /// Application fetches remote resources without validating
  /// user-supplied URLs.
  a10(
    id: 'A10',
    name: 'Server-Side Request Forgery (SSRF)',
    description:
        'Application fetches remote resources without '
        'validating user-supplied URLs.',
    url:
        'https://owasp.org/Top10/A10_2021-Server-Side_Request_Forgery_%28SSRF%29/',
  );

  const OwaspWeb({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
  });

  /// Short identifier (e.g., 'A01', 'A02').
  final String id;

  /// Full category name.
  final String name;

  /// Description of the security risk.
  final String description;

  /// URL to OWASP documentation.
  final String url;

  @override
  String toString() => '$id: $name';
}

/// OWASP mapping for a lint rule.
///
/// Contains the OWASP categories from both Mobile Top 10 and Web Top 10
/// that a rule helps prevent.
class OwaspMapping {
  /// Creates an OWASP mapping with the specified categories.
  const OwaspMapping({
    this.mobile = const <OwaspMobile>{},
    this.web = const <OwaspWeb>{},
  });

  /// OWASP Mobile Top 10 categories this rule addresses.
  final Set<OwaspMobile> mobile;

  /// OWASP Web Top 10 categories this rule addresses.
  final Set<OwaspWeb> web;

  /// Returns true if this mapping has any categories.
  bool get isNotEmpty => mobile.isNotEmpty || web.isNotEmpty;

  /// Returns true if this mapping has no categories.
  bool get isEmpty => mobile.isEmpty && web.isEmpty;

  /// Returns all category IDs as a combined list.
  List<String> get allIds => <String>[
    ...mobile.map((OwaspMobile m) => m.id),
    ...web.map((OwaspWeb w) => w.id),
  ];

  @override
  String toString() {
    final List<String> parts = <String>[];
    if (mobile.isNotEmpty) {
      parts.add('Mobile: ${mobile.map((OwaspMobile m) => m.id).join(", ")}');
    }
    if (web.isNotEmpty) {
      parts.add('Web: ${web.map((OwaspWeb w) => w.id).join(", ")}');
    }
    return parts.join(' | ');
  }
}
