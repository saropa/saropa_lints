# Using saropa_lints with Firebase

This guide explains how saropa_lints enhances your Firebase development with specialized rules that catch common issues with Firestore, Analytics, FCM, and other Firebase services.

## Why This Matters

Firebase services have patterns that cause **performance issues, cost overruns, and silent failures** - your app compiles fine but drains battery, exceeds quotas, or loses data.

Standard linters see valid Dart code. saropa_lints understands Firebase's requirements and billing implications.

## What Firebase Issues Are Caught

| Issue Type | What Happens | Rule |
|------------|--------------|------|
| Unbounded Firestore query | Reads entire collection, massive costs | `avoid_firestore_unbounded_query` |
| Database calls in build() | Excessive reads, poor UX | `avoid_database_in_build` |
| Missing Firebase.initializeApp | Crash on first Firebase call | `require_firebase_init_before_use` |
| Invalid Analytics event name | Events silently dropped | `incorrect_firebase_event_name` |
| Invalid Analytics parameter | Parameters silently dropped | `incorrect_firebase_parameter_name` |
| Firestore in widget build | Excessive reads, billing spikes | `avoid_firestore_in_widget_build` |
| Missing batch writes | Slow, expensive multiple writes | `prefer_firestore_batch_write` |
| Missing FCM token refresh | Push notifications stop working | `require_fcm_token_refresh_handler` |
| Missing background handler | Background messages lost | `require_background_message_handler` |
| Missing Crashlytics user ID | Can't identify affected users | `require_crashlytics_user_id` |
| Missing App Check | API abuse vulnerability | `require_firebase_app_check` |

## What saropa_lints Catches

### Unbounded Firestore Queries

```dart
// BAD - reads ENTIRE collection (could be millions of docs!)
final snapshot = await FirebaseFirestore.instance
    .collection('users')
    .get();  // No limit!

// GOOD - always limit queries
final snapshot = await FirebaseFirestore.instance
    .collection('users')
    .limit(50)
    .get();

// GOOD - paginate for more
final snapshot = await FirebaseFirestore.instance
    .collection('users')
    .orderBy('createdAt')
    .startAfterDocument(lastDoc)
    .limit(50)
    .get();
```

**Rule**: `avoid_firestore_unbounded_query`

### Database Calls in build()

```dart
// BAD - fetches data on every rebuild
Widget build(BuildContext context) {
  final users = FirebaseFirestore.instance
      .collection('users')
      .get();  // Called repeatedly!

  return FutureBuilder(...);
}

// GOOD - fetch in initState or use StreamBuilder
class _MyWidgetState extends State<MyWidget> {
  late Future<QuerySnapshot> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = FirebaseFirestore.instance
        .collection('users')
        .limit(50)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _usersFuture,
      builder: (context, snapshot) => ...,
    );
  }
}
```

**Rule**: `avoid_database_in_build`, `avoid_firestore_in_widget_build`

### Missing Firebase Initialization

```dart
// BAD - crashes on first Firebase call
void main() {
  runApp(MyApp());  // Firebase not initialized!
}

// Later...
final user = FirebaseAuth.instance.currentUser;  // Crash!

// GOOD - initialize before runApp
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}
```

**Rule**: `require_firebase_init_before_use`

### Invalid Analytics Event Names

```dart
// BAD - event silently dropped (invalid characters)
FirebaseAnalytics.instance.logEvent(
  name: 'User-Clicked-Button',  // Hyphens not allowed!
);

// BAD - reserved prefix
FirebaseAnalytics.instance.logEvent(
  name: 'firebase_custom_event',  // 'firebase_' is reserved!
);

// BAD - starts with number
FirebaseAnalytics.instance.logEvent(
  name: '123_event',  // Must start with letter!
);

// GOOD - snake_case, starts with letter
FirebaseAnalytics.instance.logEvent(
  name: 'user_clicked_button',
);
```

**Rule**: `incorrect_firebase_event_name`

### Missing Batch Writes

```dart
// BAD - N separate writes (slow, expensive)
for (final user in users) {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.id)
      .set(user.toJson());  // N network calls!
}

// GOOD - single batch write
final batch = FirebaseFirestore.instance.batch();
for (final user in users) {
  final ref = FirebaseFirestore.instance
      .collection('users')
      .doc(user.id);
  batch.set(ref, user.toJson());
}
await batch.commit();  // One network call!
```

**Rule**: `prefer_firestore_batch_write`

### Missing FCM Token Refresh Handler

```dart
// BAD - token expires, push notifications stop
void setupFCM() async {
  final token = await FirebaseMessaging.instance.getToken();
  await saveTokenToServer(token);
  // Token never refreshed!
}

// GOOD - handle token refresh
void setupFCM() async {
  final token = await FirebaseMessaging.instance.getToken();
  await saveTokenToServer(token);

  // Listen for token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    saveTokenToServer(newToken);
  });
}
```

**Rule**: `require_fcm_token_refresh_handler`

### Missing Background Message Handler

```dart
// BAD - background messages lost
void main() async {
  await Firebase.initializeApp();
  runApp(MyApp());
}

// GOOD - register background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Handle background message
}

void main() async {
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(MyApp());
}
```

**Rule**: `require_background_message_handler`

## Recommended Setup

### 1. Update pubspec.yaml

```yaml
dependencies:
  firebase_core: ^2.24.0
  cloud_firestore: ^4.13.0
  firebase_auth: ^4.16.0
  firebase_analytics: ^10.7.0
  firebase_messaging: ^14.7.0
  firebase_crashlytics: ^3.4.0

dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.0.0
```

### 2. Update analysis_options.yaml

```yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  saropa_lints:
    tier: recommended  # essential | recommended | professional | comprehensive | insanity
```

### 3. Run the linter

```bash
dart run custom_lint
```

## Rule Summary

| Rule | Tier | What It Catches |
|------|------|-----------------|
| `avoid_firestore_unbounded_query` | essential | Queries without limit() |
| `avoid_database_in_build` | essential | Database calls in build methods |
| `require_firebase_init_before_use` | essential | Firebase used before initialization |
| `incorrect_firebase_event_name` | essential | Invalid Analytics event names |
| `incorrect_firebase_parameter_name` | recommended | Invalid Analytics parameter names |
| `avoid_firestore_in_widget_build` | essential | Firestore queries in build() |
| `prefer_firestore_batch_write` | recommended | Individual writes in loops |
| `require_fcm_token_refresh_handler` | recommended | Missing token refresh listener |
| `require_background_message_handler` | recommended | Missing background message handler |
| `require_crashlytics_user_id` | professional | Crashlytics without user identification |
| `require_firebase_app_check` | professional | Missing App Check protection |

## Common Patterns

### Proper Firebase Initialization

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configure Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  // Configure FCM
  FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

  // Set user ID for Crashlytics (when available)
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
    }
  });

  runApp(const MyApp());
}

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Handle background message
}
```

### Firestore Repository Pattern

```dart
class UserRepository {
  final _firestore = FirebaseFirestore.instance;
  final _collection = 'users';

  // Always limit queries
  Future<List<User>> getUsers({int limit = 50}) async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => User.fromJson(doc.data()))
        .toList();
  }

  // Use batch for multiple writes
  Future<void> saveUsers(List<User> users) async {
    final batch = _firestore.batch();

    for (final user in users) {
      final ref = _firestore.collection(_collection).doc(user.id);
      batch.set(ref, user.toJson());
    }

    await batch.commit();
  }

  // Use transactions for atomic operations
  Future<void> transferCredits(String fromId, String toId, int amount) async {
    await _firestore.runTransaction((transaction) async {
      final fromRef = _firestore.collection(_collection).doc(fromId);
      final toRef = _firestore.collection(_collection).doc(toId);

      final fromSnap = await transaction.get(fromRef);
      final toSnap = await transaction.get(toRef);

      final fromCredits = fromSnap.data()?['credits'] ?? 0;
      final toCredits = toSnap.data()?['credits'] ?? 0;

      transaction.update(fromRef, {'credits': fromCredits - amount});
      transaction.update(toRef, {'credits': toCredits + amount});
    });
  }
}
```

### Analytics Event Constants

```dart
// Define event names as constants to catch typos
class AnalyticsEvents {
  // User actions
  static const String userSignedUp = 'user_signed_up';
  static const String userLoggedIn = 'user_logged_in';
  static const String userLoggedOut = 'user_logged_out';

  // Feature usage
  static const String featureUsed = 'feature_used';
  static const String settingsChanged = 'settings_changed';

  // E-commerce
  static const String itemViewed = 'item_viewed';
  static const String addedToCart = 'added_to_cart';
  static const String purchaseCompleted = 'purchase_completed';
}

class AnalyticsParams {
  static const String itemId = 'item_id';
  static const String itemName = 'item_name';
  static const String featureName = 'feature_name';
  static const String value = 'value';
}

// Usage
FirebaseAnalytics.instance.logEvent(
  name: AnalyticsEvents.itemViewed,
  parameters: {
    AnalyticsParams.itemId: product.id,
    AnalyticsParams.itemName: product.name,
  },
);
```

## Security Rules Reminder

saropa_lints catches client-side issues. Don't forget server-side security:

```javascript
// Firestore Rules - always validate!
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }
  }
}
```

## Contributing

Have ideas for more Firebase rules? Found a pattern we should catch? Contributions are welcome!

See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for guidelines on adding new rules.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)
- [Firebase Documentation](https://firebase.google.com/docs/flutter/setup)

---

Questions about Firebase rules? Open an issue - we're happy to help.
