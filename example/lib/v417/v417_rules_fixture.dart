// ignore_for_file: unused_field, unused_local_variable, avoid_print
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
// ignore_for_file: unused_element, dead_code

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =============================================================================
// v4.1.7 Test Fixtures - State Management Rules
// =============================================================================

// BAD: Riverpod used only for network client
// expect_lint: avoid_riverpod_for_network_only
final apiProvider = Provider((ref) => ApiClient());

// GOOD: Riverpod with actual state management
final userProvider = Provider((ref) {
  final api = ref.watch(apiProvider);
  return UserService(api);
});

// BAD: Large Bloc with too many handlers
// expect_lint: avoid_large_bloc
class KitchenSinkBloc extends Bloc<AppEvent, AppState> {
  KitchenSinkBloc() : super(AppState()) {
    on<LoadUser>(_onLoadUser);
    on<UpdateProfile>(_onUpdateProfile);
    on<LoadOrders>(_onLoadOrders);
    on<ProcessPayment>(_onProcessPayment);
    on<SendNotification>(_onSendNotification);
    on<UpdateSettings>(_onUpdateSettings);
    on<RefreshData>(_onRefreshData);
    on<SyncData>(_onSyncData);
  }

  void _onLoadUser(LoadUser event, Emitter<AppState> emit) {}
  void _onUpdateProfile(UpdateProfile event, Emitter<AppState> emit) {}
  void _onLoadOrders(LoadOrders event, Emitter<AppState> emit) {}
  void _onProcessPayment(ProcessPayment event, Emitter<AppState> emit) {}
  void _onSendNotification(SendNotification event, Emitter<AppState> emit) {}
  void _onUpdateSettings(UpdateSettings event, Emitter<AppState> emit) {}
  void _onRefreshData(RefreshData event, Emitter<AppState> emit) {}
  void _onSyncData(SyncData event, Emitter<AppState> emit) {}
}

// GOOD: Focused Bloc
class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc() : super(UserState()) {
    on<LoadUser>(_onLoadUser);
    on<UpdateUser>(_onUpdateUser);
  }

  void _onLoadUser(LoadUser event, Emitter<UserState> emit) {}
  void _onUpdateUser(UpdateUser event, Emitter<UserState> emit) {}
}

// BAD: GetX static context usage
void navigateWithGetX() {
  // expect_lint: avoid_getx_static_context
  Get.offNamed('/home');

  // expect_lint: avoid_getx_static_context
  Get.dialog(AlertDialog(title: Text('Hello')));
}

// =============================================================================
// v4.1.7 Test Fixtures - Performance Rules
// =============================================================================

// BAD: Heavy computation on main thread
Future<List<dynamic>> parseJsonOnMain(String json) async {
  // expect_lint: require_isolate_for_heavy
  return jsonDecode(json);
}

// GOOD: Using compute for heavy work
Future<List<dynamic>> parseJsonInIsolate(String json) async {
  return compute(_decodeJson, json);
}

List<dynamic> _decodeJson(String json) => jsonDecode(json);

// BAD: Finalizer without dispose
class ResourceWithFinalizer {
  // expect_lint: avoid_finalizer_misuse
  static final Finalizer<ResourceWithFinalizer> _finalizer =
      Finalizer((r) => r._cleanup());

  ResourceWithFinalizer() {
    _finalizer.attach(this, this);
  }

  void _cleanup() {}
}

// GOOD: Proper dispose pattern
class ResourceWithDispose {
  void dispose() {
    // Cleanup resources
  }
}

// =============================================================================
// v4.1.7 Test Fixtures - Security Rules
// =============================================================================

// BAD: Sensitive data to clipboard
void copyPassword(String password) {
  // expect_lint: avoid_sensitive_data_in_clipboard
  Clipboard.setData(ClipboardData(text: password));
}

void copyToken(String apiKey) {
  // expect_lint: avoid_sensitive_data_in_clipboard
  Clipboard.setData(ClipboardData(text: apiKey));
}

// GOOD: Public data to clipboard
void copyPublicId(String userId) {
  Clipboard.setData(ClipboardData(text: userId)); // OK - not sensitive
}

// BAD: Encryption key as field
class BadEncryptionService {
  // expect_lint: avoid_encryption_key_in_memory
  final String encryptionKey;

  BadEncryptionService(this.encryptionKey);
}

// GOOD: Load key on demand
class GoodEncryptionService {
  Future<String> encrypt(String data) async {
    final key = await _loadKeyFromSecureStorage();
    try {
      return _doEncrypt(data, key);
    } finally {
      // Clear key after use
    }
  }

  Future<String> _loadKeyFromSecureStorage() async => 'key';
  String _doEncrypt(String data, String key) => data;
}

// =============================================================================
// v4.1.7 Test Fixtures - Caching Rules
// =============================================================================

// BAD: Cache without expiration
// expect_lint: require_cache_expiration
// expect_lint: avoid_unbounded_cache_growth
class SimpleCacheService {
  final Map<String, Object> _cache = {};

  Object? get(String key) => _cache[key];
  void set(String key, Object value) => _cache[key] = value;
}

// GOOD: Cache with expiration and size limit
class GoodCacheService {
  final Map<String, CacheEntry> _cache = {};
  final Duration ttl = Duration(minutes: 5);
  static const int maxSize = 100;

  Object? get(String key) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) return null;
    return entry.value;
  }

  void set(String key, Object value) {
    if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = CacheEntry(value, DateTime.now().add(ttl));
  }
}

// BAD: Cache with non-primitive key
class BadCacheKey {
  // expect_lint: require_cache_key_uniqueness
  final Map<Request, Response> _cache = {};
}

// GOOD: String key
class GoodCacheKey {
  final Map<String, Response> _cache = {};
}

// =============================================================================
// v4.1.7 Test Fixtures - Widget Rules
// =============================================================================

// BAD: DateFormat without locale
class BadDateFormatWidget extends StatelessWidget {
  const BadDateFormatWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: require_locale_for_text
    final date = DateFormat.yMd().format(DateTime.now());
    return Text(date);
  }
}

// GOOD: DateFormat with locale
class GoodDateFormatWidget extends StatelessWidget {
  const GoodDateFormatWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMd('en_US').format(DateTime.now());
    return Text(date);
  }
}

// BAD: Destructive dialog without barrierDismissible
void showDeleteDialog(BuildContext context) {
  // expect_lint: require_dialog_barrier_consideration
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete account?'),
      content: Text('This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // Delete logic
          },
          child: Text('Delete'),
        ),
      ],
    ),
  );
}

// GOOD: Destructive dialog with barrierDismissible: false
void showDeleteDialogGood(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // Explicit
    builder: (context) => AlertDialog(
      title: Text('Delete account?'),
      content: Text('This action cannot be undone.'),
    ),
  );
}

// =============================================================================
// v4.1.7 Test Fixtures - WebSocket Rules
// =============================================================================

// BAD: WebSocket without reconnection
// expect_lint: require_websocket_reconnection
class BadChatService {
  late WebSocketChannel _channel;

  void connect(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    // No reconnection logic!
  }
}

// GOOD: WebSocket with reconnection
class GoodChatService {
  WebSocketChannel? _channel;
  int _retryCount = 0;

  void connect(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _channel!.stream.listen(
      _onMessage,
      onDone: _reconnect,
      onError: (e) => _reconnect(),
    );
  }

  void _onMessage(dynamic data) {}

  void _reconnect() {
    final delay = Duration(seconds: _retryCount++);
    Future.delayed(delay, () => connect('wss://example.com'));
  }
}

// =============================================================================
// v4.1.7 Test Fixtures - Currency Rules
// =============================================================================

// BAD: Amount without currency
// expect_lint: require_currency_code_with_amount
class BadPrice {
  final double amount; // What currency?

  BadPrice(this.amount);
}

// GOOD: Amount with currency
class GoodPrice {
  final double amount;
  final String currency;

  GoodPrice(this.amount, this.currency);
}

// =============================================================================
// v4.1.7 Test Fixtures - DI Rules
// =============================================================================

// BAD: Eager singleton for expensive service
void setupBadDI() {
  // expect_lint: prefer_lazy_singleton_registration
  GetIt.I.registerSingleton(DatabaseService());
}

// GOOD: Lazy singleton
void setupGoodDI() {
  GetIt.I.registerLazySingleton(() => DatabaseService());
}

// =============================================================================
// Mock Classes
// =============================================================================

class Provider<T> {
  final T Function(dynamic ref) create;
  Provider(this.create);
}

class ApiClient {}

class UserService {
  UserService(ApiClient api);
}

abstract class Bloc<E, S> {
  final S _state;
  Bloc(this._state);
  void on<T>(void Function(T, Emitter<S>) handler) {}
}

typedef Emitter<S> = void Function(S);

class AppEvent {}

class LoadUser extends AppEvent {}

class UpdateProfile extends AppEvent {}

class LoadOrders extends AppEvent {}

class ProcessPayment extends AppEvent {}

class SendNotification extends AppEvent {}

class UpdateSettings extends AppEvent {}

class RefreshData extends AppEvent {}

class SyncData extends AppEvent {}

class AppState {}

class UserEvent {}

class UpdateUser extends UserEvent {}

class UserState {}

class Get {
  static void offNamed(String route) {}
  static void dialog(Widget widget) {}
  static T find<T>() => throw UnimplementedError();
}

class CacheEntry {
  final Object value;
  final DateTime expiresAt;
  CacheEntry(this.value, this.expiresAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class Request {}

class Response {}

class DateFormat {
  DateFormat.yMd([String? locale]);
  String format(DateTime date) => '';
}

class WebSocketChannel {
  static WebSocketChannel connect(Uri uri) => WebSocketChannel._();
  WebSocketChannel._();
  Stream<dynamic> get stream => Stream.empty();
}

class DatabaseService {}

class GetIt {
  static final I = GetIt._();
  GetIt._();
  void registerSingleton<T>(T instance) {}
  void registerLazySingleton<T>(T Function() factory) {}
}
