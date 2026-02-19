# Task: `require_ssl_pinning_sensitive`

## Summary
- **Rule Name**: `require_ssl_pinning_sensitive`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.19 http Package Security Rules

## Problem Statement

SSL/TLS certificate validation protects against Man-in-the-Middle (MitM) attacks, but it only validates that the server has **a valid certificate from a trusted CA**. An attacker who compromises a CA, or who installs a custom CA on the device (common in enterprise environments and on rooted/jailbroken devices), can still intercept HTTPS traffic.

**SSL Pinning** goes further by hardcoding the expected server certificate (or its public key hash) into the app. This ensures that even if a rogue CA is trusted, the connection only succeeds if the server's actual certificate matches.

For sensitive operations (authentication, payment, medical data), SSL pinning is a security best practice:
- **OWASP M5: Improper Communication** — sending sensitive data without proper certificate validation
- **OWASP M3: Insecure Authentication** — auth endpoints without certificate pinning

```dart
// BAD: no certificate pinning on auth endpoint
final response = await http.post(
  Uri.parse('https://api.example.com/auth/login'),  // ← auth endpoint, no pinning
  body: {'username': username, 'password': password},
);
```

## Description (from ROADMAP)

> Sensitive APIs need certificate pinning. Detect auth endpoints without pinning.

## Trigger Conditions

1. An HTTP POST/PUT/PATCH to a URL containing auth-related path segments (`/auth`, `/login`, `/signin`, `/token`, `/oauth`, `/credentials`) without certificate pinning configured
2. `http.Client` or `Dio` making requests to sensitive URLs without custom `SecurityContext` or pinning interceptor

**HIGH FALSE POSITIVE RISK**: URL string analysis is a heuristic. Many auth endpoints use different paths.

## Implementation Approach

### Phase 1 (Heuristic: URL path detection)
```dart
context.registry.addMethodInvocation((node) {
  if (!_isHttpSensitiveCall(node)) return; // POST/PUT to auth-like URL
  if (_projectHasSslPinning(context)) return; // http_certificate_pinning package
  reporter.atNode(node, code);
});
```

`_isHttpSensitiveCall`: check if method is `post/put/patch` and the URL string literal contains `/auth`, `/login`, `/token`.
`_projectHasSslPinning`: check `ProjectContext.usesPackage('http_certificate_pinning')` or `ProjectContext.usesPackage('ssl_pinning_plugin')`.

### Phase 2 (More Accurate)
Detect `Dio` without `HttpClientAdapter` that sets `badCertificateCallback` in a way that enforces pinning.

## Code Examples

### Bad (Should trigger)
```dart
// Direct HTTP call to auth endpoint without pinning
final response = await http.post(
  Uri.parse('https://api.myapp.com/auth/login'),  // ← trigger: auth URL, no pinning
  body: jsonEncode({'email': email, 'password': password}),
);

// Dio without pinning interceptor
final dio = Dio();
// ← no certificate pinning configured
final response = await dio.post('/auth/token', data: credentials);
```

### Good (Should NOT trigger)
```dart
// Using http_certificate_pinning
final response = await HttpCertificatePinning.check(
  serverURL: 'https://api.myapp.com/auth/login',
  headerHttp: {},
  sha: SHA.SHA256,
  allowedSHAFingerprints: ['AB:CD:EF:...'],
  timeout: 50,
);

// Dio with pinning interceptor
final dio = Dio();
dio.interceptors.add(CertificatePinningInterceptor(allowedFingerprints: [...]));
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Local development server (`localhost`, `127.0.0.1`) | **Suppress** | Dev servers don't have pinnable certs |
| HTTP (not HTTPS) URLs | **Suppress** — pinning is irrelevant on HTTP | Actually, HTTP should be a separate error |
| Dio with custom `HttpClientAdapter` | **Complex** — may have pinning | |
| `package:http` with custom `SecurityContext` | **Suppress** — may have cert validation | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `http.post(Uri.parse('https://api.x.com/auth/login'), ...)` without pinning package → 1 lint

### Non-Violations
1. Project with `http_certificate_pinning` → no lint
2. `http.get('/auth/login')` (GET, not modifying data) → debatable
3. `http.post('http://localhost/auth/login')` → no lint (dev server)

## Quick Fix

No automated fix — implementing SSL pinning requires:
1. Adding pinning package
2. Generating certificate fingerprints
3. Configuring pinning interceptor

Suggest documentation link to OWASP certificate pinning guide.

## Notes & Issues

1. **OWASP**: Maps to **M5: Improper Communication** and **M3: Insecure Authentication**.
2. **HIGH FALSE POSITIVE RISK**: The URL path heuristic is unreliable. Many auth endpoints don't use `/auth` in the path. Many non-auth endpoints do use `/auth-svc/` as a service namespace.
3. **Phase 1 is very conservative**: Only fires when URL string literally contains auth-related paths AND no pinning package is in the project. This will miss most cases but avoid false positives.
4. **Pinning packages**: The Flutter ecosystem has several:
   - `http_certificate_pinning`
   - `ssl_pinning_plugin`
   - Dio's built-in `HttpClientAdapter` with `badCertificateCallback`
   - Native platform channels for stricter pinning
5. **Bypass risk**: SSL pinning can be bypassed on rooted/jailbroken devices using tools like Frida. It's a defense-in-depth measure, not a silver bullet.
6. **Certificate expiry**: Pinned certificates expire. Apps that pin certificates need a key rotation strategy. A companion rule about pinned certificate rotation would be valuable.
