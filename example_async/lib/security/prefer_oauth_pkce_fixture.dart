// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `prefer_oauth_pkce` lint rule.

// NOTE: prefer_oauth_pkce fires on OAuth constructor calls without
// codeVerifier parameter (PKCE flow).
//
// BAD:
// final grant = AuthorizationCodeGrant(clientId, authUrl, tokenUrl);
//
// GOOD:
// final grant = AuthorizationCodeGrant(
//   clientId, authUrl, tokenUrl, codeVerifier: pkceVerifier);

void main() {}
