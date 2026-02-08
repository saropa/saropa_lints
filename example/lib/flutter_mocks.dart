// ignore_for_file: unused_element, avoid_unused_constructor_parameters
// ignore_for_file: avoid_context_in_static_methods
// Mock Flutter types for lint rule testing
// These mocks allow testing lint rules without requiring the Flutter SDK

// ============================================================================
// Core Flutter types
// ============================================================================

class BuildContext {
  bool get mounted => true;
}

abstract class Widget {
  const Widget({Key? key});
}

class Key {
  const Key(String value);
}

// ============================================================================
// StatelessWidget / StatefulWidget
// ============================================================================

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});
  Widget build(BuildContext context);
}

abstract class StatefulWidget extends Widget {
  const StatefulWidget({super.key});
  State createState();
}

abstract class State<T extends StatefulWidget> {
  T get widget => throw UnimplementedError();
  BuildContext get context => BuildContext();
  bool get mounted => true;
  void setState(void Function() fn) {}
  void dispose() {}
  void initState() {}
  void didUpdateWidget(T oldWidget) {}
  Widget build(BuildContext context);
}

// ============================================================================
// Common widgets
// ============================================================================

class Container extends Widget {
  const Container({
    super.key,
    Widget? child,
    dynamic alignment,
    dynamic padding,
    dynamic margin,
    dynamic constraints,
    dynamic color,
    dynamic decoration,
    dynamic transform,
    double? width,
    double? height,
  });
}

class SizedBox extends Widget {
  const SizedBox({super.key, double? width, double? height, Widget? child});
  const SizedBox.square({super.key, double? dimension, Widget? child});
  const SizedBox.shrink({super.key, Widget? child});
  const SizedBox.expand({super.key, Widget? child});
}

class Padding extends Widget {
  const Padding({super.key, required dynamic padding, Widget? child});
}

class Align extends Widget {
  const Align({super.key, dynamic alignment, Widget? child});
}

class Center extends Widget {
  const Center({super.key, Widget? child});
}

class ConstrainedBox extends Widget {
  const ConstrainedBox(
      {super.key, required dynamic constraints, Widget? child});
}

class Column extends Widget {
  const Column({
    super.key,
    List<Widget>? children,
    MainAxisSize mainAxisSize = MainAxisSize.max,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    TextBaseline? textBaseline,
  });
}

class Row extends Widget {
  const Row({
    super.key,
    List<Widget>? children,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    TextBaseline? textBaseline,
  });
}

class Flex extends Widget {
  const Flex({
    super.key,
    List<Widget>? children,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    TextBaseline? textBaseline,
  });
}

class Expanded extends Widget {
  const Expanded({super.key, int flex = 1, required Widget child});
}

class Flexible extends Widget {
  const Flexible({super.key, int flex = 1, required Widget child});
}

class Spacer extends Widget {
  const Spacer({super.key, int flex = 1});
}

class Stack extends Widget {
  const Stack({super.key, List<Widget>? children});
}

class IndexedStack extends Stack {
  const IndexedStack({super.key, int? index, super.children});
}

/// Mock for `package:indexed` Indexer widget which extends Stack.
class Indexer extends Stack {
  const Indexer({super.key, super.children});
}

class Positioned extends Widget {
  const Positioned({
    super.key,
    double? left,
    double? top,
    double? right,
    double? bottom,
    required Widget child,
  });
}

class AnimatedPositioned extends Widget {
  const AnimatedPositioned({
    super.key,
    double? left,
    double? top,
    required Widget child,
    required Duration duration,
  });
}

class PositionedDirectional extends Widget {
  const PositionedDirectional({
    super.key,
    double? start,
    double? top,
    required Widget child,
  });
}

class Wrap extends Widget {
  const Wrap({super.key, List<Widget>? children, double spacing = 0.0});
}

class Table extends Widget {
  const Table({super.key, List<TableRow>? children});
}

class TableRow extends Widget {
  const TableRow({super.key, List<Widget>? children});
}

class TableCell extends Widget {
  const TableCell({super.key, required Widget child});
}

class IntrinsicHeight extends Widget {
  const IntrinsicHeight({super.key, Widget? child});
}

class IntrinsicWidth extends Widget {
  const IntrinsicWidth({super.key, Widget? child});
}

class GridView extends Widget {
  const GridView({super.key, List<Widget>? children, bool shrinkWrap = false});
  const GridView.builder({
    super.key,
    int? itemCount,
    Widget Function(BuildContext, int)? itemBuilder,
    required dynamic gridDelegate,
    bool shrinkWrap = false,
  });
}

class LimitedBox extends Widget {
  const LimitedBox(
      {super.key, double maxHeight = double.infinity, Widget? child});
}

enum MainAxisSize { min, max }

enum CrossAxisAlignment { start, end, center, stretch, baseline }

enum TextBaseline { alphabetic, ideographic }

class Text extends Widget {
  const Text(String data, {super.key});
}

class Icon extends Widget {
  const Icon(dynamic icon, {super.key});
}

class Semantics extends Widget {
  const Semantics({super.key, String? label, Widget? child});
}

// ============================================================================
// Image widgets
// ============================================================================

class CircleAvatar extends Widget {
  const CircleAvatar({
    super.key,
    dynamic backgroundImage,
    String? semanticLabel,
    void Function(Object, StackTrace?)? onBackgroundImageError,
  });
}

class NetworkImage {
  const NetworkImage(String url);
}

class Badge extends Widget {
  const Badge({super.key, Widget? label, Widget? child});
}

// ============================================================================
// Form widgets
// ============================================================================

class TextField extends Widget {
  const TextField(
      {super.key,
      TextEditingController? controller,
      FocusNode? focusNode,
      bool autofocus = false});
}

class TextFormField extends Widget {
  const TextFormField({super.key});
}

// ============================================================================
// Scroll widgets
// ============================================================================

class ListView extends Widget {
  const ListView(
      {super.key,
      List<Widget>? children,
      dynamic physics,
      bool shrinkWrap = false});
  const ListView.builder({
    super.key,
    int? itemCount,
    Widget Function(BuildContext, int)? itemBuilder,
    dynamic physics,
    bool shrinkWrap = false,
  });
}

class SingleChildScrollView extends Widget {
  const SingleChildScrollView({
    super.key,
    Widget? child,
    dynamic physics,
    Axis scrollDirection = Axis.vertical,
  });
}

class CustomScrollView extends Widget {
  const CustomScrollView({super.key, List<Widget>? slivers, dynamic physics});
}

// ============================================================================
// Material widgets
// ============================================================================

class Theme {
  static ThemeData of(BuildContext context) => ThemeData();
}

class ThemeData {
  dynamic get primaryColor => null;
}

class Scaffold extends Widget {
  const Scaffold({super.key, Widget? body, Widget? appBar});
}

class AppBar extends Widget {
  const AppBar({super.key, Widget? title});
}

class SnackBar extends Widget {
  const SnackBar({super.key, required Widget content, Duration? duration});
}

class ScaffoldMessenger {
  static ScaffoldMessengerState of(BuildContext context) =>
      ScaffoldMessengerState();
}

class ScaffoldMessengerState {
  void showSnackBar(SnackBar snackBar) {}
  void clearSnackBars() {}
}

// ============================================================================
// Dialog
// ============================================================================

Future<T?> showDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
}) async {
  return null;
}

class AlertDialog extends Widget {
  const AlertDialog(
      {super.key, Widget? title, Widget? content, List<Widget>? actions});
}

class SimpleDialog extends Widget {
  const SimpleDialog({super.key, Widget? title, List<Widget>? children});
}

// ============================================================================
// Animation
// ============================================================================

class AnimationController {
  AnimationController({required dynamic vsync, Duration? duration});
  void dispose() {}
  double get value => 0.0;
}

abstract class Animation<T> {
  T get value;
}

class CurvedAnimation implements Animation<double> {
  CurvedAnimation({required Animation<double> parent, required dynamic curve});
  @override
  double get value => 0.0;
}

/// Axis enum for SizeTransition
enum Axis { horizontal, vertical }

/// Curves for animations
class Curves {
  static const dynamic easeIn = null;
  static const dynamic easeOut = null;
  static const dynamic linear = null;
}

/// Transition widgets for animation rules testing
class ScaleTransition extends Widget {
  const ScaleTransition({
    super.key,
    required Animation<double> scale,
    Widget? child,
  });
}

class FadeTransition extends Widget {
  const FadeTransition({
    super.key,
    required Animation<double> opacity,
    Widget? child,
  });
}

class SlideTransition extends Widget {
  const SlideTransition({
    super.key,
    required Animation<dynamic> position,
    Widget? child,
  });
}

class RotationTransition extends Widget {
  const RotationTransition({
    super.key,
    required Animation<double> turns,
    Widget? child,
  });
}

class SizeTransition extends Widget {
  const SizeTransition({
    super.key,
    required Animation<double> sizeFactor,
    Axis axis = Axis.vertical,
    double axisAlignment = 0.0,
    Widget? child,
  });
}

mixin SingleTickerProviderStateMixin<T extends StatefulWidget> on State<T> {}

// ============================================================================
// Timer / Stream
// ============================================================================

class Timer {
  Timer(Duration duration, void Function() callback);
  Timer.periodic(Duration duration, void Function(Timer) callback);
  void cancel() {}
}

class StreamSubscription<T> {
  Future<void> cancel() async {}
}

class StreamController<T> {
  Stream<T> get stream => Stream.empty();
  void close() {}
}

// ============================================================================
// Icons
// ============================================================================

class Icons {
  static const dynamic notifications = null;
  static const dynamic mail = null;
  static const dynamic star = null;
  static const dynamic home = null;
  static const dynamic search = null;
  static const dynamic add = null;
  static const dynamic person = null;
  static const dynamic settings = null;
  static const dynamic help = null;
}

// ============================================================================
// Colors
// ============================================================================

class Colors {
  static const dynamic red = null;
  static const dynamic blue = null;
  static const dynamic black = null;
}

// ============================================================================
// Alignment
// ============================================================================

class Alignment {
  static const Alignment topLeft = Alignment._();
  static const Alignment center = Alignment._();
  static const Alignment bottomRight = Alignment._();
  const Alignment._();
}

// ============================================================================
// EdgeInsets
// ============================================================================

class EdgeInsets {
  const EdgeInsets.all(double value);
  const EdgeInsets.symmetric({double? horizontal, double? vertical});
}

// ============================================================================
// BoxConstraints
// ============================================================================

class BoxConstraints {
  const BoxConstraints({double? maxWidth, double? minWidth});
  const BoxConstraints.tightFor({double? width, double? height});
}

// ============================================================================
// Physics
// ============================================================================

class NeverScrollableScrollPhysics {
  const NeverScrollableScrollPhysics();
}

class AlwaysScrollableScrollPhysics {
  const AlwaysScrollableScrollPhysics();
}

// ============================================================================
// VoidCallback
// ============================================================================

typedef VoidCallback = void Function();

// ============================================================================
// Debug printing
// ============================================================================

void debugPrint(String? message, {int? wrapWidth}) {}

// ============================================================================
// Image widget
// ============================================================================

class Image extends Widget {
  const Image({super.key});
  const Image.network(String url, {Key? key});
  const Image.asset(String name, {Key? key});
}

// ============================================================================
// Controllers
// ============================================================================

class TextEditingController {
  TextEditingController({String? text});
  void dispose() {}
}

class TabController {
  TabController({required int length, required dynamic vsync});
  void dispose() {}
}

class PageController {
  PageController({int initialPage = 0});
  void dispose() {}
}

class FocusNode {
  FocusNode();
  void dispose() {}
}

// ============================================================================
// Tab widgets
// ============================================================================

class TabBar extends Widget {
  const TabBar({super.key, TabController? controller, List<Tab>? tabs});
}

class Tab extends Widget {
  const Tab({super.key, String? text, Widget? icon});
}

// ============================================================================
// PageView
// ============================================================================

class PageView extends Widget {
  const PageView(
      {super.key, PageController? controller, List<Widget>? children});
}

// ============================================================================
// Buttons
// ============================================================================

class ElevatedButton extends Widget {
  const ElevatedButton({super.key, VoidCallback? onPressed, Widget? child});
}

class TextButton extends Widget {
  const TextButton({super.key, VoidCallback? onPressed, Widget? child});
}

// ============================================================================
// Navigation
// ============================================================================

class Navigator {
  static void pop<T>(BuildContext context, [T? result]) {}
  static NavigatorState of(BuildContext context) => NavigatorState();
}

class NavigatorState {
  void pop<T>([T? result]) {}
  Future<T?> pushNamed<T>(String routeName, {Object? arguments}) async => null;
}

class BottomNavigationBar extends Widget {
  const BottomNavigationBar({super.key, List<BottomNavigationBarItem>? items});
}

class BottomNavigationBarItem {
  const BottomNavigationBarItem({required Widget icon, String? label});
}

// ============================================================================
// Icons (more)
// ============================================================================

// ============================================================================
// Autocomplete
// ============================================================================

class Autocomplete<T extends Object> extends Widget {
  const Autocomplete({
    super.key,
    required Iterable<T> Function(TextEditingValue) optionsBuilder,
    Widget Function(
            BuildContext, TextEditingController, FocusNode, VoidCallback)?
        fieldViewBuilder,
  });
}

class TextEditingValue {
  const TextEditingValue({String text = ''});
}

// ============================================================================
// ValueNotifier
// ============================================================================

class ValueNotifier<T> {
  ValueNotifier(T value);
  void dispose() {}
}

class ChangeNotifier {
  void dispose() {}
}

// ============================================================================
// Provider (mock)
// ============================================================================

class Provider<T> extends Widget {
  const Provider({
    super.key,
    required T Function(BuildContext) create,
    void Function(BuildContext, T)? dispose,
    Widget? child,
  });
  const Provider.value({
    super.key,
    required T value,
    Widget? child,
  });
}

class MultiProvider extends Widget {
  const MultiProvider({
    super.key,
    required List<Widget> providers,
    Widget? child,
  });
}

class ChangeNotifierProvider<T extends ChangeNotifier> extends Widget {
  const ChangeNotifierProvider({
    super.key,
    required T Function(BuildContext) create,
    Widget? child,
  });
}

// ============================================================================
// BLoC (mock)
// ============================================================================

abstract class Bloc<Event, State> {
  Bloc(State initialState);
}

class BlocProvider<T extends Bloc<Object, Object>> extends Widget {
  const BlocProvider({
    super.key,
    required T Function(BuildContext) create,
    Widget? child,
  });
  const BlocProvider.value({
    super.key,
    required T value,
    Widget? child,
  });
}

class MultiBlocProvider extends Widget {
  const MultiBlocProvider({
    super.key,
    required List<Widget> providers,
    Widget? child,
  });
}

extension ReadContext on BuildContext {
  T read<T>() => throw UnimplementedError();
}

// ============================================================================
// Cubit (mock for v4.1.4 rules)
// ============================================================================

abstract class Cubit<State> {
  Cubit(State initialState);
  State get state => throw UnimplementedError();
  void emit(State state) {}
}

class UserBloc extends Bloc<Object, Object> {
  UserBloc() : super(Object());
}

// ============================================================================
// GetX (mock for v4.1.4 rules)
// ============================================================================

abstract class GetxController {
  void onInit() {}
  void onClose() {}
}

class Get {
  static void put<T>(T instance) {}
  static void lazyPut<T>(T Function() builder) {}
  static void snackbar(String title, String message) {}
}

// ============================================================================
// Hive (mock for v4.1.4 rules)
// ============================================================================

class Box<T> {}

class LazyBox<T> {}

class HiveType {
  const HiveType({required int typeId});
}

class Hive {
  static Future<Box<T>> openBox<T>(String name) async => Box<T>();
  static Future<LazyBox<T>> openLazyBox<T>(String name) async => LazyBox<T>();
}

class Uint8List {
  Uint8List(int length);
}

// ============================================================================
// SharedPreferences (mock for v4.1.4 rules)
// ============================================================================

class SharedPreferences {
  static Future<SharedPreferences> getInstance() async => SharedPreferences();
  static void setPrefix(String prefix) {}
}

class SendPort {}

// ============================================================================
// Intl (mock for v4.1.4 rules)
// ============================================================================

class Intl {
  static String message(String message, {List<Object>? args}) => message;
}

// ============================================================================
// Navigation (mock for v4.1.4 rules)
// ============================================================================

class MaterialPageRoute<T> {
  MaterialPageRoute({
    required Widget Function(BuildContext) builder,
    RouteSettings? settings,
  });
}

class RouteSettings {
  const RouteSettings({String? name});
}

// ============================================================================
// ChangeNotifierProxyProvider (mock for v4.1.4 rules)
// ============================================================================

class ChangeNotifierProxyProvider<T, R extends ChangeNotifier> extends Widget {
  const ChangeNotifierProxyProvider({
    super.key,
    required R Function(BuildContext) create,
    required R Function(BuildContext, T, R?) update,
    Widget? child,
  });
}

// ============================================================================
// Builder widgets (mock for builder-callback tests)
// ============================================================================

class Builder extends Widget {
  const Builder({super.key, required Widget Function(BuildContext) builder});
}

class StreamBuilder<T> extends Widget {
  const StreamBuilder({
    super.key,
    Stream<T>? stream,
    required Widget Function(BuildContext, AsyncSnapshot<T>) builder,
  });
}

class AsyncSnapshot<T> {
  const AsyncSnapshot();
}

class BlocBuilder<B, S> extends Widget {
  const BlocBuilder({
    super.key,
    required Widget Function(BuildContext, S) builder,
  });
}

class LayoutBuilder extends Widget {
  const LayoutBuilder({
    super.key,
    required Widget Function(BuildContext, BoxConstraints) builder,
  });
}

// ============================================================================
// freezed annotation (mock for v4.1.4 rules)
// ============================================================================

const freezed = _Freezed();

class _Freezed {
  const _Freezed();
}

// ============================================================================
// WidgetsBinding (mock for v4.1.4 rules)
// ============================================================================

class WidgetsBinding {
  static WidgetsBinding get instance => WidgetsBinding();
  void addPostFrameCallback(void Function(Duration) callback) {}
}

// ============================================================================
// Collection comparison functions (from foundation.dart)
// ============================================================================

bool listEquals<T>(List<T>? a, List<T>? b) => a == b;
bool setEquals<T>(Set<T>? a, Set<T>? b) => a == b;
bool mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) => a == b;

// ============================================================================
// Additional widget types for test fixture generation
// ============================================================================

class ListTile extends Widget {
  const ListTile({
    super.key,
    Widget? title,
    Widget? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool enabled = true,
    bool selected = false,
  });
}

class TextStyle {
  const TextStyle({
    double? fontSize,
    dynamic fontWeight,
    dynamic color,
    dynamic decoration,
    String? fontFamily,
    double? letterSpacing,
    double? height,
  });
}

class MaterialApp extends Widget {
  const MaterialApp({
    super.key,
    Widget? home,
    String? title,
    dynamic theme,
    dynamic darkTheme,
    dynamic themeMode,
    dynamic onGenerateRoute,
  });
}

class GestureDetector extends Widget {
  const GestureDetector({
    super.key,
    Widget? child,
    VoidCallback? onTap,
    VoidCallback? onDoubleTap,
    VoidCallback? onLongPress,
    dynamic behavior,
  });
}

class InputDecoration {
  const InputDecoration({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    dynamic border,
    String? errorText,
    Widget? label,
  });
}

class CircularProgressIndicator extends Widget {
  const CircularProgressIndicator({super.key, double? value});
}

class TextSpan {
  const TextSpan({
    String? text,
    TextStyle? style,
    List<TextSpan>? children,
    dynamic recognizer,
  });
}

class Form extends Widget {
  const Form({super.key, Widget? child, dynamic key});
}

class IconButton extends Widget {
  const IconButton({
    super.key,
    required VoidCallback? onPressed,
    required Widget icon,
    String? tooltip,
  });
}

class InkWell extends Widget {
  const InkWell({
    super.key,
    Widget? child,
    VoidCallback? onTap,
  });
}

class Hero extends Widget {
  const Hero({super.key, required dynamic tag, required Widget child});
}

class BoxDecoration {
  const BoxDecoration({
    dynamic color,
    dynamic gradient,
    dynamic border,
    dynamic borderRadius,
    dynamic boxShadow,
  });
}

class Opacity extends Widget {
  const Opacity({super.key, required double opacity, Widget? child});
}

class SafeArea extends Widget {
  const SafeArea({super.key, required Widget child});
}

class AnimatedList extends Widget {
  const AnimatedList({
    super.key,
    required dynamic itemBuilder,
    int initialItemCount = 0,
  });
}

class SliverAnimatedList extends Widget {
  const SliverAnimatedList({super.key, required dynamic itemBuilder});
}

class ValueKey<T> extends Key {
  const ValueKey(T value) : super('');
}

class GlobalKey<T extends State> extends Key {
  GlobalKey({String? debugLabel}) : super('');
}

class Color {
  const Color(int value);
  Color withOpacity(double opacity) => this;
}

class SliverList extends Widget {
  const SliverList({super.key, required dynamic delegate});
  const SliverList.builder({
    super.key,
    required dynamic itemBuilder,
    int? itemCount,
  });
}

class AnimatedContainer extends Widget {
  const AnimatedContainer({
    super.key,
    required Duration duration,
    Widget? child,
    dynamic color,
    double? width,
    double? height,
  });
}

class SelectableText extends Widget {
  const SelectableText(String data, {super.key, TextStyle? style});
}

class Tooltip extends Widget {
  const Tooltip({super.key, String? message, Widget? child});
}

class Card extends Widget {
  const Card({super.key, Widget? child, dynamic elevation});
}

class FloatingActionButton extends Widget {
  const FloatingActionButton({
    super.key,
    VoidCallback? onPressed,
    Widget? child,
    String? tooltip,
  });
}

class Switch extends Widget {
  const Switch({super.key, required bool value, dynamic onChanged});
}

class Checkbox extends Widget {
  const Checkbox({super.key, required bool? value, dynamic onChanged});
}

class RefreshIndicator extends Widget {
  const RefreshIndicator({
    super.key,
    required Widget child,
    required dynamic onRefresh,
  });
}

class RepaintBoundary extends Widget {
  const RepaintBoundary({super.key, Widget? child});
}

class FittedBox extends Widget {
  const FittedBox({super.key, Widget? child, dynamic fit});
}

class Chip extends Widget {
  const Chip({super.key, required Widget label, Widget? avatar});
}

class Draggable<T> extends Widget {
  const Draggable({
    super.key,
    required Widget child,
    required Widget feedback,
    T? data,
  });
}

class Dismissible extends Widget {
  const Dismissible({
    super.key,
    required dynamic key,
    required Widget child,
    dynamic onDismissed,
  });
}

class FutureBuilder<T> extends Widget {
  const FutureBuilder({
    super.key,
    required Future<T>? future,
    required dynamic builder,
  });
}

class AbsorbPointer extends Widget {
  const AbsorbPointer({super.key, bool absorbing = true, Widget? child});
}

class IgnorePointer extends Widget {
  const IgnorePointer({super.key, bool ignoring = true, Widget? child});
}

class Visibility extends Widget {
  const Visibility({super.key, required Widget child, bool visible = true});
}

class PopupMenuButton<T> extends Widget {
  const PopupMenuButton({super.key, required dynamic itemBuilder});
}

class DropdownButton<T> extends Widget {
  const DropdownButton({
    super.key,
    required T? value,
    required dynamic onChanged,
    required List<dynamic> items,
  });
}

class DefaultTextStyle extends Widget {
  const DefaultTextStyle({
    super.key,
    required TextStyle style,
    required Widget child,
  });
}

// ============================================================================
// Test framework stubs
// ============================================================================

void test(String description, dynamic Function() body) {}
void testWidgets(String description, dynamic Function(dynamic) callback) {}
void expect(dynamic actual, dynamic matcher) {}
void group(String description, dynamic Function() body) {}
void setUp(dynamic Function() body) {}
void tearDown(dynamic Function() body) {}
void when(dynamic obj) {}
void verify(dynamic obj) {}
dynamic find = _FindStub();
dynamic findsOneWidget = true;
dynamic findsNothing = true;

class _FindStub {
  dynamic byKey(dynamic key) => null;
  dynamic byType(dynamic type) => null;
  dynamic text(String text) => null;
  dynamic noSuchMethod(Invocation i) => null;
}

// ============================================================================
// Common utility stubs
// ============================================================================

void runApp(Widget app) {}
dynamic jsonDecode(String source) => {};
String jsonEncode(dynamic object) => '';
Future<T> compute<T, U>(T Function(U) callback, U message) async =>
    callback(message);
void log(String message, {String? name, int? level}) {}
void setState(void Function() fn) {}
void doSomething() {}
dynamic fetchData() => null;
dynamic fetchUser() => null;
dynamic showError(dynamic msg) => null;
dynamic saveData(dynamic data) => null;
dynamic showNotification(dynamic n) => null;

class Platform {
  static bool get isIOS => false;
  static bool get isAndroid => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static Map<String, String> get environment => {};
}

class MediaQuery {
  static dynamic of(BuildContext context) => _MediaQueryData();
  static dynamic maybeOf(BuildContext context) => null;
}

class _MediaQueryData {
  dynamic get size => null;
  double get textScaleFactor => 1.0;
  dynamic get padding => null;
  dynamic get viewInsets => null;
}

class Focus extends Widget {
  const Focus({super.key, Widget? child, dynamic onFocusChange});
}

class FocusTraversalGroup extends Widget {
  const FocusTraversalGroup({super.key, Widget? child, dynamic policy});
}

class ValueListenableBuilder<T> extends Widget {
  const ValueListenableBuilder({
    super.key,
    required dynamic valueListenable,
    required dynamic builder,
  });
}

class OrientationBuilder extends Widget {
  const OrientationBuilder({super.key, required dynamic builder});
}

class CupertinoButton extends Widget {
  const CupertinoButton({
    super.key,
    required VoidCallback? onPressed,
    required Widget child,
  });
}

class ScrollController {
  ScrollController({double initialScrollOffset = 0.0});
  void dispose() {}
  void addListener(VoidCallback listener) {}
  void removeListener(VoidCallback listener) {}
  double get offset => 0.0;
}

class File {
  File(String path);
  String readAsStringSync() => '';
  Future<String> readAsString() async => '';
  bool existsSync() => false;
}

class Uri {
  static Uri parse(String uriString) => Uri._();
  const Uri._();
  String get scheme => '';
  String get host => '';
}

class DateFormat {
  DateFormat(String pattern, [String? locale]);
  String format(dynamic date) => '';
  dynamic parse(String input) => null;
}

class GoRouter {
  GoRouter({required List<dynamic> routes, String? initialLocation});
  void go(String path) {}
  void push(String path) {}
}

class GoRoute {
  const GoRoute({
    required String path,
    dynamic builder,
    List<dynamic>? routes,
    String? name,
  });
}

class CachedNetworkImage extends Widget {
  const CachedNetworkImage({
    super.key,
    required String imageUrl,
    Widget? placeholder,
    Widget? errorWidget,
  });
}

class WebView extends Widget {
  const WebView({
    super.key,
    String? initialUrl,
    dynamic onPageFinished,
  });
}

class InAppWebView extends Widget {
  const InAppWebView({super.key, dynamic initialUrlRequest});
}

class ImagePicker {
  Future<dynamic> pickImage({required dynamic source}) async => null;
}

class ImageSource {
  static const camera = ImageSource._();
  static const gallery = ImageSource._();
  const ImageSource._();
}

class VideoPlayer {
  VideoPlayer({bool autoPlay = false});
  void dispose() {}
}

class AudioPlayer {
  AudioPlayer({bool autoPlay = false});
  void dispose() {}
}

class FlutterSecureStorage {
  const FlutterSecureStorage();
  Future<void> write({required String key, required String? value}) async {}
  Future<String?> read({required String key}) async => null;
}

class Dio {
  Dio([dynamic baseOptions]);
  Future<dynamic> get(String path) async => null;
  Future<dynamic> post(String path, {dynamic data}) async => null;
}

class HttpClient {
  Future<dynamic> getUrl(Uri url) async => null;
}

class StateProvider<T> {
  StateProvider(T Function(dynamic) create);
}

class ConsumerWidget extends Widget {
  const ConsumerWidget({super.key});
}

class MethodChannel {
  const MethodChannel(String name);
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async => null;
}

class EventChannel {
  const EventChannel(String name);
  Stream<dynamic> receiveBroadcastStream() => Stream.empty();
}

class NotificationDetails {
  const NotificationDetails({dynamic android, dynamic iOS});
}

class BlendMode {
  static const modulate = BlendMode._();
  const BlendMode._();
}

class FontWeight {
  static const bold = FontWeight._();
  static const normal = FontWeight._();
  static const w400 = FontWeight._();
  static const w700 = FontWeight._();
  const FontWeight._();
}

class BorderRadius {
  static dynamic circular(double radius) => null;
}

class ClipRRect extends Widget {
  const ClipRRect({super.key, dynamic borderRadius, Widget? child});
}

class BackdropFilter extends Widget {
  const BackdropFilter({super.key, required dynamic filter, Widget? child});
}

class ThemeMode {
  static const system = ThemeMode._();
  static const light = ThemeMode._();
  static const dark = ThemeMode._();
  const ThemeMode._();
}

class Brightness {
  static const light = Brightness._();
  static const dark = Brightness._();
  const Brightness._();
}

// Placeholder classes for DartDoc examples
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => Container();
}

class MyWidget extends StatelessWidget {
  const MyWidget({super.key});
  @override
  Widget build(BuildContext context) => Container();
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});
  @override
  Widget build(BuildContext context) => Container();
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => Container();
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => Container();
}

class User {
  String name = '';
  String email = '';
  int id = 0;
}

class MyService {
  void dispose() {}
}

class UserService {
  Future<User> getUser() async => User();
}

class MyNotifier {
  void dispose() {}
}

// AsyncSnapshot for FutureBuilder
class AsyncSnapshot<T> {
  bool get hasData => false;
  bool get hasError => false;
  T? get data => null;
  dynamic get error => null;
  dynamic get connectionState => null;
}

class ConnectionState {
  static const none = ConnectionState._();
  static const waiting = ConnectionState._();
  static const active = ConnectionState._();
  static const done = ConnectionState._();
  const ConnectionState._();
}

class Geolocator {
  static Future<dynamic> getCurrentPosition() async => null;
  static Future<bool> isLocationServiceEnabled() async => false;
}

class LocationSettings {
  const LocationSettings({dynamic accuracy, int? distanceFilter});
}
