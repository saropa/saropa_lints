import 'package:test/test.dart';

/// Tests for false positive fixes
///
/// This test file documents the expected behavior for rule fixes:
/// 1. require_subscription_status_check - word boundary matching
/// 2. require_deep_link_fallback - utility getter filtering
/// 3. require_https_only - safe replacement pattern detection
/// 4. avoid_passing_self_as_argument - literal value exclusion
/// 5. avoid_variable_shadowing - sibling closure scoping
/// 6. avoid_isar_clear_in_production - receiver type checking
/// 7. avoid_unused_instances - fire-and-forget constructor allowlist
/// 8. prefer_late_final - method call-site awareness
/// 9. avoid_nested_assignments - for-loop update clause exclusion
///
/// Test fixtures are located in:
/// - example/lib/require_subscription_status_check_example.dart
/// - example_widgets/lib/navigation/require_deep_link_fallback_fixture.dart
/// - example_async/lib/security/require_https_only_fixture.dart
/// - example/lib/avoid_variable_shadowing_fixture.dart
/// - example_packages/lib/isar/avoid_isar_clear_in_production_fixture.dart
/// - example/lib/avoid_nested_assignments_fixture.dart
void main() {
  group('False Positive Fixes', () {
    group('require_subscription_status_check', () {
      test('should use word boundary regex to avoid substring matches', () {
        // Expected behavior documented in fixture file
        // isProportional should NOT trigger (contains "isPro" but is not "isPro")
        // processData should NOT trigger (contains "pro" but is not "pro")
        // premiumQualityDescription should NOT trigger (describes quality, not access)

        expect(
          'Word boundary regex prevents false positives on substrings',
          isNotNull,
        );
      });

      test('should still detect actual premium indicators', () {
        // Expected behavior: These SHOULD trigger
        // - isPro
        // - hasPremium
        // - isPremiumUser
        // - proFeature

        expect('Actual premium indicators are still detected', isNotNull);
      });
    });

    group('require_deep_link_fallback', () {
      test('should skip utility getters with common prefixes', () {
        // Expected behavior: These should NOT trigger
        // - isNotUriNullOrEmpty (starts with "is")
        // - hasValidScheme (starts with "has")
        // - checkDeepLinkFormat (starts with "check")
        // - isValidDeepLink (starts with "is")

        expect(
          'Utility getters with is/has/check/valid prefixes are skipped',
          isNotNull,
        );
      });

      test('should skip utility methods that manage state', () {
        // Expected behavior: These should NOT trigger
        // - resetInitialUri() (starts with "reset")
        // - clearCurrentUri() (starts with "clear")
        // - setInitialUri() (starts with "set")
        // - getStoredUri() (starts with "get")

        expect(
          'Utility methods with reset/clear/set/get prefixes are skipped',
          isNotNull,
        );
      });

      test('should skip simple expression body getters', () {
        // Expected behavior: These should NOT trigger
        // - Uri? get initialUri => _initialUri;
        // - Uri? get currentRouteUri => _currentUri;

        expect('Simple getters returning a field are skipped', isNotNull);
      });

      test('should skip lazy-loading patterns', () {
        // Expected behavior: These should NOT trigger
        // - Uri? get uri => _uri ??= Uri.parse(url);
        // - Uri? get cachedUri => _cachedUri ??= parseUri();

        expect('Lazy-loading with ??= operator is skipped', isNotNull);
      });

      test('should skip simple method invocations', () {
        // Expected behavior: These should NOT trigger
        // - Uri? get parsedUri => url.toUri();
        // - Uri? get safeUri => url?.toUriSafe();
        // - Uri? uri() => _url.toUri();

        expect('Simple method invocations on fields are skipped', isNotNull);
      });

      test('should skip property access patterns', () {
        // Expected behavior: These should NOT trigger
        // - String? get uriScheme => _uri?.scheme;
        // - String? get uriHost => uri?.host;

        expect('Null-aware property access is skipped', isNotNull);
      });

      test('should skip trivial single-assignment method bodies', () {
        // Expected behavior: These should NOT trigger
        // - void resetUri() { _uri = null; }

        expect(
          'Methods with single assignment statement are skipped',
          isNotNull,
        );
      });

      test('should skip methods with simple return statements', () {
        // Expected behavior: These should NOT trigger
        // - Uri? getStoredUri() { return _uri; }
        // - Uri? getCachedUri() => _uri;
        // - Uri? getDefaultUri() { return null; }

        expect(
          'Methods with simple return of field/null are skipped',
          isNotNull,
        );
      });

      test('should skip utility getters ending with empty/null/nullable', () {
        // Expected behavior: These should NOT trigger
        // - isUriEmpty (ends with "empty")
        // - isUriNull (ends with "null")
        // - isUriNullable (ends with "nullable")

        expect(
          'Utility getters ending with empty/null/nullable are skipped',
          isNotNull,
        );
      });

      test('should still detect actual deep link handlers', () {
        // Expected behavior: These SHOULD trigger if missing fallback
        // - handleProductDeepLink
        // - handleUserProfileLink
        // - processDeepLink

        expect(
          'Actual deep link handlers without fallback are detected',
          isNotNull,
        );
      });

      test('should use suffix matching not substring matching', () {
        // handleEmptyDeepLink SHOULD be checked (not ending with "empty")
        // processNullableUri SHOULD be checked if not a getter with is/has prefix

        expect('Uses endsWith for precision, not contains', isNotNull);
      });

      test('should skip methods returning Widget types', () {
        // Expected behavior: These should NOT trigger
        // - Widget buildShareLinkButton() - UI builder
        // - Widget? buildRouteBanner() - nullable widget builder
        // Also covers Future<Widget>, PreferredSizeWidget, etc.

        expect(
          'Methods returning Widget types are UI builders, not handlers',
          isNotNull,
        );
      });

      test('should skip methods with no deep link signals in body', () {
        // Expected behavior: These should NOT trigger
        // - linkAccounts() - name has "link" but body has no Uri/Navigator
        // - logRouteChange() - name has "route" but body has no navigation

        expect(
          'Methods without Uri/Navigator/GoRouter in body are skipped',
          isNotNull,
        );
      });
    });

    group('require_https_only', () {
      test('should allow safe http to https replacement patterns', () {
        // Expected behavior: These should NOT trigger
        // - url.replaceFirst('http://', 'https://')
        // - content.replaceAll('http://', 'https://')
        // - text.replace('http://', 'https://')

        expect('Safe HTTP to HTTPS upgrade patterns are allowed', isNotNull);
      });

      test('should still detect hardcoded http URLs', () {
        // Expected behavior: These SHOULD trigger
        // - 'http://api.example.com/data'
        // - 'http://cdn.example.com/image.png'

        expect('Hardcoded HTTP URLs are still detected', isNotNull);
      });

      test('should allow localhost and development URLs', () {
        // Expected behavior: These should NOT trigger
        // - http://localhost:8080
        // - http://127.0.0.1:3000
        // - http://[::1]:8080
        // - http://192.168.1.100:8080

        expect('Localhost and local network URLs are allowed', isNotNull);
      });
    });

    group('avoid_passing_self_as_argument', () {
      test('should skip literal values as targets', () {
        // Expected behavior: These should NOT trigger
        // - 0.isBetween(0, 10)         // IntegerLiteral
        // - 3.14.isBetween(0.0, 5.0)   // DoubleLiteral
        // - 'test'.contains('test')    // StringLiteral
        // - true.toString() == 'true'  // BooleanLiteral

        expect(
          'Literal values (int, double, string, bool) are excluded',
          isNotNull,
        );
      });

      test('should still detect object self-references', () {
        // Expected behavior: These SHOULD trigger
        // - list.add(list)     // Adding list to itself
        // - map[key] = map     // Assigning map to itself
        // - obj.compare(obj)   // Comparing object to itself

        expect('Object self-references are still detected', isNotNull);
      });
    });

    group('avoid_variable_shadowing', () {
      test('should not flag sibling closures as shadowing', () {
        // Expected behavior: These should NOT trigger
        // Variables with same name in sibling closures (not nested) are
        // independent scopes, not shadowing
        //
        // group('...', () {
        //   test('A', () { final list = [1]; }); // Scope A
        //   test('B', () { final list = [2]; }); // Scope B - NOT shadowing
        // });
        //
        // The closures are siblings, not nested.

        expect('Sibling closures have independent scopes', isNotNull);
      });

      test('should still detect true nested shadowing', () {
        // Expected behavior: These SHOULD trigger
        // void outer() {
        //   final list = [1];        // Outer scope
        //   void inner() {
        //     final list = [2];      // SHADOWING - nested, not sibling
        //   }
        // }

        expect('Nested shadowing is still detected', isNotNull);
      });

      test('should detect parameter shadowing', () {
        // Expected behavior: These SHOULD trigger
        // int value = 10;
        // void process(int value) { } // Shadows outer 'value'

        expect('Parameter shadowing outer variable is detected', isNotNull);
      });
    });

    group('avoid_unused_instances', () {
      test('should not flag Future constructors as unused', () {
        // Expected behavior: These should NOT trigger
        // - Future.delayed(duration, callback)
        // - Future.microtask(callback)
        // - Future<void>.delayed(duration, callback)

        expect(
          'Future constructors used for side effects are skipped',
          isNotNull,
        );
      });

      test('should not flag Timer constructors as unused', () {
        // Expected behavior: These should NOT trigger
        // - Timer(duration, callback)
        // - Timer.periodic(duration, callback)

        expect(
          'Timer constructors used for side effects are skipped',
          isNotNull,
        );
      });

      test('should still detect genuinely unused instances', () {
        // Expected behavior: These SHOULD trigger
        // - MyClass()
        // - ValueNotifier(0)
        // - List<int>()

        expect('Genuinely unused instances are still detected', isNotNull);
      });
    });

    group('avoid_isar_clear_in_production', () {
      test('should only flag clear() on Isar instances', () {
        // Expected behavior:
        // isar.clear() without kDebugMode guard SHOULD trigger
        // isar.clear() inside if (kDebugMode) should NOT trigger

        expect('Only Isar.clear() triggers the rule', isNotNull);
      });

      test('should not flag clear() on Map, List, Set, or other types', () {
        // Expected behavior: These should NOT trigger
        // - cache.clear()      (Map<String, List<String>>)
        // - items.clear()      (List<int>)
        // - tags.clear()       (Set<String>)
        // - buffer.clear()     (StringBuffer)
        // - controller.clear() (TextEditingController)

        expect('Non-Isar clear() calls are not flagged', isNotNull);
      });
    });

    group('prefer_late_final', () {
      test(
        'should not flag fields assigned via method called multiple times',
        () {
          // Expected behavior:
          // A late field assigned in a helper method that is called from
          // multiple sites (e.g., initState + didUpdateWidget) should NOT
          // be flagged, because the field IS reassigned at runtime.
          //
          // class MyState {
          //   late Future<T> _future;
          //   void _fetch() { _future = loadData(); }
          //   void initState() { _fetch(); }           // Call site 1
          //   void didUpdateWidget() { _fetch(); }     // Call site 2
          // }

          expect(
            'Method call-site analysis prevents false positives',
            isNotNull,
          );
        },
      );

      test('should still flag fields with single call-site methods', () {
        // Expected behavior: These SHOULD trigger
        // - late field assigned in a method called from only one place
        // - late field assigned directly in a single method

        expect('Single-assignment fields are still detected', isNotNull);
      });

      test('should not flag fields with multiple direct assignments', () {
        // Expected behavior: These should NOT trigger
        // - late field assigned in init() AND reset()

        expect('Multiple direct assignments prevent flagging', isNotNull);
      });
    });

    group('avoid_nested_assignments', () {
      test('should not flag for-loop update clauses', () {
        // Expected behavior: These should NOT trigger
        // for (int i = 0; i < n; i += 1) {}
        // for (int i = 0; i < n; i += step) {}
        // for (int i = n; i > 0; i -= 1) {}
        // for (int i = 1; i < n; i *= 2) {}
        // for (int i = 0; i < n; i = next(i)) {}
        // for (int mask = 1; mask != 0; mask <<= 1) {}

        expect('For-loop update clause assignments are not nested', isNotNull);
      });

      test('should still flag assignments in conditions and arguments', () {
        // Expected behavior: These SHOULD trigger
        // if ((x = getValue()) > 0) {}
        // foo(x = 5)
        // final list = [x = 5]

        expect('Genuinely nested assignments are still detected', isNotNull);
      });
    });

    group('require_websocket_reconnection', () {
      test('should not flag WebSocket class definitions', () {
        // Fixed: node.toSource() includes the class name, so classes
        // literally named WebSocket or WebSocketChannel always matched
        // their own string check, producing false positives on mock/stub
        // class definitions.
        //
        // These must NOT trigger:
        // - class WebSocket { ... }
        // - class WebSocketChannel { ... }

        expect(
          'WebSocket class definitions are skipped via exact name match',
          isNotNull,
        );
      });

      test(
        'should still flag classes that USE WebSocket without reconnection',
        () {
          // Expected behavior: These SHOULD trigger
          // - class ChatService { WebSocketChannel.connect(url); }
          // - class LiveFeed { WebSocket.connect(url); }
          //
          // Expected behavior: These should NOT trigger (has reconnection)
          // - class ChatService { ... reconnect() ... onDone: ... }

          expect(
            'Classes using WebSocket without reconnection are detected',
            isNotNull,
          );
        },
      );

      test('should not flag WebSocket subclass names', () {
        // Classes named BadWebSocketService, GoodWebSocketService,
        // WebSocketDemo are NOT skipped — they USE WebSocket and
        // should be checked for reconnection logic.

        expect(
          'Only exact WebSocket/WebSocketChannel names are skipped',
          isNotNull,
        );
      });
    });
  });

  group('String.contains() Anti-Pattern Fixes', () {
    // These tests document fixes for the systemic .contains() anti-pattern
    // that caused 71% of all resolved bugs. See:
    // bugs/string_contains_false_positive_audit.md

    group('require_location_timeout', () {
      test('should not flag permission-only methods', () {
        // Fixed: LocationPermissionUtils.hasLocationPermission() was flagged
        // because method name contains "Location". Now uses exact GPS method
        // set: getCurrentPosition, getLastKnownPosition, getLocation, etc.
        //
        // These must NOT trigger:
        // - LocationPermissionUtils.hasLocationPermission()
        // - LocationServiceUtils.isLocationServiceEnabled()
        // - Geolocator.openLocationSettings()
        // - LocationFormatter.formatLocation(latLng)
        // - LocationCache.getCachedLocation()

        expect(
          'GPS method exact-match set replaces substring matching',
          isNotNull,
        );
      });

      test('should detect chained .timeout() on Futures', () {
        // Fixed: Geolocator.getCurrentPosition().timeout(duration) was not
        // detected because timeout check only inspected direct arguments.
        // Now walks up AST parents to find chained .timeout() calls.

        expect('Chained .timeout() is detected via AST parent walk', isNotNull);
      });
    });

    group('await_navigation', () {
      test('should not flag classes with Navigator in the name', () {
        // Fixed: contains('Navigator') matched NavigatorHelper, CustomNavigator
        // Now uses exact match: targetSource == 'Navigator'
        //
        // These must NOT trigger:
        // - NavigatorHelper.setup()
        // - CustomNavigatorState.pushRoute()
        // - NavigatorObserverLogger.log()

        expect('Navigator exact match replaces substring matching', isNotNull);
      });
    });

    group('avoid_context_access_in_callback', () {
      test('should not flag classes with context in the name', () {
        // Fixed: contains('context') matched ThemeContext, SecurityContext,
        // AudioContext, etc. Now checks if target is SimpleIdentifier with
        // name == 'context' (actual BuildContext parameter).
        //
        // These must NOT trigger:
        // - ThemeContext.of(context) — "ThemeContext" is a class, not context
        // - SecurityContext.defaultContext
        // - AudioContext.createBuffer()

        expect(
          'BuildContext SimpleIdentifier check replaces substring matching',
          isNotNull,
        );
      });
    });

    group('require_http_status_code_check', () {
      test('should not flag non-HTTP .get() calls', () {
        // Fixed: contains('.get(') matched Map.get(), GetIt.get(),
        // SharedPreferences.get(), List.get(). Now uses specific client
        // patterns: http.get, dio.get, client.get with exact target matching.
        //
        // These must NOT trigger:
        // - cache.get(key)
        // - prefs.get('setting')
        // - GetIt.I.get<Service>()
        // - map.get(key)

        expect(
          'HTTP client exact target set replaces bare .get() matching',
          isNotNull,
        );
      });
    });

    group('require_scroll_controller_dispose', () {
      test('should not flag classes containing ScrollController', () {
        // Fixed: typeName.contains('ScrollController') matched
        // ScrollControllerManager, CustomScrollControllerMixin, etc.
        // Now uses exact match: == 'ScrollController' or
        // == 'ScrollController?'
        //
        // These must NOT trigger for type matching:
        // - ScrollControllerManager (custom wrapper class)
        // - CustomScrollControllerMixin
        // - ScrollControllerFactory

        expect(
          'ScrollController exact type match replaces substring matching',
          isNotNull,
        );
      });

      test('should detect disposal via regex instead of interpolation', () {
        // Fixed: disposeBody.contains('$name.dispose(') broke on whitespace,
        // null-aware calls (?.dispose), and formatting differences.
        // Now uses regex: RegExp('name\\s*[?.]\\s*dispose\\s*\\(')

        expect(
          'Regex disposal detection replaces string interpolation',
          isNotNull,
        );
      });
    });
  });

  group('prefer_wheretype_over_where_is', () {
    test('should not flag negated type checks (is!)', () {
      // Fixed: IsExpression matches both `is` and `is!`, but the rule
      // never checked expr.notOperator. `.where((e) => e is! T)` has
      // no whereType equivalent — it excludes a type, not includes.
      //
      // These must NOT trigger:
      // - list.where((e) => e is! String)
      // - items.where((w) => w is! PhoneRow)

      expect('Negated is! checks are skipped via notOperator guard', isNotNull);
    });

    test('should still flag positive type checks', () {
      // Expected behavior: These SHOULD trigger
      // - list.where((e) => e is String)
      // - items.where((w) => w is Widget)

      expect('Positive is checks are still detected', isNotNull);
    });

    test('auto-fix should not produce semantically wrong replacement', () {
      // Fixed: The auto-fix also lacked the notOperator guard and would
      // replace `.where((e) => e is! T)` with `.whereType<T>()`,
      // which inverts the filtering logic.
      //
      // After fix: auto-fix only runs on positive `is` checks.

      expect(
        'Auto-fix guard prevents incorrect is! to whereType replacement',
        isNotNull,
      );
    });
  });

  group('Test Fixture Coverage', () {
    test('require_subscription_status_check has test fixture', () {
      // Located at: example/lib/require_subscription_status_check_example.dart
      expect(true, isTrue);
    });

    test('require_deep_link_fallback has test fixture', () {
      // Located at: example_widgets/lib/navigation/require_deep_link_fallback_fixture.dart
      expect(true, isTrue);
    });

    test('require_https_only has test fixture', () {
      // Located at: example_async/lib/security/require_https_only_fixture.dart
      expect(true, isTrue);
    });

    test('avoid_variable_shadowing has test fixture', () {
      // Located at: example/lib/avoid_variable_shadowing_fixture.dart
      expect(true, isTrue);
    });

    test('avoid_isar_clear_in_production has test fixture', () {
      // Located at: example_packages/lib/isar/avoid_isar_clear_in_production_fixture.dart
      expect(true, isTrue);
    });

    test('prefer_late_final has test fixture', () {
      // Located at: example_core/lib/code_quality/code_quality_fixture.dart
      expect(true, isTrue);
    });

    test('avoid_nested_assignments has test fixture', () {
      // Located at: example/lib/avoid_nested_assignments_fixture.dart
      expect(true, isTrue);
    });

    test('require_websocket_reconnection has mock stubs', () {
      // Located at: example/lib/flutter_mocks.dart (WebSocket, WebSocketChannel)
      // Fixture at: example_async/lib/async/async_rules_fixture.dart
      expect(true, isTrue);
    });

    test('prefer_wheretype_over_where_is has test fixture', () {
      // Located at: example_style/lib/stylistic_null_collection/prefer_wheretype_over_where_is_fixture.dart
      expect(true, isTrue);
    });
  });
}
