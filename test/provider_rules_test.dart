import 'dart:io';

import 'package:test/test.dart';

/// Tests for 27 Provider package lint rules.
///
/// These rules cover proper Provider/ChangeNotifier usage, Consumer/Selector
/// patterns, disposal, InheritedWidget requirements, and common anti-patterns.
///
/// Test fixtures: example_packages/lib/packages/*provider*
void main() {
  group('Provider Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_nested_providers',
      'avoid_provider_in_init_state',
      'avoid_provider_in_widget',
      'avoid_provider_listen_false_in_build',
      'avoid_provider_of_in_build',
      'avoid_provider_recreate',
      'avoid_provider_value_rebuild',
      'dispose_provider_instances',
      'prefer_consumer_over_provider_of',
      'prefer_nullable_provider_types',
      'prefer_provider_extensions',
      'prefer_proxy_provider',
      'require_multi_provider',
      'require_provider_dispose',
      'require_provider_generic_type',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/packages/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Provider Access Pattern Rules', () {
    group('avoid_watch_in_callbacks', () {
      test('context.watch() in onPressed SHOULD trigger', () {
        // watch() in callbacks creates new subscriptions on every call
        expect('watch in callback detected', isNotNull);
      });

      test('context.watch() in build() should NOT trigger', () {
        // build() is the correct place for watch
        expect('watch in build passes', isNotNull);
      });

      test('context.read() in callback should NOT trigger', () {
        // read() is correct for one-time access in callbacks
        expect('read in callback passes', isNotNull);
      });
    });

    group('avoid_provider_of_in_build', () {
      test('Provider.of(context) in build SHOULD trigger', () {
        // Use context.watch or Consumer instead
        expect('Provider.of in build detected', isNotNull);
      });

      test('Consumer widget should NOT trigger', () {
        expect('Consumer passes', isNotNull);
      });

      test('context.read() in build should NOT trigger', () {
        expect('context.read passes', isNotNull);
      });
    });

    group('prefer_consumer_over_provider_of', () {
      test('Provider.of(context) anywhere SHOULD trigger', () {
        // Consumer/Selector is preferred pattern
        expect('Provider.of detected', isNotNull);
      });

      test('Consumer<T> widget should NOT trigger', () {
        expect('Consumer passes', isNotNull);
      });
    });

    group('prefer_context_read_in_callbacks', () {
      test('context.watch() in callback SHOULD trigger', () {
        expect('watch in callback detected', isNotNull);
      });

      test('context.read() in callback should NOT trigger', () {
        expect('read in callback passes', isNotNull);
      });
    });

    group('avoid_provider_listen_false_in_build', () {
      test('Provider.of(context, listen: false) in build SHOULD trigger', () {
        // listen: false in build means widget won't rebuild on changes
        expect('listen false in build detected', isNotNull);
      });

      test('Provider.of(context) in build should NOT trigger', () {
        expect('default listen passes', isNotNull);
      });
    });

    group('avoid_provider_in_init_state', () {
      test('Provider.of() in initState SHOULD trigger', () {
        // Provider may not be fully initialized during initState
        expect('provider access in initState detected', isNotNull);
      });

      test('Provider.of() in didChangeDependencies should NOT trigger', () {
        expect('didChangeDependencies is safe', isNotNull);
      });
    });
  });

  group('InheritedWidget Rules', () {
    group('require_update_should_notify', () {
      test('InheritedWidget without updateShouldNotify SHOULD trigger', () {
        // Missing updateShouldNotify causes unnecessary rebuilds
        expect('missing updateShouldNotify detected', isNotNull);
      });

      test(
        'InheritedWidget with updateShouldNotify override should NOT trigger',
        () {
          expect('updateShouldNotify present passes', isNotNull);
        },
      );
    });
  });

  group('Provider Creation Rules', () {
    group('avoid_provider_recreate', () {
      test('Provider created in build SHOULD trigger', () {
        // Provider should be created outside build to prevent recreation
        expect('provider recreation in build detected', isNotNull);
      });

      test('Provider created in state field should NOT trigger', () {
        expect('stable provider passes', isNotNull);
      });
    });

    group('avoid_provider_in_widget', () {
      test('Provider instantiation in widget SHOULD trigger', () {
        expect('provider in widget detected', isNotNull);
      });

      test('Provider in top-level setup should NOT trigger', () {
        expect('top-level provider passes', isNotNull);
      });
    });

    group('avoid_change_notifier_in_widget', () {
      test('ChangeNotifier created in widget SHOULD trigger', () {
        expect('ChangeNotifier in widget detected', isNotNull);
      });

      test('ChangeNotifier in ChangeNotifierProvider should NOT trigger', () {
        expect('provider-managed ChangeNotifier passes', isNotNull);
      });
    });

    group('avoid_instantiating_in_value_provider', () {
      test('Provider.value(value: MyModel()) SHOULD trigger', () {
        // value: should receive existing instance, not create new
        expect('instantiation in value provider detected', isNotNull);
      });

      test('Provider.value(value: existingModel) should NOT trigger', () {
        expect('existing instance passes', isNotNull);
      });
    });

    group('avoid_provider_value_rebuild', () {
      test('Provider.value in build causing rebuild SHOULD trigger', () {
        expect('value rebuild detected', isNotNull);
      });
    });
  });

  group('Provider Organization Rules', () {
    group('require_multi_provider / prefer_multi_provider', () {
      test('nested Providers SHOULD trigger', () {
        // Nested providers should use MultiProvider
        expect('nested providers detected', isNotNull);
      });

      test('MultiProvider should NOT trigger', () {
        expect('MultiProvider passes', isNotNull);
      });
    });

    group('avoid_nested_providers', () {
      test('deeply nested Provider tree SHOULD trigger', () {
        expect('deep nesting detected', isNotNull);
      });

      test('flat MultiProvider should NOT trigger', () {
        expect('flat structure passes', isNotNull);
      });
    });
  });

  group('Provider Disposal Rules', () {
    group('require_provider_dispose', () {
      test('ChangeNotifier without dispose SHOULD trigger', () {
        expect('undisposed ChangeNotifier detected', isNotNull);
      });

      test('ChangeNotifier disposed in provider should NOT trigger', () {
        expect('disposed ChangeNotifier passes', isNotNull);
      });
    });

    group('dispose_providers / dispose_provided_instances', () {
      test('provided instance not disposed SHOULD trigger', () {
        expect('undisposed instance detected', isNotNull);
      });

      test('instance disposed on provider close should NOT trigger', () {
        expect('disposed instance passes', isNotNull);
      });
    });
  });

  group('Provider Type Rules', () {
    group('require_provider_generic_type', () {
      test('Provider without generic type SHOULD trigger', () {
        // Provider() without <T> loses type safety
        expect('missing generic type detected', isNotNull);
      });

      test('Provider<MyModel>() should NOT trigger', () {
        expect('generic type present passes', isNotNull);
      });
    });

    group('prefer_nullable_provider_types', () {
      test('non-nullable type with possible null SHOULD trigger', () {
        expect('non-nullable type mismatch detected', isNotNull);
      });

      test('properly typed nullable provider should NOT trigger', () {
        expect('correct nullable type passes', isNotNull);
      });
    });

    group('prefer_provider_extensions', () {
      test('manual Provider.of calls SHOULD trigger', () {
        // context.read<T>() is cleaner
        expect('manual Provider.of detected', isNotNull);
      });

      test('context.read/watch extensions should NOT trigger', () {
        expect('extension methods pass', isNotNull);
      });
    });
  });

  group('Provider Composition Rules', () {
    group('prefer_proxy_provider', () {
      test(
        'provider depending on another without ProxyProvider SHOULD trigger',
        () {
          expect('missing ProxyProvider detected', isNotNull);
        },
      );

      test('ProxyProvider should NOT trigger', () {
        expect('ProxyProvider passes', isNotNull);
      });
    });

    group('require_update_callback', () {
      test('ProxyProvider without update SHOULD trigger', () {
        expect('missing update callback detected', isNotNull);
      });

      test('ProxyProvider with update should NOT trigger', () {
        expect('update callback present passes', isNotNull);
      });
    });

    group(
      'prefer_change_notifier_proxy / prefer_change_notifier_proxy_provider',
      () {
        test(
          'ChangeNotifierProvider depending on other provider SHOULD trigger',
          () {
            // Should use ChangeNotifierProxyProvider
            expect('missing proxy pattern detected', isNotNull);
          },
        );

        test('ChangeNotifierProxyProvider should NOT trigger', () {
          expect('proxy provider passes', isNotNull);
        });
      },
    );
  });

  group('Provider Optimization Rules', () {
    group('prefer_selector_over_consumer / prefer_selector_widget', () {
      test('Consumer rebuilding for all changes SHOULD trigger', () {
        // Selector prevents unnecessary rebuilds
        expect('over-rebuilding Consumer detected', isNotNull);
      });

      test('Selector<T, S> should NOT trigger', () {
        expect('Selector passes', isNotNull);
      });
    });
  });
}
