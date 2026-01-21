// ignore_for_file: unused_element, unused_local_variable

// BAD: Using insecure HTTP URLs
class BadHttpUsage {
  void fetchData() {
    // LINT: Hardcoded HTTP URL (insecure)
    final url = 'http://api.example.com/data';
    // Use in network request...
  }

  void connectToApi() {
    // LINT: HTTP in production code
    const apiEndpoint = 'http://example.com/api/v1';
    // Make API call...
  }

  void loadImage() {
    // LINT: HTTP image URL
    final imageUrl = 'http://cdn.example.com/image.png';
    // Load image...
  }
}

// GOOD: Using secure HTTPS URLs
class GoodHttpsUsage {
  void fetchData() {
    // OK: HTTPS is secure
    final url = 'https://api.example.com/data';
    // Use in network request...
  }

  void connectToApi() {
    // OK: Secure HTTPS endpoint
    const apiEndpoint = 'https://example.com/api/v1';
    // Make API call...
  }

  void loadImage() {
    // OK: Secure image URL
    final imageUrl = 'https://cdn.example.com/image.png';
    // Load image...
  }
}

// FALSE POSITIVE TEST: Safe replacement patterns should NOT trigger
class SafeHttpUpgrade {
  // OK: Replacing HTTP with HTTPS (safe upgrade pattern)
  String upgradeToHttps(String url) {
    return url.replaceFirst('http://', 'https://');
  }

  // OK: Using replaceAll for HTTP to HTTPS upgrade
  String upgradeAllToHttps(String content) {
    return content.replaceAll('http://', 'https://');
  }

  // OK: Generic replace with HTTP to HTTPS
  String upgradeUrls(String text) {
    return text.replace('http://', 'https://');
  }

  // OK: Conditional upgrade
  String ensureHttps(String url) {
    if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }
}

// ALLOWED: Localhost and development URLs
class LocalhostUsage {
  void connectToLocalhost() {
    // OK: Localhost HTTP is allowed for development
    final url = 'http://localhost:8080';
    final url2 = 'http://127.0.0.1:3000';
    final url3 = 'http://[::1]:8080'; // IPv6 localhost
    // Development usage...
  }

  void connectToLocalNetwork() {
    // OK: Local network development
    final url = 'http://192.168.1.100:8080';
    final url2 = 'http://10.0.0.1:3000';
    // Local testing...
  }
}
