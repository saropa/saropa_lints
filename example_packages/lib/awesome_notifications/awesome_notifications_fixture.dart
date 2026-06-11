// ignore_for_file: unused_local_variable, unused_element, avoid_print

/// Fixture for all 7 awesome_notifications lint rules.
///
/// Minimal mock stubs of the package API are declared at the bottom of this
/// file so the fixture is self-contained and does not require the real package
/// as a dependency.  In a real project, the import is
/// `package:awesome_notifications/awesome_notifications.dart`.
///
/// Rules covered:
///   - awesome_notifications_non_static_listener            (ERROR)
///   - awesome_notifications_handler_wrong_parameter_type   (ERROR)
///   - awesome_notifications_missing_pragma_annotation      (WARNING)
///   - awesome_notifications_undeclared_channel_key         (WARNING)
///   - awesome_notifications_create_without_permission_check (WARNING)
///   - awesome_notifications_negative_notification_id        (WARNING + fix)
///   - awesome_notifications_listeners_before_display        (WARNING)
///
/// NOTE: rules gate on `package:awesome_notifications/` being imported.
/// Because this fixture uses a local stub instead of the real package import,
/// the import-gate never fires in an actual scan — these examples document
/// what the rule detects when the real import is present.
library;

// =============================================================================
// awesome_notifications_non_static_listener
// =============================================================================

class _NonStaticHandlerBad {
  Future<void> init() async {
    await AwesomeNotifications().setListeners(
      // expect_lint: awesome_notifications_non_static_listener
      onActionReceivedMethod: _handleAction,
    );
  }

  // Instance method — the package throws a runtime error for this.
  Future<void> _handleAction(ReceivedAction action) async {}
}

class _NonStaticHandlerGood {
  Future<void> init() async {
    // Static method with pragma — both rules satisfied.
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: _GoodHandlers.handleAction,
    );
  }
}

// =============================================================================
// awesome_notifications_handler_wrong_parameter_type
// =============================================================================

class _WrongParamTypeBad {
  Future<void> init() async {
    await AwesomeNotifications().setListeners(
      // expect_lint: awesome_notifications_handler_wrong_parameter_type
      // onActionReceivedMethod expects ReceivedAction, not ReceivedNotification.
      onActionReceivedMethod: _GoodHandlers.handleNotification,
    );
  }
}

class _WrongParamTypeGood {
  Future<void> init() async {
    // Correct type: onActionReceivedMethod receives ReceivedAction.
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: _GoodHandlers.handleAction,
    );
  }
}

// =============================================================================
// awesome_notifications_missing_pragma_annotation
// =============================================================================

class _MissingPragmaBad {
  Future<void> init() async {
    await AwesomeNotifications().setListeners(
      // expect_lint: awesome_notifications_missing_pragma_annotation
      // handleActionNoPragma is static but lacks @pragma('vm:entry-point').
      onActionReceivedMethod: _GoodHandlers.handleActionNoPragma,
    );
  }
}

class _MissingPragmaGood {
  Future<void> init() async {
    // Handler has @pragma('vm:entry-point') — preserved in release builds.
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: _GoodHandlers.handleAction,
    );
  }
}

// =============================================================================
// awesome_notifications_undeclared_channel_key
// =============================================================================

Future<void> undeclaredChannelKeyBad() async {
  await AwesomeNotifications().initialize(
    null,
    [NotificationChannel(channelKey: 'alerts', channelName: 'Alerts')],
  );
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: 1,
      // expect_lint: awesome_notifications_undeclared_channel_key
      // 'basic' is not in the initialize() channel list — notification silently
      // discarded.
      channelKey: 'basic',
      title: 'Hello',
    ),
  );
}

Future<void> undeclaredChannelKeyGood() async {
  await AwesomeNotifications().initialize(
    null,
    [NotificationChannel(channelKey: 'alerts', channelName: 'Alerts')],
  );
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: 1,
      // 'alerts' matches the declared channel — no lint.
      channelKey: 'alerts',
      title: 'Hello',
    ),
  );
}

// =============================================================================
// awesome_notifications_create_without_permission_check
// =============================================================================

Future<void> createWithoutPermissionBad() async {
  // No isNotificationAllowed() await — notification silently ignored on
  // Android 13+ and iOS if permission was not granted.
  // expect_lint: awesome_notifications_create_without_permission_check
  await AwesomeNotifications().createNotification(
    content: NotificationContent(id: 1, channelKey: 'alerts', title: 'Hi'),
  );
}

Future<void> createWithPermissionCheckGood() async {
  // Guard present — permission verified before creating notification.
  if (!await AwesomeNotifications().isNotificationAllowed()) return;
  await AwesomeNotifications().createNotification(
    content: NotificationContent(id: 1, channelKey: 'alerts', title: 'Hi'),
  );
}

// Suppressed: enclosing function has an 'allowed' bool parameter indicating
// the caller is responsible for the permission check.
Future<void> createWithAllowedParam(bool isAllowed) async {
  if (!isAllowed) return;
  await AwesomeNotifications().createNotification(
    content: NotificationContent(id: 1, channelKey: 'alerts', title: 'Hi'),
  );
}

// =============================================================================
// awesome_notifications_negative_notification_id
// =============================================================================

Future<void> negativeIdBad() async {
  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      // expect_lint: awesome_notifications_negative_notification_id
      // Negative ID is silently replaced by a random value — cancel(id) broken.
      id: -1,
      channelKey: 'alerts',
      title: 'Hi',
    ),
  );
}

Future<void> negativeIdGood() async {
  // Positive literal — ID is used as-is by the plugin.
  await AwesomeNotifications().createNotification(
    content: NotificationContent(id: 42, channelKey: 'alerts', title: 'Hi'),
  );
}

// =============================================================================
// awesome_notifications_listeners_before_display
// =============================================================================

Future<void> listenersTooLateBad() async {
  await AwesomeNotifications().initialize(null, []);
  // expect_lint: awesome_notifications_listeners_before_display
  // createNotification fires before setListeners — events are lost.
  await AwesomeNotifications().createNotification(
    content: NotificationContent(id: 1, channelKey: 'alerts', title: 'Hi'),
  );
  await AwesomeNotifications().setListeners(
    onActionReceivedMethod: _GoodHandlers.handleAction,
  );
}

Future<void> listenersBeforeDisplayGood() async {
  await AwesomeNotifications().initialize(null, []);
  // setListeners is registered first — events will be delivered.
  await AwesomeNotifications().setListeners(
    onActionReceivedMethod: _GoodHandlers.handleAction,
  );
  await AwesomeNotifications().createNotification(
    content: NotificationContent(id: 1, channelKey: 'alerts', title: 'Hi'),
  );
}

// =============================================================================
// Shared compliant handler class used by GOOD examples above.
// =============================================================================

class _GoodHandlers {
  /// Correctly typed ReceivedAction handler with @pragma.
  @pragma('vm:entry-point')
  static Future<void> handleAction(ReceivedAction action) async {}

  /// Correctly typed ReceivedNotification handler with @pragma.
  @pragma('vm:entry-point')
  static Future<void> handleNotification(
    ReceivedNotification notification,
  ) async {}

  /// Static but NO @pragma — triggers missing_pragma_annotation lint.
  static Future<void> handleActionNoPragma(ReceivedAction action) async {}
}

// =============================================================================
// Minimal mock stubs — stand-ins for the real awesome_notifications types.
// These allow the fixture to compile without adding awesome_notifications as
// a dependency of example_packages.
// =============================================================================

/// Mock of AwesomeNotifications singleton from awesome_notifications.
class AwesomeNotifications {
  Future<bool> initialize(
    String? defaultIcon,
    List<NotificationChannel> channels,
  ) async => true;

  Future<bool> setListeners({
    Future<void> Function(ReceivedAction)? onActionReceivedMethod,
    Future<void> Function(ReceivedNotification)? onNotificationCreatedMethod,
    Future<void> Function(ReceivedNotification)? onNotificationDisplayedMethod,
    Future<void> Function(ReceivedAction)? onDismissActionReceivedMethod,
  }) async => true;

  Future<bool> createNotification({NotificationContent? content}) async => true;

  Future<bool> isNotificationAllowed() async => false;

  Future<bool> requestPermissionToSendNotifications() async => false;

  Future<bool> cancel(int id) async => true;
}

/// Mock of NotificationContent.
class NotificationContent {
  const NotificationContent({
    required this.id,
    required this.channelKey,
    this.title,
  });
  final int id;
  final String channelKey;
  final String? title;
}

/// Mock of NotificationChannel.
class NotificationChannel {
  const NotificationChannel({
    required this.channelKey,
    required this.channelName,
  });
  final String channelKey;
  final String channelName;
}

/// Mock of ReceivedAction (used by action/dismiss handlers).
class ReceivedAction {}

/// Mock of ReceivedNotification (used by created/displayed handlers).
class ReceivedNotification {}
