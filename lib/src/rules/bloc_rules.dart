// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Bloc and Cubit lint rules for Flutter/Dart applications.
///
/// These rules help identify common Bloc/Cubit anti-patterns including
/// improper state management, missing dispose calls, event handling issues,
/// and architectural violations.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when BLoC events are emitted in constructor.
///
/// Events should not be added during BLoC construction.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   MyBloc() : super(Initial()) {
///     add(LoadEvent()); // Anti-pattern
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   MyBloc() : super(Initial());
/// }
/// // Add event from outside: bloc.add(LoadEvent());
/// ```
class AvoidBlocEventInConstructorRule extends SaropaLintRule {
  const AvoidBlocEventInConstructorRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_event_in_constructor',
    problemMessage:
        '[avoid_bloc_event_in_constructor] Adding a BLoC event in the constructor runs it before listeners are attached, causing missed state updates and unpredictable app behavior. This can result in lost events, bugs that are hard to trace, and inconsistent UI state.',
    correctionMessage:
        'Dispatch initial events from the widget that creates the BLoC, not from the BLoC constructor, to ensure all listeners are attached and receive the event.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      // Check if in a Bloc class
      final ClassDeclaration? classDecl =
          node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null) return;

      final ExtendsClause? extendsClause = classDecl.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (!superName.contains('Bloc') && !superName.contains('Cubit')) return;

      // Check for add() calls in constructor body
      final FunctionBody body = node.body;
      body.visitChildren(_AddCallVisitor(reporter, code));
    });
  }
}

class _AddCallVisitor extends RecursiveAstVisitor<void> {
  _AddCallVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'add') {
      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
  }
}

/// Requires Bloc/Cubit fields to be closed in dispose.
///
/// Bloc and Cubit instances created in a State class must be closed when
/// the widget is disposed to prevent memory leaks and cancel active
/// stream subscriptions.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _counterBloc = CounterBloc();
///   // Missing close - MEMORY LEAK!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _counterBloc = CounterBloc();
///
///   @override
///   void dispose() {
///     _counterBloc.close();
///     super.dispose();
///   }
/// }
/// ```
///
/// Note: Blocs provided via BlocProvider or dependency injection
/// are typically managed externally and don't need to be closed here.
class RequireBlocCloseRule extends SaropaLintRule {
  const RequireBlocCloseRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_close',
    problemMessage:
        '[require_bloc_close] If you do not close your Bloc or Cubit in the StatefulWidget dispose() method, it will leak memory, keep stream subscriptions active, and cause app slowdowns or crashes. Always close Blocs and Cubits to prevent leaks and unexpected behavior after the widget tree is rebuilt.',
    correctionMessage:
        'Add _bloc.close() (or cubit.close()) in the dispose() method before calling super.dispose() to properly release resources and prevent memory leaks.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State<T>
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final NamedType superclass = extendsClause.superclass;
      final String superName = superclass.name.lexeme;

      // Must be exactly "State" with type argument
      if (superName != 'State') return;
      if (superclass.typeArguments == null) return;

      // Find Bloc/Cubit fields that are CREATED locally (have initializers)
      // Fields without initializers are typically injected and managed elsewhere
      final List<String> blocNames = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            // Only check fields with initializers (locally created)
            final Expression? initializer = variable.initializer;
            if (initializer == null) continue;

            final String? typeName = member.fields.type?.toSource();
            if (typeName != null &&
                (typeName.endsWith('Bloc') ||
                    typeName.endsWith('Cubit') ||
                    typeName.contains('Bloc<') ||
                    typeName.contains('Cubit<'))) {
              blocNames.add(variable.name.lexeme);
              continue;
            }

            // Check initializer type
            if (initializer is InstanceCreationExpression) {
              final String initType =
                  initializer.constructorName.type.name.lexeme;
              if (initType.endsWith('Bloc') || initType.endsWith('Cubit')) {
                if (!blocNames.contains(variable.name.lexeme)) {
                  blocNames.add(variable.name.lexeme);
                }
              }
            }
          }
        }
      }

      if (blocNames.isEmpty) return;

      // Find dispose method body
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Check if each bloc is closed
      for (final String name in blocNames) {
        final bool isClosed = disposeBody != null &&
            (disposeBody.contains('$name.close(') ||
                disposeBody.contains('$name?.close(') ||
                disposeBody.contains('$name.closeSafe(') ||
                disposeBody.contains('$name?.closeSafe(') ||
                disposeBody.contains('$name..close('));

        if (!isClosed) {
          // Find and report the field declaration
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == name) {
                  reporter.atNode(variable, code);
                }
              }
            }
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddBlocCloseFix()];
}

class _AddBlocCloseFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String fieldName = node.name.lexeme;

      // Find the containing class
      AstNode? current = node.parent;
      while (current != null && current is! ClassDeclaration) {
        current = current.parent;
      }
      if (current is! ClassDeclaration) return;

      final ClassDeclaration classNode = current;

      // Find existing dispose method
      MethodDeclaration? disposeMethod;
      for (final ClassMember member in classNode.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      if (disposeMethod != null) {
        // Insert close() call before super.dispose()
        final String bodySource = disposeMethod.body.toSource();
        final int superDisposeIndex = bodySource.indexOf('super.dispose()');

        if (superDisposeIndex != -1) {
          final int bodyOffset = disposeMethod.body.offset;
          final int insertOffset = bodyOffset + superDisposeIndex;

          final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
            message: 'Add $fieldName.close()',
            priority: 1,
          );

          changeBuilder.addDartFileEdit((builder) {
            builder.addSimpleInsertion(
              insertOffset,
              '$fieldName.close();\n    ',
            );
          });
        }
      } else {
        // Create new dispose method
        int insertOffset = classNode.rightBracket.offset;

        for (final ClassMember member in classNode.members) {
          if (member is FieldDeclaration || member is ConstructorDeclaration) {
            insertOffset = member.end;
          }
        }

        final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
          message: 'Add dispose() method with $fieldName.close()',
          priority: 1,
        );

        changeBuilder.addDartFileEdit((builder) {
          builder.addSimpleInsertion(
            insertOffset,
            '\n\n  @override\n  void dispose() {\n    $fieldName.close();\n    super.dispose();\n  }',
          );
        });
      }
    });
  }
}

/// Warns when BLoC state classes are not immutable.
///
/// BLoC pattern relies on comparing old and new states to determine if the UI
/// should rebuild. Mutable state classes can lead to subtle bugs where state
/// changes aren't detected because the same object instance is being compared.
///
/// This rule only targets classes whose name ends with `State` and does NOT
/// extend a Flutter `State` subclass, `StatefulWidget`, or `StatelessWidget`.
///
/// **BAD:**
/// ```dart
/// class CounterState {
///   int count;
///   CounterState({this.count = 0});
/// }
/// ```
///
/// **GOOD (with @immutable):**
/// ```dart
/// @immutable
/// class CounterState {
///   final int count;
///   const CounterState({this.count = 0});
/// }
/// ```
///
/// **GOOD (with Equatable):**
/// ```dart
/// class CounterState extends Equatable {
///   final int count;
///   const CounterState({this.count = 0});
///
///   @override
///   List<Object?> get props => [count];
/// }
/// ```
class RequireImmutableBlocStateRule extends SaropaLintRule {
  const RequireImmutableBlocStateRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  /// Known Flutter framework State subclasses that are not BLoC states.
  static const Set<String> _flutterStateClasses = <String>{
    'State',
    'PopupMenuItemState',
    'FormFieldState',
    'AnimatedWidgetBaseState',
    'ScrollableState',
    'RefreshIndicatorState',
  };

  /// Flutter widget base classes — a class named "FooState" extending one of
  /// these is using "State" as a domain term, not a BLoC state.
  static const Set<String> _flutterWidgetClasses = <String>{
    'StatefulWidget',
    'StatelessWidget',
  };

  static const LintCode _code = LintCode(
    name: 'require_immutable_bloc_state',
    problemMessage:
        '[require_immutable_bloc_state] If your BLoC state is mutable, it causes unpredictable UI updates, breaks state comparison, and leads to missed widget rebuilds. This results in subtle bugs, inconsistent UI, and hard-to-maintain code.',
    correctionMessage:
        'Add the @immutable annotation or extend Equatable to ensure your BLoC state is immutable and supports proper equality comparisons. This guarantees reliable UI updates and easier debugging.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;

      // Check if class name ends with 'State' (BLoC convention)
      if (!className.endsWith('State')) return;

      // Skip abstract classes
      if (node.abstractKeyword != null) return;

      // Skip Flutter State subclasses and widget classes using "State" as
      // a domain term (e.g., ButtonDeleteCountryState extends StatefulWidget)
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (_flutterStateClasses.contains(superName)) return;
        if (_flutterWidgetClasses.contains(superName)) return;
        // A superclass ending with 'State' is likely a Flutter State
        // subclass or custom State variant, not a BLoC state.
        if (superName.endsWith('State')) return;
      }

      // Check for @immutable annotation
      bool hasImmutable = false;
      for (final Annotation annotation in node.metadata) {
        final String annotationName = annotation.name.name;
        if (annotationName == 'immutable') {
          hasImmutable = true;
          break;
        }
      }

      // Check for Equatable in extends clause
      bool hasEquatable = false;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (superName == 'Equatable' ||
            superName.contains('Equatable') ||
            superName == 'BlocState') {
          hasEquatable = true;
        }
      }

      // Check for Equatable in with clause (mixin)
      final WithClause? withClause = node.withClause;
      if (withClause != null) {
        for (final NamedType mixin in withClause.mixinTypes) {
          final String mixinName = mixin.name.lexeme;
          if (mixinName == 'EquatableMixin' ||
              mixinName.contains('Equatable')) {
            hasEquatable = true;
            break;
          }
        }
      }

      // Check for Equatable in implements clause
      final ImplementsClause? implementsClause = node.implementsClause;
      if (implementsClause != null) {
        for (final NamedType interface in implementsClause.interfaces) {
          final String interfaceName = interface.name.lexeme;
          if (interfaceName.contains('Equatable')) {
            hasEquatable = true;
            break;
          }
        }
      }

      if (!hasImmutable && !hasEquatable) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when Bloc is used for simple state that could use Cubit.
///
/// Cubit is simpler than Bloc for straightforward state changes.
/// If your Bloc only has 1-2 events with simple handlers, use Cubit.
///
/// **BAD:**
/// ```dart
/// // Overly complex for simple counter
/// abstract class CounterEvent {}
/// class IncrementPressed extends CounterEvent {}
///
/// class CounterBloc extends Bloc<CounterEvent, int> {
///   CounterBloc() : super(0) {
///     on<IncrementPressed>((event, emit) => emit(state + 1));
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class CounterCubit extends Cubit<int> {
///   CounterCubit() : super(0);
///
///   void increment() => emit(state + 1);
/// }
/// ```
class PreferCubitForSimpleRule extends SaropaLintRule {
  const PreferCubitForSimpleRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'prefer_cubit_for_simple',
    problemMessage:
        '[prefer_cubit_for_simple] Using Bloc for simple state management with few events adds unnecessary boilerplate, indirection, and makes code harder to maintain. This can slow down development and introduce avoidable complexity.',
    correctionMessage:
        'Use Cubit for straightforward state management. Reserve Bloc for cases with complex event handling or multiple event types.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  // Cached regex for performance
  static final RegExp _onPattern = RegExp(r'on<\w+>');

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc') return;

      // Count event handlers (on<Event> calls)
      final String classSource = node.toSource();

      // Count on<EventType> registrations
      final int eventCount = _onPattern.allMatches(classSource).length;

      // If only 1-2 simple events, suggest Cubit
      if (eventCount <= 2) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when BlocProvider is used without a BlocObserver setup.
///
/// BlocObserver provides centralized logging and error handling for all
/// Blocs. Without it, state changes and errors may go untracked.
///
/// **BAD:**
/// ```dart
/// void main() {
///   runApp(
///     BlocProvider(
///       create: (_) => AuthBloc(),
///       child: MyApp(),
///     ),
///   );
///   // No BlocObserver - no centralized logging!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() {
///   Bloc.observer = AppBlocObserver();
///   runApp(
///     BlocProvider(
///       create: (_) => AuthBloc(),
///       child: MyApp(),
///     ),
///   );
/// }
///
/// class AppBlocObserver extends BlocObserver {
///   @override
///   void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
///     log('Bloc error: $error');
///     super.onError(bloc, error, stackTrace);
///   }
/// }
/// ```
class RequireBlocObserverRule extends SaropaLintRule {
  const RequireBlocObserverRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  /// Alias: require_bloc_observer_instance
  static const LintCode _code = LintCode(
    name: 'require_bloc_observer',
    problemMessage:
        '[require_bloc_observer] Without a BlocObserver, state transitions and errors are invisible, making it extremely difficult to debug production issues, track bugs, or monitor app health. This can lead to undetected failures and poor user experience.',
    correctionMessage:
        'Add Bloc.observer = AppBlocObserver() in main() to enable centralized logging and error handling for all Blocs and Cubits.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme != 'main') return;

      final FunctionBody body = node.functionExpression.body;
      final String bodySource = body.toSource();

      // Check if using Bloc
      if (!bodySource.contains('BlocProvider') &&
          !bodySource.contains('MultiBlocProvider')) {
        return;
      }

      // Check if BlocObserver is set
      if (!bodySource.contains('Bloc.observer') &&
          !bodySource.contains('BlocObserver')) {
        reporter.atNode(node, code);
      }
    });
  }
}

// ============================================================================
// Batch 10: Additional Riverpod & Bloc Rules

/// Warns when BLoC events are mutated after dispatch.
///
/// Bloc events should be immutable. Mutating an event after dispatch
/// causes race conditions and makes debugging impossible.
///
/// **BAD:**
/// ```dart
/// class UpdateEvent extends MyEvent {
///   String name; // Mutable!
/// }
///
/// bloc.add(event);
/// event.name = 'changed'; // Mutating after dispatch!
/// ```
///
/// **GOOD:**
/// ```dart
/// class UpdateEvent extends MyEvent {
///   final String name; // Immutable
///   const UpdateEvent(this.name);
/// }
/// ```
class AvoidBlocEventMutationRule extends SaropaLintRule {
  const AvoidBlocEventMutationRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_event_mutation',
    problemMessage:
        '[avoid_bloc_event_mutation] If BLoC events are mutable, they can be modified during processing, causing race conditions, unpredictable state changes, and hard-to-debug bugs. This breaks the contract of event immutability and can destabilize your app.',
    correctionMessage:
        'Make all event fields final and use a const constructor to ensure events are immutable and safe to use in BLoC.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is an event class (naming convention)
      final String className = node.name.lexeme;
      if (!className.endsWith('Event')) return;

      // Check for mutable fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          if (!member.isStatic && !member.fields.isFinal) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

/// Warns when BLoC state is modified directly instead of using copyWith.
///
/// Directly modifying state fields breaks immutability. Use copyWith
/// to create new state instances with updated fields.
///
/// **BAD:**
/// ```dart
/// emit(state..count = 5); // Mutating existing state!
/// ```
///
/// **GOOD:**
/// ```dart
/// emit(state.copyWith(count: 5)); // New immutable state
/// ```
class PreferCopyWithForStateRule extends SaropaLintRule {
  const PreferCopyWithForStateRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Alias: prefer_copy_with_for_state_class
  static const LintCode _code = LintCode(
    name: 'prefer_copy_with_for_state',
    problemMessage:
        '[prefer_copy_with_for_state] Directly modifying BLoC state breaks immutability, leading to unpredictable UI updates, missed rebuilds, and subtle bugs that surface only in production. The BLoC pattern relies on immutable state transitions to guarantee that every emit triggers a rebuild; mutating fields in place silently bypasses this contract.',
    correctionMessage:
        'Use state.copyWith(field: value) to create a new immutable state object and trigger proper UI updates.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCascadeExpression((CascadeExpression node) {
      final Expression target = node.target;
      if (target is SimpleIdentifier && target.name == 'state') {
        for (final Expression section in node.cascadeSections) {
          if (section is AssignmentExpression) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when BlocProvider.of is used with listen:true in build method.
///
/// listen:true causes rebuilds on every state change. Use BlocBuilder
/// or BlocConsumer for controlled rebuilds.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final bloc = BlocProvider.of<MyBloc>(context); // listen:true by default
///   return Text('${bloc.state}');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return BlocBuilder<MyBloc, MyState>(
///     builder: (context, state) => Text('$state'),
///   );
/// }
/// ```
class AvoidBlocListenInBuildRule extends SaropaLintRule {
  const AvoidBlocListenInBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_listen_in_build',
    problemMessage:
        '[avoid_bloc_listen_in_build] Using BlocProvider.of in build() with listen:true causes the widget to rebuild on every state change, leading to performance issues and unpredictable UI updates. This can make your app less efficient and harder to maintain.',
    correctionMessage:
        'Use BlocBuilder for reactive UI updates, or context.read() for one-time access to the bloc, to avoid unnecessary rebuilds and improve performance.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      node.body.visitChildren(_BlocProviderOfVisitor(reporter, code));
    });
  }
}

class _BlocProviderOfVisitor extends RecursiveAstVisitor<void> {
  _BlocProviderOfVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'of') {
      final Expression? target = node.target;
      if (target is SimpleIdentifier && target.name == 'BlocProvider') {
        // Check if listen: false is explicitly set
        final ArgumentList args = node.argumentList;
        bool hasListenFalse = false;
        for (final Expression arg in args.arguments) {
          if (arg is NamedExpression &&
              arg.name.label.name == 'listen' &&
              arg.expression is BooleanLiteral &&
              !(arg.expression as BooleanLiteral).value) {
            hasListenFalse = true;
          }
        }
        if (!hasListenFalse) {
          reporter.atNode(node, code);
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when BLoC constructor doesn't pass initial state to super.
///
/// Bloc without an initial state throws at runtime. Always pass
/// initial state to super() in the constructor.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   MyBloc() : super(); // Missing initial state!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   MyBloc() : super(InitialState());
/// }
/// ```
class RequireInitialStateRule extends SaropaLintRule {
  const RequireInitialStateRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_initial_state',
    problemMessage:
        '[require_initial_state] If a BLoC or Cubit does not provide an initial state, it will throw a LateInitializationError at runtime when BlocBuilder or BlocConsumer tries to read the state. This causes your app to crash and makes debugging difficult.',
    correctionMessage:
        'Always add an initial state: super(InitialState()) or super(const State()) in your BLoC/Cubit constructor to prevent runtime errors.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Check constructors have super with argument
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          bool hasSuperWithArg = false;
          for (final ConstructorInitializer init in member.initializers) {
            if (init is SuperConstructorInvocation) {
              if (init.argumentList.arguments.isNotEmpty) {
                hasSuperWithArg = true;
              }
            }
          }
          if (!hasSuperWithArg) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

/// Warns when BLoC state sealed class doesn't include an error state.
///
/// States should include an error variant. Without it, errors are either
/// swallowed or crash the app instead of showing error UI.
///
/// **BAD:**
/// ```dart
/// sealed class UserState {}
/// class UserLoading extends UserState {}
/// class UserLoaded extends UserState {}
/// // Missing UserError!
/// ```
///
/// **GOOD:**
/// ```dart
/// sealed class UserState {}
/// class UserLoading extends UserState {}
/// class UserLoaded extends UserState {}
/// class UserError extends UserState {
///   final String message;
/// }
/// ```
class RequireErrorStateRule extends SaropaLintRule {
  const RequireErrorStateRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Alias: require_error_state_context
  static const LintCode _code = LintCode(
    name: 'require_error_state',
    problemMessage:
        '[require_error_state] If your BLoC state hierarchy does not include an error state, failures will be unhandled, leading to crashes or missing error UI. This makes your app less robust and harder to debug.',
    correctionMessage:
        'Add an Error state class (e.g., UserError) to your BLoC state hierarchy to handle failures gracefully and display error messages to users.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final Map<String, ClassDeclaration> stateClasses =
        <String, ClassDeclaration>{};
    final Set<String> sealedBases = <String>{};

    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;
      if (className.endsWith('State')) {
        stateClasses[className] = node;
        if (node.sealedKeyword != null) {
          sealedBases.add(className);
        }
      }
    });

    context.addPostRunCallback(() {
      for (final String baseName in sealedBases) {
        bool hasErrorState = false;
        for (final String className in stateClasses.keys) {
          if (className.contains('Error') || className.contains('Failure')) {
            hasErrorState = true;
            break;
          }
        }
        if (!hasErrorState && stateClasses.containsKey(baseName)) {
          reporter.atNode(stateClasses[baseName]!, code);
        }
      }
    });
  }
}

/// Warns when BLoCs directly call other BLoCs.
///
/// Blocs calling other blocs directly creates tight coupling. Use a
/// parent widget or service to coordinate between blocs.
///
/// **BAD:**
/// ```dart
/// class OrderBloc extends Bloc<OrderEvent, OrderState> {
///   final UserBloc userBloc;
///   OrderBloc(this.userBloc);
///
///   void onPlaceOrder() {
///     userBloc.add(UpdatePoints()); // Direct coupling!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Coordinate in widget or use streams
/// BlocListener<OrderBloc, OrderState>(
///   listener: (context, state) {
///     if (state is OrderPlaced) {
///       context.read<UserBloc>().add(UpdatePoints());
///     }
///   },
///   child: ...
/// )
/// ```
class AvoidBlocInBlocRule extends SaropaLintRule {
  const AvoidBlocInBlocRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  /// Alias: avoid_bloc_in_bloc_pattern
  static const LintCode _code = LintCode(
    name: 'avoid_bloc_in_bloc',
    problemMessage:
        '[avoid_bloc_in_bloc] BLoC directly calling another BLoC creates tight coupling between state managers. This makes unit testing difficult, risks circular dependencies, and breaks the unidirectional data flow pattern that BLoC relies on for predictable state management.',
    correctionMessage:
        'Coordinate between BLoCs at the widget layer using BlocListener, or communicate through shared streams to maintain loose coupling.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Check for Bloc fields that are used with .add()
      final Set<String> blocFields = <String>{};
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration field in member.fields.variables) {
            final String fieldType = member.fields.type?.toSource() ?? '';
            if (fieldType.contains('Bloc') || fieldType.contains('Cubit')) {
              blocFields.add(field.name.lexeme);
            }
          }
        }
      }

      // Check for .add() calls on bloc fields
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          member.body
              .visitChildren(_BlocAddVisitor(reporter, code, blocFields));
        }
      }
    });
  }
}

class _BlocAddVisitor extends RecursiveAstVisitor<void> {
  _BlocAddVisitor(this.reporter, this.code, this.blocFields);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  final Set<String> blocFields;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'add' || node.methodName.name == 'emit') {
      final Expression? target = node.target;
      if (target is SimpleIdentifier && blocFields.contains(target.name)) {
        reporter.atNode(node, code);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when BLoC events don't use sealed classes.
///
/// Sealed classes for events enable exhaustive switch statements, so
/// the compiler catches unhandled events.
///
/// **BAD:**
/// ```dart
/// abstract class CounterEvent {}
/// class Increment extends CounterEvent {}
/// class Decrement extends CounterEvent {}
/// ```
///
/// **GOOD:**
/// ```dart
/// sealed class CounterEvent {}
/// class Increment extends CounterEvent {}
/// class Decrement extends CounterEvent {}
/// ```
class PreferSealedEventsRule extends SaropaLintRule {
  const PreferSealedEventsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Alias: prefer_sealed_events_pattern
  static const LintCode _code = LintCode(
    name: 'prefer_sealed_events',
    problemMessage:
        '[prefer_sealed_events] Non-sealed events allow subclassing anywhere, '
        'preventing compiler exhaustiveness checks in switch statements.',
    correctionMessage:
        'Use sealed class instead of abstract class for event hierarchy.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;
      if (!className.endsWith('Event')) return;

      // Check if abstract but not sealed
      if (node.abstractKeyword != null && node.sealedKeyword == null) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Bloc event handlers don't use EventTransformer.
///
/// Without EventTransformer, rapid events are processed sequentially.
/// Use transformers for debouncing, throttling, or concurrent processing.
///
/// **BAD:**
/// ```dart
/// class SearchBloc extends Bloc<SearchEvent, SearchState> {
///   SearchBloc() : super(SearchInitial()) {
///     on<SearchQueryChanged>((event, emit) async {
///       // Processes every keystroke - excessive API calls!
///       final results = await search(event.query);
///       emit(SearchResults(results));
///     });
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class SearchBloc extends Bloc<SearchEvent, SearchState> {
///   SearchBloc() : super(SearchInitial()) {
///     on<SearchQueryChanged>(
///       (event, emit) async {
///         final results = await search(event.query);
///         emit(SearchResults(results));
///       },
///       transformer: debounce(Duration(milliseconds: 300)),
///     );
///   }
/// }
/// ```
class RequireBlocTransformerRule extends SaropaLintRule {
  const RequireBlocTransformerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_transformer',
    problemMessage:
        '[require_bloc_transformer] Bloc on<Event> without transformer processes all events sequentially.',
    correctionMessage:
        'Add transformer: for debounce, throttle, or concurrent event handling.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Event names that commonly benefit from transformers
  static const Set<String> _transformerSuggestedEvents = <String>{
    'SearchQueryChanged',
    'TextChanged',
    'InputChanged',
    'ScrollPositionChanged',
    'FilterChanged',
    'QueryChanged',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for on<EventType>(...) pattern
      if (node.methodName.name != 'on') return;

      // Check if it has type arguments (on<EventType>)
      final TypeArgumentList? typeArgs = node.typeArguments;
      if (typeArgs == null || typeArgs.arguments.isEmpty) return;

      final String eventType = typeArgs.arguments.first.toSource();

      // Check if this event type would benefit from a transformer
      bool needsTransformer = false;
      for (final String pattern in _transformerSuggestedEvents) {
        if (eventType.contains(pattern)) {
          needsTransformer = true;
          break;
        }
      }

      if (!needsTransformer) return;

      // Check if transformer argument is present
      bool hasTransformer = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'transformer') {
          hasTransformer = true;
          break;
        }
      }

      if (!hasTransformer) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Bloc event handlers are too long.
///
/// Long event handlers indicate the handler is doing too much. Extract
/// business logic to separate methods or services for testability.
///
/// **BAD:**
/// ```dart
/// on<SubmitForm>((event, emit) async {
///   emit(Loading());
///   // 50+ lines of validation, API calls, error handling...
///   final validated = validateForm(event.data);
///   if (!validated.isValid) {
///     emit(Error(validated.errors));
///     return;
///   }
///   final user = await api.createUser(validated.data);
///   // ... more logic ...
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// on<SubmitForm>(_onSubmitForm);
///
/// Future<void> _onSubmitForm(SubmitForm event, Emitter<State> emit) async {
///   emit(Loading());
///   final result = await _submitFormUseCase(event.data);
///   emit(result.fold(
///     (error) => Error(error),
///     (user) => Success(user),
///   ));
/// }
/// ```
class AvoidLongEventHandlersRule extends SaropaLintRule {
  const AvoidLongEventHandlersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_long_event_handlers',
    problemMessage:
        '[avoid_long_event_handlers] Bloc event handler is too long. Extract logic to separate methods.',
    correctionMessage:
        'Move complex logic to named methods or use cases for better testability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Maximum lines before warning
  static const int _maxLines = 30;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'on') return;

      // Find the handler function in arguments
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is FunctionExpression) {
          final String source = arg.body.toSource();
          final int lineCount = '\n'.allMatches(source).length + 1;

          if (lineCount > _maxLines) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when nested `BlocProvider` widgets are used.
///
/// Use `MultiBlocProvider` when providing multiple blocs to reduce nesting
/// and improve readability.
///
/// **BAD:**
/// ```dart
/// BlocProvider<AuthBloc>(
///   create: (_) => AuthBloc(),
///   child: BlocProvider<UserBloc>(
///     create: (_) => UserBloc(),
///     child: MyApp(),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// MultiBlocProvider(
///   providers: [
///     BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
///     BlocProvider<UserBloc>(create: (_) => UserBloc()),
///   ],
///   child: MyApp(),
/// )
/// ```
///
/// **Quick fix available:** Adds a `TODO` comment for manual conversion.
class PreferMultiBlocProviderRule extends SaropaLintRule {
  const PreferMultiBlocProviderRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'prefer_multi_bloc_provider',
    problemMessage:
        '[prefer_multi_bloc_provider] Nested BlocProviders should use MultiBlocProvider instead.',
    correctionMessage:
        'Combine into MultiBlocProvider(providers: [...], child: ...).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'BlocProvider') return;

      // Check if child is also a BlocProvider
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression childExpr = arg.expression;
          if (childExpr is InstanceCreationExpression) {
            final String childType = childExpr.constructorName.type.name.lexeme;
            if (childType == 'BlocProvider') {
              reporter.atNode(node, code);
              return;
            }
          }
        }
      }
    });
  }
}

/// Warns when `BlocProvider.value` receives a newly created bloc instance.
///
/// `BlocProvider.value` should only receive existing bloc instances.
/// Creating a new bloc in the value parameter will not properly manage
/// the bloc's lifecycle (it won't be automatically closed).
///
/// **BAD:**
/// ```dart
/// BlocProvider.value(
///   value: AuthBloc(), // New instance - won't be automatically closed!
///   child: MyWidget(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// BlocProvider(
///   create: (_) => AuthBloc(), // Properly managed by BlocProvider
///   child: MyWidget(),
/// )
/// // OR for existing instances:
/// BlocProvider.value(
///   value: existingBloc, // Variable reference is correct
///   child: MyWidget(),
/// )
/// ```
class AvoidInstantiatingInBlocValueProviderRule extends SaropaLintRule {
  const AvoidInstantiatingInBlocValueProviderRule() : super(code: _code);

  /// Critical - memory leak potential.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'avoid_instantiating_in_bloc_value_provider',
    problemMessage:
        '[avoid_instantiating_in_bloc_value_provider] Creating a new bloc instance inside BlocProvider.value prevents the bloc from being automatically closed, leading to memory leaks and unpredictable state. This is a critical resource management issue that can degrade app performance and reliability.',
    correctionMessage:
        'Always use BlocProvider(create: ...) to create new bloc instances, or pass an existing bloc variable to BlocProvider.value. Never instantiate a bloc directly inside BlocProvider.value.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final ConstructorName constructorName = node.constructorName;
      final String typeName = constructorName.type.name.lexeme;
      if (typeName != 'BlocProvider') return;

      // Check if this is BlocProvider.value
      if (constructorName.name?.name != 'value') return;

      // Check if value parameter is an instance creation (new bloc)
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'value') {
          final Expression valueExpr = arg.expression;
          if (valueExpr is InstanceCreationExpression) {
            // This is creating a new instance in value - BAD
            reporter.atNode(valueExpr, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when `BlocProvider(create: ...)` returns an existing bloc instance.
///
/// `BlocProvider(create: ...)` should create a new bloc instance.
/// Returning an existing variable will cause the bloc to be closed when
/// the provider is disposed, even though it may still be in use elsewhere.
///
/// **BAD:**
/// ```dart
/// final myBloc = AuthBloc();
/// // ...
/// BlocProvider(
///   create: (_) => myBloc, // Existing instance - will be closed unexpectedly!
///   child: MyWidget(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// BlocProvider(
///   create: (_) => AuthBloc(), // New instance - proper lifecycle
///   child: MyWidget(),
/// )
/// // OR for existing instances:
/// BlocProvider.value(
///   value: myBloc, // Use .value for existing instances
///   child: MyWidget(),
/// )
/// ```
class AvoidExistingInstancesInBlocProviderRule extends SaropaLintRule {
  const AvoidExistingInstancesInBlocProviderRule() : super(code: _code);

  /// Critical - unexpected bloc closure.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'avoid_existing_instances_in_bloc_provider',
    problemMessage:
        '[avoid_existing_instances_in_bloc_provider] Returning an existing bloc instance from BlocProvider(create: ...) causes the bloc to be closed when the provider disposes, even if it is still used elsewhere. This can lead to unexpected state loss, runtime errors, and hard-to-debug bugs. Always use the correct provider pattern for new vs. existing blocs.',
    correctionMessage:
        'For existing bloc instances, use BlocProvider.value(value: existingBloc). Only use BlocProvider(create: ...) to create new bloc instances. This ensures proper lifecycle management and prevents accidental closure of shared blocs.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final ConstructorName constructorName = node.constructorName;
      final String typeName = constructorName.type.name.lexeme;
      if (typeName != 'BlocProvider') return;

      // Skip BlocProvider.value - that's what they should use for existing
      if (constructorName.name?.name == 'value') return;

      // Check if create parameter returns an existing variable
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'create') {
          final Expression createExpr = arg.expression;
          if (createExpr is FunctionExpression) {
            final FunctionBody body = createExpr.body;
            if (body is ExpressionFunctionBody) {
              final Expression returnExpr = body.expression;
              // Check if return is just a simple identifier (variable)
              if (returnExpr is SimpleIdentifier) {
                // Check it's not calling a constructor
                // A simple identifier returning means it's an existing variable
                reporter.atNode(returnExpr, code);
                return;
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when the wrong BlocProvider variant is used for the use case.
///
/// - Use `BlocProvider(create: ...)` when you need to create AND manage a bloc
/// - Use `BlocProvider.value(value: ...)` when providing an already-existing bloc
///
/// This rule identifies common mismatches between provider type and usage.
///
/// **BAD:**
/// ```dart
/// // Using create but immediately closing the bloc elsewhere
/// BlocProvider(
///   create: (_) => context.read<AuthBloc>(), // Getting existing bloc!
///   child: MyWidget(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use .value for accessing blocs from context
/// BlocProvider.value(
///   value: context.read<AuthBloc>(),
///   child: MyWidget(),
/// )
/// ```
class PreferCorrectBlocProviderRule extends SaropaLintRule {
  const PreferCorrectBlocProviderRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'prefer_correct_bloc_provider',
    problemMessage:
        '[prefer_correct_bloc_provider] Using context.read() in BlocProvider.create returns an existing bloc. '
        'Use BlocProvider.value instead.',
    correctionMessage:
        'Replace with BlocProvider.value(value: context.read<T>(), ...).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final ConstructorName constructorName = node.constructorName;
      final String typeName = constructorName.type.name.lexeme;
      if (typeName != 'BlocProvider') return;

      // Only check BlocProvider(create: ...)
      if (constructorName.name?.name == 'value') return;

      // Check if create parameter uses context.read()
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'create') {
          final Expression createExpr = arg.expression;
          if (createExpr is FunctionExpression) {
            final FunctionBody body = createExpr.body;
            if (body is ExpressionFunctionBody) {
              final Expression returnExpr = body.expression;
              // Check for context.read<T>() pattern
              if (returnExpr is MethodInvocation) {
                final String methodName = returnExpr.methodName.name;
                if (methodName == 'read' || methodName == 'watch') {
                  reporter.atNode(node, code);
                  return;
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when emit() is called after an await without checking isClosed.
///
/// Bloc can be closed while awaiting, leading to state emissions on a
/// closed bloc which causes errors.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// on<LoadEvent>((event, emit) async {
///   final data = await fetchData();
///   emit(LoadedState(data)); // Bloc might be closed!
/// });
/// ```
///
/// #### GOOD:
/// ```dart
/// on<LoadEvent>((event, emit) async {
///   final data = await fetchData();
///   if (!isClosed) {
///     emit(LoadedState(data));
///   }
/// });
/// ```
class CheckIsNotClosedAfterAsyncGapRule extends SaropaLintRule {
  const CheckIsNotClosedAfterAsyncGapRule() : super(code: _code);

  /// Critical bug. Emit after close causes crash.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'check_is_not_closed_after_async_gap',
    problemMessage:
        '[check_is_not_closed_after_async_gap] Emitting to closed Bloc throws '
        'StateError, crashing the app when widget is disposed during async.',
    correctionMessage:
        'Add if (!isClosed) check before emit() after async operations.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Look for on<Event> handler registration
      if (node.methodName.name != 'on') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      // Get the callback
      final Expression callback = args.arguments.first;
      if (callback is! FunctionExpression) return;

      final FunctionBody body = callback.body;
      if (!body.isAsynchronous) return;

      // Find emit calls after await
      final _EmitAfterAwaitVisitor visitor = _EmitAfterAwaitVisitor();
      body.accept(visitor);

      for (final MethodInvocation emitCall in visitor.emitCallsAfterAwait) {
        reporter.atNode(emitCall, code);
      }
    });
  }
}

class _EmitAfterAwaitVisitor extends RecursiveAstVisitor<void> {
  bool _foundAwait = false;
  bool _insideClosedCheck = false;
  final List<MethodInvocation> emitCallsAfterAwait = <MethodInvocation>[];

  @override
  void visitAwaitExpression(AwaitExpression node) {
    _foundAwait = true;
    super.visitAwaitExpression(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    // Check for if (!isClosed) or if (isClosed) return patterns
    final Expression condition = node.expression;
    if (_isClosedCheck(condition)) {
      _insideClosedCheck = true;
      node.thenStatement.accept(this);
      _insideClosedCheck = false;
      node.elseStatement?.accept(this);
    } else {
      super.visitIfStatement(node);
    }
  }

  bool _isClosedCheck(Expression expr) {
    // Check for !isClosed or isClosed
    if (expr is PrefixExpression && expr.operator.lexeme == '!') {
      final Expression operand = expr.operand;
      return operand is SimpleIdentifier && operand.name == 'isClosed';
    }
    if (expr is SimpleIdentifier) {
      return expr.name == 'isClosed';
    }
    return false;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'emit' && _foundAwait && !_insideClosedCheck) {
      emitCallsAfterAwait.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when multiple handlers are registered for the same event type.
///
/// Bloc doesn't support multiple handlers for the same event. The second
/// handler will override the first, leading to unexpected behavior.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   MyBloc() : super(InitialState()) {
///     on<LoadEvent>((e, emit) => emit(Loading()));
///     on<LoadEvent>((e, emit) => emit(Loaded())); // Duplicate!
///   }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   MyBloc() : super(InitialState()) {
///     on<LoadEvent>((e, emit) {
///       emit(Loading());
///       // ... then emit Loaded
///     });
///   }
/// }
/// ```
class AvoidDuplicateBlocEventHandlersRule extends SaropaLintRule {
  const AvoidDuplicateBlocEventHandlersRule() : super(code: _code);

  /// Critical bug. Duplicate handlers cause unexpected behavior.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_bloc_event_handlers',
    problemMessage:
        '[avoid_duplicate_bloc_event_handlers] Second handler for same event '
        'type is ignored, causing silent bugs when expected logic runs.',
    correctionMessage:
        'Combine handlers into one on<Event> call. Only one handler per event type.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends Bloc
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'Bloc') return;

      // Find constructor
      ConstructorDeclaration? constructor;
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration && member.name == null) {
          constructor = member;
          break;
        }
      }

      if (constructor == null) return;

      // Find all on<Event> calls
      final Map<String, List<MethodInvocation>> eventHandlers =
          <String, List<MethodInvocation>>{};

      final _OnCallVisitor visitor = _OnCallVisitor();
      constructor.body.accept(visitor);

      for (final MethodInvocation onCall in visitor.onCalls) {
        final TypeArgumentList? typeArgs = onCall.typeArguments;
        if (typeArgs == null || typeArgs.arguments.isEmpty) continue;

        final String eventType = typeArgs.arguments.first.toSource();
        eventHandlers.putIfAbsent(eventType, () => <MethodInvocation>[]);
        eventHandlers[eventType]!.add(onCall);
      }

      // Report duplicates
      for (final String eventType in eventHandlers.keys) {
        final List<MethodInvocation> handlers = eventHandlers[eventType]!;
        if (handlers.length > 1) {
          // Report all but the first one
          for (int i = 1; i < handlers.length; i++) {
            reporter.atNode(handlers[i], code);
          }
        }
      }
    });
  }
}

class _OnCallVisitor extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> onCalls = <MethodInvocation>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'on') {
      onCalls.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when Bloc event classes have mutable fields.
///
/// Bloc events should be immutable for predictable state management.
/// Mutable events can be changed after dispatch, causing bugs.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class UpdateUserEvent extends UserEvent {
///   String name; // Mutable!
///   UpdateUserEvent(this.name);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class UpdateUserEvent extends UserEvent {
///   final String name; // Immutable
///   const UpdateUserEvent(this.name);
/// }
/// ```
class PreferImmutableBlocEventsRule extends SaropaLintRule {
  const PreferImmutableBlocEventsRule() : super(code: _code);

  /// Bug risk. Mutable events can cause unexpected behavior.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  /// Alias: prefer_immutable_bloc_events_pattern
  static const LintCode _code = LintCode(
    name: 'prefer_immutable_bloc_events',
    problemMessage:
        '[prefer_immutable_bloc_events] Mutable event fields can be changed '
        'during processing, causing inconsistent state and debugging nightmares.',
    correctionMessage: 'Mark all fields as final for immutable events.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class name ends with Event
      final String className = node.name.lexeme;
      if (!className.endsWith('Event')) return;

      // Check for mutable fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration && !member.isStatic) {
          final VariableDeclarationList fields = member.fields;
          if (!fields.isFinal && !fields.isConst) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

/// Warns when Bloc state classes have mutable fields.
///
/// Bloc states should be immutable for predictable state management.
/// Mutable states can be changed outside the bloc, breaking the pattern.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class LoadedState extends UserState {
///   List<User> users; // Mutable!
///   LoadedState(this.users);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class LoadedState extends UserState {
///   final List<User> users; // Immutable reference
///   const LoadedState(this.users);
/// }
/// ```
class PreferImmutableBlocStateRule extends SaropaLintRule {
  const PreferImmutableBlocStateRule() : super(code: _code);

  /// Bug risk. Mutable state breaks bloc pattern.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  /// Alias: prefer_immutable_bloc_state_pattern
  static const LintCode _code = LintCode(
    name: 'prefer_immutable_bloc_state',
    problemMessage:
        '[prefer_immutable_bloc_state] Mutable state fields break equality '
        'comparison, causing BlocBuilder to miss or duplicate updates.',
    correctionMessage: 'Mark all fields as final for immutable state.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class name ends with State
      final String className = node.name.lexeme;
      if (!className.endsWith('State')) return;

      // Exclude Flutter's State class by checking for extends StatefulWidget
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (superName == 'State') return; // Flutter State, not Bloc state
      }

      // Check for mutable fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration && !member.isStatic) {
          final VariableDeclarationList fields = member.fields;
          if (!fields.isFinal && !fields.isConst) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

/// Warns when Bloc event classes are not sealed.
///
/// Sealed event classes ensure exhaustive pattern matching in handlers
/// and prevent unexpected event subtypes from being created.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// abstract class UserEvent {}
/// class LoadUserEvent extends UserEvent {}
/// ```
///
/// #### GOOD:
/// ```dart
/// sealed class UserEvent {}
/// class LoadUserEvent extends UserEvent {}
/// ```
class PreferSealedBlocEventsRule extends SaropaLintRule {
  const PreferSealedBlocEventsRule() : super(code: _code);

  /// Code quality. Sealed classes improve type safety.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  /// Alias: prefer_sealed_bloc_events_pattern
  static const LintCode _code = LintCode(
    name: 'prefer_sealed_bloc_events',
    problemMessage:
        '[prefer_sealed_bloc_events] Bloc event base class should be sealed.',
    correctionMessage: 'Use sealed keyword for exhaustive pattern matching.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class name ends with Event
      final String className = node.name.lexeme;
      if (!className.endsWith('Event')) return;

      // Check if it's a base class (abstract without extending another Event)
      if (node.abstractKeyword == null) return;

      // Check if it's already sealed
      if (node.sealedKeyword != null) return;

      // Check if it doesn't extend another Event class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (superName.endsWith('Event')) return; // Not a base class
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when Bloc state classes are not sealed.
///
/// Sealed state classes ensure exhaustive pattern matching in widgets
/// and prevent unexpected state subtypes from being created.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// abstract class UserState {}
/// class LoadingState extends UserState {}
/// ```
///
/// #### GOOD:
/// ```dart
/// sealed class UserState {}
/// class LoadingState extends UserState {}
/// ```
class PreferSealedBlocStateRule extends SaropaLintRule {
  const PreferSealedBlocStateRule() : super(code: _code);

  /// Code quality. Sealed classes improve type safety.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  /// Alias: prefer_sealed_bloc_state_pattern
  static const LintCode _code = LintCode(
    name: 'prefer_sealed_bloc_state',
    problemMessage:
        '[prefer_sealed_bloc_state] Bloc state base class should be sealed.',
    correctionMessage: 'Use sealed keyword for exhaustive pattern matching.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class name ends with State
      final String className = node.name.lexeme;
      if (!className.endsWith('State')) return;

      // Check if it's a base class (abstract without extending another State)
      if (node.abstractKeyword == null) return;

      // Check if it's already sealed
      if (node.sealedKeyword != null) return;

      // Check if it doesn't extend another State class (excluding Flutter State)
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (superName.endsWith('State') && superName != 'State') {
          return; // Not a base class
        }
      }

      reporter.atNode(node, code);
    });
  }
}

/// Suggests that Bloc event classes end with 'Event' suffix.
///
/// **Stylistic rule (opt-in only).** Naming convention with no performance or correctness impact.
///
/// Consistent naming helps identify Bloc event classes quickly.
///
/// **BAD:**
/// ```dart
/// abstract class UserAction {}  // Should end with Event
/// class LoadUser extends UserAction {}
/// ```
///
/// **GOOD:**
/// ```dart
/// abstract class UserEvent {}
/// class LoadUserEvent extends UserEvent {}
/// ```
class PreferBlocEventSuffixRule extends SaropaLintRule {
  const PreferBlocEventSuffixRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'prefer_bloc_event_suffix',
    problemMessage:
        '[prefer_bloc_event_suffix] Suffixing Bloc event class names with Event is a naming convention. The suffix does not affect Bloc behavior or performance. Enable via the stylistic tier.',
    correctionMessage:
        'Rename class to include Event suffix (e.g., LoadUserEvent).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;

      // Check if this class extends something that ends with Event
      // but this class itself doesn't end with Event
      if (superName.endsWith('Event')) {
        final String className = node.name.lexeme;
        if (!className.endsWith('Event')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Suggests that Bloc state classes end with 'State' suffix.
///
/// **Stylistic rule (opt-in only).** Naming convention with no performance or correctness impact.
///
/// Consistent naming helps identify Bloc state classes quickly.
///
/// **BAD:**
/// ```dart
/// abstract class UserStatus {}  // Should end with State
/// class UserLoading extends UserStatus {}
/// ```
///
/// **GOOD:**
/// ```dart
/// abstract class UserState {}
/// class UserLoadingState extends UserState {}
/// ```
class PreferBlocStateSuffixRule extends SaropaLintRule {
  const PreferBlocStateSuffixRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'prefer_bloc_state_suffix',
    problemMessage:
        '[prefer_bloc_state_suffix] Suffixing Bloc state class names with State is a naming convention. The suffix does not affect Bloc behavior or performance. Enable via the stylistic tier.',
    correctionMessage:
        'Rename class to include State suffix (e.g., UserLoadingState).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;

      // Check if this class extends something that ends with State (but not Flutter's State)
      // and this class itself doesn't end with State
      if (superName.endsWith('State') && superName != 'State') {
        final String className = node.name.lexeme;
        if (!className.endsWith('State')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when yield is used inside Bloc event handler.
///
/// In Bloc 8.0+, yield was replaced with emit(). Using yield in `on<Event>`
/// handlers is deprecated and won't work correctly.
///
/// **BAD:**
/// ```dart
/// on<MyEvent>((event, emit) async* {
///   yield LoadingState();  // Wrong!
///   yield LoadedState();
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// on<MyEvent>((event, emit) async {
///   emit(LoadingState());
///   emit(LoadedState());
/// });
/// ```
class AvoidYieldInOnEventRule extends SaropaLintRule {
  const AvoidYieldInOnEventRule() : super(code: _code);

  /// Using yield in Bloc handlers is deprecated and broken.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_yield_in_on_event',
    problemMessage:
        '[avoid_yield_in_on_event] yield breaks Bloc 8.0+ concurrency and '
        'event ordering, causing unpredictable state updates.',
    correctionMessage:
        'Replace yield with emit() - yield is deprecated in Bloc 8.0+.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addYieldStatement((YieldStatement node) {
      // Check if inside on<Event> handler
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodInvocation) {
          final String methodName = current.methodName.name;
          if (methodName == 'on') {
            reporter.atNode(node, code);
            return;
          }
        }
        if (current is ClassDeclaration) break;
        current = current.parent;
      }
    });
  }
}

/// Warns when Bloc state is mutated with cascade instead of new instance.
///
/// Bloc states should be immutable. Using cascade (..) to mutate existing
/// state breaks Bloc's equality comparison and causes missed rebuilds.
///
/// **BAD:**
/// ```dart
/// emit(state..items.add(newItem));  // Mutation!
/// emit(state..count = newCount);
/// ```
///
/// **GOOD:**
/// ```dart
/// emit(state.copyWith(items: [...state.items, newItem]));
/// emit(MyState(count: newCount));
/// ```
class EmitNewBlocStateInstancesRule extends SaropaLintRule {
  const EmitNewBlocStateInstancesRule() : super(code: _code);

  /// State mutation breaks Bloc equality and causes bugs.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'emit_new_bloc_state_instances',
    problemMessage:
        '[emit_new_bloc_state_instances] Mutating state object breaks equality '
        'checks, preventing BlocBuilder from detecting changes.',
    correctionMessage: 'Use copyWith() or constructor to create new state.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'emit') return;

      // Check argument for cascade expression
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression arg = args.first;
      if (arg is CascadeExpression) {
        // Check if target is 'state'
        final String targetSource = arg.target.toSource();
        if (targetSource == 'state') {
          reporter.atNode(arg, code);
        }
      }
    });
  }
}

/// Warns when Bloc has public non-final fields.
///
/// Bloc internals should be private. Public fields expose implementation
/// details and allow external modification of state.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   int counter = 0;  // Public mutable field
///   List<Item> items = [];
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   int _counter = 0;  // Private
///   final List<Item> _items = [];
/// }
/// ```
class AvoidBlocPublicFieldsRule extends SaropaLintRule {
  const AvoidBlocPublicFieldsRule() : super(code: _code);

  /// Public fields expose Bloc internals and break encapsulation.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_public_fields',
    problemMessage:
        '[avoid_bloc_public_fields] Public field in Bloc. Keep internals private.',
    correctionMessage: 'Make field private (_fieldName) or final.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Bloc or Cubit
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Check for public non-final fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          // Skip if private (starts with _)
          for (final VariableDeclaration field in member.fields.variables) {
            final String fieldName = field.name.lexeme;
            if (!fieldName.startsWith('_') && !member.fields.isFinal) {
              reporter.atNode(field, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when Bloc has public methods other than add().
///
/// Bloc should only expose add() for events. Other public methods
/// break the event-driven architecture and make testing harder.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   void loadData() { ... }  // Direct method call!
///   void reset() { ... }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   // Use events instead
///   // bloc.add(LoadDataEvent());
///   // bloc.add(ResetEvent());
/// }
/// ```
class AvoidBlocPublicMethodsRule extends SaropaLintRule {
  const AvoidBlocPublicMethodsRule() : super(code: _code);

  /// Public methods bypass Bloc's event-driven architecture.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_public_methods',
    problemMessage:
        '[avoid_bloc_public_methods] Public method in Bloc. Use events via add() instead.',
    correctionMessage: 'Convert to event class and handle in on<Event>().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _allowedMethods = <String>{
    'add',
    'close',
    'emit',
    'on',
    'onChange',
    'onError',
    'onEvent',
    'onTransition',
    'toString',
    'hashCode',
    'noSuchMethod',
    'runtimeType',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Bloc
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc') return;

      // Check for public methods
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          final String methodName = member.name.lexeme;
          // Skip private, allowed, and overrides
          if (methodName.startsWith('_')) continue;
          if (_allowedMethods.contains(methodName)) continue;
          if (member.metadata.any((a) => a.name.name == 'override')) continue;

          reporter.atToken(member.name, code);
        }
      }
    });
  }
}

/// Warns when BlocBuilder accesses only one field from state.
///
/// Using BlocSelector instead of BlocBuilder when you only need one
/// field prevents unnecessary rebuilds when other fields change.
///
/// **BAD:**
/// ```dart
/// BlocBuilder<MyBloc, MyState>(
///   builder: (context, state) {
///     return Text(state.name);  // Only uses one field
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// BlocSelector<MyBloc, MyState, String>(
///   selector: (state) => state.name,
///   builder: (context, name) {
///     return Text(name);
///   },
/// )
/// ```
class RequireBlocSelectorRule extends SaropaLintRule {
  const RequireBlocSelectorRule() : super(code: _code);

  /// BlocSelector provides more targeted rebuilds.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_selector',
    problemMessage:
        '[require_bloc_selector] BlocBuilder accessing single field. Use BlocSelector instead.',
    correctionMessage:
        'Replace with BlocSelector for targeted rebuilds on specific field.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'BlocBuilder') return;

      // Find builder parameter
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          final Expression builderExpr = arg.expression;
          if (builderExpr is FunctionExpression) {
            // Count state property accesses
            final _StateAccessCounter counter = _StateAccessCounter();
            builderExpr.body.accept(counter);

            // If only one unique field is accessed, suggest BlocSelector
            if (counter.accessedFields.length == 1 &&
                counter.accessCount <= 2) {
              reporter.atNode(node, code);
            }
          }
        }
      }
    });
  }
}

class _StateAccessCounter extends RecursiveAstVisitor<void> {
  final Set<String> accessedFields = <String>{};
  int accessCount = 0;

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final Expression? target = node.target;
    if (target is SimpleIdentifier && target.name == 'state') {
      accessedFields.add(node.propertyName.name);
      accessCount++;
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == 'state') {
      accessedFields.add(node.identifier.name);
      accessCount++;
    }
    super.visitPrefixedIdentifier(node);
  }
}

/// Warns when emit() is called without checking isClosed in async handlers.
///
/// Alias: bloc_emit_after_close, unsafe_emit
///
/// After async operations, the Bloc may have been closed. Emitting to a
/// closed Bloc throws an error.
///
/// **BAD:**
/// ```dart
/// Future<void> _onFetch(FetchEvent event, Emitter<State> emit) async {
///   final data = await api.fetch();
///   emit(LoadedState(data));  // Bloc might be closed!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> _onFetch(FetchEvent event, Emitter<State> emit) async {
///   final data = await api.fetch();
///   if (!isClosed) {
///     emit(LoadedState(data));
///   }
/// }
/// ```
class AvoidBlocEmitAfterCloseRule extends SaropaLintRule {
  const AvoidBlocEmitAfterCloseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_emit_after_close',
    problemMessage:
        '[avoid_bloc_emit_after_close] Calling emit() after an await may throw an exception if the Bloc has been closed, leading to runtime errors and unpredictable state changes. This can cause crashes or silent failures, especially in asynchronous event handlers. Always check that the Bloc is still open before emitting new states after an await.',
    correctionMessage:
        'Before calling emit() after an await, add an "if (!isClosed)" check to ensure the Bloc is still active. This prevents exceptions and ensures state updates are only performed on open Blocs.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'emit') return;

      // Find enclosing method
      AstNode? current = node.parent;
      MethodDeclaration? enclosingMethod;

      while (current != null) {
        if (current is MethodDeclaration) {
          enclosingMethod = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingMethod == null) return;

      // Check if method is async
      if (enclosingMethod.body is! BlockFunctionBody) return;
      final body = enclosingMethod.body as BlockFunctionBody;
      if (body.keyword?.lexeme != 'async') return;

      // Check if emit is after an await expression
      final methodSource = enclosingMethod.body.toSource();
      final emitOffset = node.offset - enclosingMethod.body.offset;

      // Simple heuristic: check if there's an await before this emit
      final beforeEmit =
          methodSource.substring(0, emitOffset.clamp(0, methodSource.length));
      if (!beforeEmit.contains('await ')) return;

      // Check if there's an isClosed check protecting this emit
      AstNode? parentNode = node.parent;
      bool hasIsClosedCheck = false;

      while (parentNode != null && parentNode != enclosingMethod) {
        if (parentNode is IfStatement) {
          final condition = parentNode.expression.toSource();
          if (condition.contains('isClosed') ||
              condition.contains('!isClosed')) {
            hasIsClosedCheck = true;
            break;
          }
        }
        parentNode = parentNode.parent;
      }

      if (!hasIsClosedCheck) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when Bloc state is mutated directly instead of using copyWith.
///
/// Alias: bloc_state_direct_mutation, immutable_bloc_state
///
/// Bloc states should be immutable. Direct mutation causes bugs because
/// the framework compares by reference.
///
/// **BAD:**
/// ```dart
/// void _onUpdate(UpdateEvent event, Emitter<State> emit) {
///   state.name = event.name;  // Direct mutation!
///   emit(state);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void _onUpdate(UpdateEvent event, Emitter<State> emit) {
///   emit(state.copyWith(name: event.name));
/// }
/// ```
class AvoidBlocStateMutationRule extends SaropaLintRule {
  const AvoidBlocStateMutationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_state_mutation',
    problemMessage:
        '[avoid_bloc_state_mutation] Direct mutation bypasses equality checks, '
        'preventing UI rebuild and causing stale data display.',
    correctionMessage: 'Use state.copyWith() to create a new state instance.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      // Check for state.field = value pattern
      final leftSide = node.leftHandSide;
      if (leftSide is! PropertyAccess) return;

      final target = leftSide.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'state') return;

      // Check if inside a Bloc class
      AstNode? current = node.parent;
      while (current != null) {
        if (current is ClassDeclaration) {
          final extendsClause = current.extendsClause;
          if (extendsClause != null) {
            final superName = extendsClause.superclass.name.lexeme;
            if (superName == 'Bloc' || superName == 'Cubit') {
              reporter.atNode(leftSide, code);
              return;
            }
          }
          break;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when Bloc constructor doesn't call super with initial state.
///
/// Alias: bloc_missing_initial_state, bloc_super_required
///
/// Every Bloc must specify its initial state in the super() constructor call.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   MyBloc() {  // Missing super call!
///     on<MyEvent>(_onEvent);
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   MyBloc() : super(MyInitialState()) {
///     on<MyEvent>(_onEvent);
///   }
/// }
/// ```
class RequireBlocInitialStateRule extends SaropaLintRule {
  const RequireBlocInitialStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_initial_state',
    problemMessage: '[require_bloc_initial_state] Missing initial state throws '
        'LateInitializationError when BlocBuilder tries to read state.',
    correctionMessage: 'Add : super(InitialState()) to the constructor.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Find constructors
      for (final member in node.members) {
        if (member is ConstructorDeclaration) {
          // Check for super initializer
          bool hasSuperInit = false;
          for (final initializer in member.initializers) {
            if (initializer is SuperConstructorInvocation) {
              hasSuperInit = true;
              break;
            }
          }

          if (!hasSuperInit) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

/// Warns when Bloc async handler doesn't emit loading state.
///
/// Alias: bloc_missing_loading, async_loading_state
///
/// Async operations should emit loading state to show UI feedback.
///
/// **BAD:**
/// ```dart
/// Future<void> _onFetch(FetchEvent event, Emitter<State> emit) async {
///   final data = await api.fetch();  // No loading state!
///   emit(LoadedState(data));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> _onFetch(FetchEvent event, Emitter<State> emit) async {
///   emit(LoadingState());
///   final data = await api.fetch();
///   emit(LoadedState(data));
/// }
/// ```
class RequireBlocLoadingStateRule extends SaropaLintRule {
  const RequireBlocLoadingStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_loading_state',
    problemMessage:
        '[require_bloc_loading_state] Async Bloc handler should emit loading state.',
    correctionMessage: 'Add emit(LoadingState()) before async operations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Check if async method
      if (node.body is! BlockFunctionBody) return;
      final body = node.body as BlockFunctionBody;
      if (body.keyword?.lexeme != 'async') return;

      // Check if in Bloc class
      final parent = node.parent;
      if (parent is! ClassDeclaration) return;
      final extendsClause = parent.extendsClause;
      if (extendsClause == null) return;
      final superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Check if method has Emitter parameter (Bloc handler)
      bool hasEmitter = false;
      for (final param in node.parameters?.parameters ?? <FormalParameter>[]) {
        final paramSource = param.toSource();
        if (paramSource.contains('Emitter')) {
          hasEmitter = true;
          break;
        }
      }

      if (!hasEmitter) return;

      // Check if emit is called before await
      final methodSource = body.toSource();
      final awaitIndex = methodSource.indexOf('await ');
      if (awaitIndex == -1) return;

      final beforeAwait = methodSource.substring(0, awaitIndex);

      // cspell:ignore inprogress
      final hasLoadingEmit = beforeAwait.contains('emit(') &&
          (beforeAwait.toLowerCase().contains('loading') ||
              beforeAwait.toLowerCase().contains('inprogress'));

      if (!hasLoadingEmit) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Bloc state sealed class doesn't have an error case.
///
/// Alias: bloc_missing_error_state, state_error_handling
///
/// Bloc states should include an error case for proper error handling.
///
/// **BAD:**
/// ```dart
/// sealed class UserState {}
/// class UserInitial extends UserState {}
/// class UserLoaded extends UserState {}
/// // Missing error state!
/// ```
///
/// **GOOD:**
/// ```dart
/// sealed class UserState {}
/// class UserInitial extends UserState {}
/// class UserLoaded extends UserState {}
/// class UserError extends UserState {}
/// ```
class RequireBlocErrorStateRule extends SaropaLintRule {
  const RequireBlocErrorStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_error_state',
    problemMessage:
        '[require_bloc_error_state] Bloc state sealed class should have an error case.',
    correctionMessage: 'Add an error state class (e.g., UserError).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if sealed class ending with State
      if (node.sealedKeyword == null) return;
      if (!node.name.lexeme.endsWith('State')) return;

      // This is a sealed state class - check file for error subclass
      final fileSource = resolver.source.contents.data;
      final className = node.name.lexeme;
      final baseName = className.replaceAll('State', '');

      // Look for error/failure subclass
      final hasError = fileSource.contains('${baseName}Error') ||
          fileSource.contains('${baseName}Failure') ||
          fileSource.contains('${className}Error') ||
          fileSource.contains('Error extends $className');

      if (!hasError) {
        reporter.atNode(node, code);
      }
    });
  }
}

// cspell:ignore antipattern

/// Warns when Bloc/Cubit has controllers or streams without close() cleanup.
///
/// Alias: bloc_dispose, bloc_close, cubit_dispose
///
/// Bloc and Cubit subclasses that create StreamControllers, TextEditingControllers,
/// or other disposable resources must override close() to dispose of them.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   final _controller = StreamController<int>();
///   final _textController = TextEditingController();
///
///   MyBloc() : super(MyInitial());
///   // Missing close() - resources leak!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   final _controller = StreamController<int>();
///   final _textController = TextEditingController();
///
///   MyBloc() : super(MyInitial());
///
///   @override
///   Future<void> close() {
///     _controller.close();
///     _textController.dispose();
///     return super.close();
///   }
/// }
/// ```
class RequireBlocManualDisposeRule extends SaropaLintRule {
  const RequireBlocManualDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_bloc_manual_dispose',
    problemMessage:
        '[require_bloc_manual_dispose] Bloc or Cubit holds StreamController or Timer fields but does not override close() to dispose them. Undisposed resources cause memory leaks that accumulate across navigation, eventually increasing memory pressure until the operating system kills the app.',
    correctionMessage:
        'Override close() to dispose StreamController, Timer, and other held resources, then call super.close() to complete the Bloc lifecycle.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Types that require disposal in Bloc/Cubit close() method
  static const Set<String> _disposableTypes = <String>{
    'StreamController',
    'TextEditingController',
    'ScrollController',
    'PageController',
    'TabController',
    'AnimationController',
    'FocusNode',
    'Timer',
    'StreamSubscription',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Bloc or Cubit
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (!superName.contains('Bloc') && !superName.contains('Cubit')) {
        return;
      }

      // Find disposable fields
      final List<String> disposableFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null) {
            for (final String disposableType in _disposableTypes) {
              if (typeName.contains(disposableType)) {
                for (final VariableDeclaration variable
                    in member.fields.variables) {
                  disposableFields.add(variable.name.lexeme);
                }
                break;
              }
            }
          }
          // Also check initializers
          for (final VariableDeclaration variable in member.fields.variables) {
            final Expression? initializer = variable.initializer;
            if (initializer is InstanceCreationExpression) {
              final String initType =
                  initializer.constructorName.type.name.lexeme;
              if (_disposableTypes.contains(initType)) {
                if (!disposableFields.contains(variable.name.lexeme)) {
                  disposableFields.add(variable.name.lexeme);
                }
              }
            }
          }
        }
      }

      if (disposableFields.isEmpty) return;

      // Check for close() method
      bool hasCloseMethod = false;
      String? closeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'close') {
          hasCloseMethod = true;
          closeBody = member.body.toSource();
          break;
        }
      }

      if (!hasCloseMethod) {
        // No close() method at all
        reporter.atToken(node.name, code);
        return;
      }

      // Check if all disposable fields are cleaned up
      for (final String fieldName in disposableFields) {
        final bool isCleaned = closeBody != null &&
            (closeBody.contains('$fieldName.close()') ||
                closeBody.contains('$fieldName?.close()') ||
                closeBody.contains('$fieldName.dispose()') ||
                closeBody.contains('$fieldName?.dispose()') ||
                closeBody.contains('$fieldName.cancel()') ||
                closeBody.contains('$fieldName?.cancel()'));

        if (!isCleaned) {
          // Report the specific field that's not cleaned up
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == fieldName) {
                  reporter.atNode(variable, code);
                }
              }
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// Provider Dependency Rules

/// Suggests using Cubit instead of Bloc when only one event type exists.
///
/// Bloc is designed for complex state management with multiple events.
/// When a Bloc only has one event type, a Cubit is simpler and more direct.
///
/// **BAD:**
/// ```dart
/// // Events
/// abstract class CounterEvent {}
/// class IncrementEvent extends CounterEvent {}
///
/// // Bloc with only one event type
/// class CounterBloc extends Bloc<CounterEvent, int> {
///   CounterBloc() : super(0) {
///     on<IncrementEvent>((event, emit) => emit(state + 1));
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class CounterCubit extends Cubit<int> {
///   CounterCubit() : super(0);
///
///   void increment() => emit(state + 1);
/// }
/// ```
class PreferCubitForSimpleStateRule extends SaropaLintRule {
  const PreferCubitForSimpleStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'prefer_cubit_for_simple_state',
    problemMessage:
        '[prefer_cubit_for_simple_state] Bloc with single event type. Consider using Cubit for simpler code.',
    correctionMessage:
        'Replace with Cubit when only one event/action is needed.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Bloc<Event, State>
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc') return;

      // Count the number of on<EventType> handlers
      int eventHandlerCount = 0;
      final Set<String> eventTypes = <String>{};

      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          final String bodySource = member.body.toSource();

          // Find all on<EventType> patterns
          final RegExp onEventPattern = RegExp(r'on<(\w+)>');
          final Iterable<RegExpMatch> matches =
              onEventPattern.allMatches(bodySource);

          for (final RegExpMatch match in matches) {
            eventHandlerCount++;
            eventTypes.add(match.group(1)!);
          }
        }
      }

      // If only one event type is handled, suggest Cubit
      if (eventHandlerCount == 1 && eventTypes.length == 1) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when side effects (navigation, snackbar) are performed in BlocBuilder.
///
/// BlocBuilder is for building UI based on state. Side effects should be
/// handled in BlocListener to ensure they only execute once per state change.
///
/// **BAD:**
/// ```dart
/// BlocBuilder<AuthBloc, AuthState>(
///   builder: (context, state) {
///     if (state is AuthSuccess) {
///       Navigator.pushNamed(context, '/home'); // Called on every rebuild!
///     }
///     return Container();
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// BlocListener<AuthBloc, AuthState>(
///   listener: (context, state) {
///     if (state is AuthSuccess) {
///       Navigator.pushNamed(context, '/home'); // Called once per state
///     }
///   },
///   child: BlocBuilder<AuthBloc, AuthState>(
///     builder: (context, state) => Container(),
///   ),
/// )
/// // Or use BlocConsumer for both
/// ```
class PreferBlocListenerForSideEffectsRule extends SaropaLintRule {
  const PreferBlocListenerForSideEffectsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'prefer_bloc_listener_for_side_effects',
    problemMessage:
        '[prefer_bloc_listener_for_side_effects] Side effects inside BlocBuilder execute on every widget rebuild, causing user-facing errors like duplicate navigation pushes, multiple snackbars stacking on screen, or repeated API calls that waste bandwidth and may corrupt server-side state.',
    correctionMessage:
        'Move side effects (navigation, snackbars, API calls) to BlocListener or use BlocConsumer to separate rebuilds from one-time actions.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Patterns that indicate side effects
  static const Set<String> _sideEffectPatterns = <String>{
    'Navigator.',
    'Navigator.of(',
    '.pushNamed(',
    '.push(',
    '.pop(',
    '.pushReplacement',
    'context.go(',
    'context.push(',
    'GoRouter.of(',
    'showDialog(',
    'showModalBottomSheet(',
    'showSnackBar(',
    'ScaffoldMessenger.',
    'Scaffold.of(',
    '.showSnackBar(',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'BlocBuilder') return;

      // Find the builder argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          final String builderSource = arg.expression.toSource();

          // Check for side effect patterns
          for (final String pattern in _sideEffectPatterns) {
            if (builderSource.contains(pattern)) {
              reporter.atNode(node.constructorName, code);
              return;
            }
          }
        }
      }
    });
  }
}

/// Suggests using BlocConsumer when both BlocListener and BlocBuilder are nested.
///
/// When you need both listener (for side effects) and builder (for UI),
/// BlocConsumer provides a cleaner single-widget solution.
///
/// **BAD:**
/// ```dart
/// BlocListener<AuthBloc, AuthState>(
///   listener: (context, state) {
///     if (state is AuthError) showSnackBar(...);
///   },
///   child: BlocBuilder<AuthBloc, AuthState>(
///     builder: (context, state) {
///       return Text(state.toString());
///     },
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// BlocConsumer<AuthBloc, AuthState>(
///   listener: (context, state) {
///     if (state is AuthError) showSnackBar(...);
///   },
///   builder: (context, state) {
///     return Text(state.toString());
///   },
/// )
/// ```
class RequireBlocConsumerWhenBothRule extends SaropaLintRule {
  const RequireBlocConsumerWhenBothRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'require_bloc_consumer_when_both',
    problemMessage:
        '[require_bloc_consumer_when_both] Nested BlocListener + BlocBuilder. Use BlocConsumer instead.',
    correctionMessage:
        'Replace with BlocConsumer which combines listener and builder.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'BlocListener') return;

      // Check if the child is a BlocBuilder
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression childExpr = arg.expression;

          if (childExpr is InstanceCreationExpression) {
            final String childTypeName =
                childExpr.constructorName.type.name.lexeme;
            if (childTypeName == 'BlocBuilder') {
              // Check if they're for the same Bloc type
              final TypeArgumentList? listenerTypeArgs =
                  node.constructorName.type.typeArguments;
              final TypeArgumentList? builderTypeArgs =
                  childExpr.constructorName.type.typeArguments;

              if (listenerTypeArgs != null && builderTypeArgs != null) {
                final String listenerType = listenerTypeArgs.toSource();
                final String builderType = builderTypeArgs.toSource();

                // If same Bloc type, suggest BlocConsumer
                if (listenerType == builderType) {
                  reporter.atNode(node.constructorName, code);
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when BuildContext is passed to Bloc constructor.
///
/// Alias: bloc_context, context_in_bloc
///
/// Blocs should be independent of the widget tree. Passing BuildContext
/// to a Bloc couples it to the UI and makes testing difficult.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   MyBloc(BuildContext context) : super(MyInitial()) {
///     // Using context in bloc
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   MyBloc(MyRepository repository) : super(MyInitial()) {
///     // Inject dependencies, not context
///   }
/// }
/// ```
class AvoidBlocContextDependencyRule extends SaropaLintRule {
  const AvoidBlocContextDependencyRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_context_dependency',
    problemMessage:
        '[avoid_bloc_context_dependency] Bloc depending on BuildContext couples business logic to the UI layer. This makes the Bloc untestable in isolation, prevents reuse across widgets, and can cause crashes when the context becomes invalid after the widget is removed from the tree.',
    correctionMessage:
        'Inject dependencies through the constructor instead of passing BuildContext, keeping business logic independent from the UI layer for better testability.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _blocSuperclasses = <String>{
    'Bloc',
    'Cubit',
    'StateNotifier',
    'ChangeNotifier',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a Bloc/Cubit
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (!_blocSuperclasses.contains(superclassName)) return;

      // Check constructors for BuildContext parameter
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          final FormalParameterList? params = member.parameters;
          if (params == null) continue;

          for (final FormalParameter param in params.parameters) {
            final String paramSource = param.toSource();
            if (paramSource.contains('BuildContext')) {
              reporter.atNode(param, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when Bloc contains BuildContext usage or UI dependencies.
///
/// Alias: bloc_no_context, bloc_separation, bloc_business_logic
///
/// Blocs should contain only business logic, not UI-related code.
/// BuildContext dependencies make Blocs harder to test and reuse.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   void _onEvent(Event event, Emitter<State> emit) {
///     Navigator.of(context).push(...); // UI in Bloc!
///     ScaffoldMessenger.of(context).showSnackBar(...); // UI in Bloc!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   void _onEvent(Event event, Emitter<State> emit) {
///     emit(NavigateToDetailState()); // Emit state for UI to handle
///   }
/// }
/// ```
class AvoidBlocBusinessLogicInUiRule extends SaropaLintRule {
  const AvoidBlocBusinessLogicInUiRule() : super(code: _code);

  /// Blocs with UI code are hard to test and violate separation.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_business_logic_in_ui',
    problemMessage:
        '[avoid_bloc_business_logic_in_ui] UI code such as showDialog or Navigator calls inside a Bloc breaks separation of concerns and makes the Bloc untestable without a widget tree. Business logic becomes coupled to the UI framework, preventing reuse across platforms and complicating unit testing.',
    correctionMessage:
        'Emit a state representing the UI action (e.g., ShowDialogState or NavigateState) and handle the actual UI change in a BlocListener within the widget layer.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Methods that indicate UI code.
  static const Set<String> _uiMethods = <String>{
    'showSnackBar',
    'showDialog',
    'showModalBottomSheet',
    'push',
    'pushNamed',
    'pop',
    'pushReplacement',
    'pushReplacementNamed',
    'showDatePicker',
    'showTimePicker',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_uiMethods.contains(methodName)) return;

      // Check if inside a Bloc class
      AstNode? current = node.parent;
      while (current != null) {
        if (current is ClassDeclaration) {
          final String? extendsName =
              current.extendsClause?.superclass.name2.lexeme;
          if (extendsName != null &&
              (extendsName == 'Bloc' || extendsName == 'Cubit')) {
            reporter.atNode(node, code);
          }
          return;
        }
        current = current.parent;
      }
    });
  }
}

// =============================================================================
// ROADMAP_NEXT: Phase 4 - State Management Rules

/// Warns when Bloc events are not sealed classes.
///
/// Alias: bloc_event_sealed, sealed_bloc_event, event_sealed
///
/// Using sealed classes for Bloc events enables exhaustive pattern matching
/// and prevents invalid event subtypes.
///
/// **BAD:**
/// ```dart
/// abstract class CounterEvent {}
/// class IncrementEvent extends CounterEvent {}
/// class DecrementEvent extends CounterEvent {}
/// ```
///
/// **GOOD:**
/// ```dart
/// sealed class CounterEvent {}
/// final class IncrementEvent extends CounterEvent {}
/// final class DecrementEvent extends CounterEvent {}
/// ```
class RequireBlocEventSealedRule extends SaropaLintRule {
  const RequireBlocEventSealedRule() : super(code: _code);

  /// Type safety improvement.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_event_sealed',
    problemMessage:
        '[require_bloc_event_sealed] Bloc event hierarchy should use sealed class for exhaustive matching.',
    correctionMessage:
        'Change abstract class XEvent to sealed class XEvent for Dart 3+ pattern matching.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class name ends with Event
      final name = node.name.lexeme;
      if (!name.endsWith('Event')) return;

      // Check if it's abstract but not sealed
      if (node.abstractKeyword != null && node.sealedKeyword == null) {
        // Make sure it looks like a Bloc event (has subclasses pattern)
        if (node.members.isEmpty || _looksLikeBlocEvent(node)) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  bool _looksLikeBlocEvent(ClassDeclaration node) {
    // Empty body is common for event base classes
    if (node.members.isEmpty) return true;

    // Only has constructors
    return node.members.every((member) => member is ConstructorDeclaration);
  }
}

/// Warns when Bloc directly depends on repository implementations.
///
/// Alias: bloc_repository, bloc_abstract_repo, bloc_di
///
/// Blocs should depend on abstract repository interfaces, not concrete
/// implementations. This enables testing and swapping implementations.
///
/// **BAD:**
/// ```dart
/// class UserBloc extends Bloc<UserEvent, UserState> {
///   UserBloc() : super(UserInitial()) {
///     _repo = FirebaseUserRepository(); // Concrete implementation!
///   }
///   late final FirebaseUserRepository _repo;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserBloc extends Bloc<UserEvent, UserState> {
///   UserBloc(this._repo) : super(UserInitial());
///   final UserRepository _repo; // Abstract interface
/// }
/// ```
class RequireBlocRepositoryAbstractionRule extends SaropaLintRule {
  const RequireBlocRepositoryAbstractionRule() : super(code: _code);

  /// Architecture improvement.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  /// Alias: require_bloc_repository_abstraction_layer
  static const LintCode _code = LintCode(
    name: 'require_bloc_repository_abstraction',
    problemMessage:
        '[require_bloc_repository_abstraction] Bloc depends on concrete repository. Use abstract interface for testability.',
    correctionMessage:
        'Inject UserRepository interface instead of FirebaseUserRepository.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Prefixes that indicate concrete implementations.
  static const Set<String> _concretePrefixes = <String>{
    'Firebase',
    'Postgres',
    'Mysql',
    'Sqlite',
    'Http',
    'Rest',
    'Grpc',
    'Mock',
    'Fake',
    'Real',
    'Local',
    'Remote',
    'Cached',
    'Impl',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class is a Bloc
      final extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Check fields for concrete repository types
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          final type = member.fields.type;
          if (type == null) continue;

          final typeName = type.toSource();
          for (final prefix in _concretePrefixes) {
            if (typeName.startsWith(prefix) &&
                (typeName.contains('Repository') ||
                    typeName.contains('Service') ||
                    typeName.contains('DataSource'))) {
              reporter.atNode(member, code);
              break;
            }
          }
        }
      }
    });
  }
}

/// Warns when Bloc doesn't use transform for event debouncing/throttling.
///
/// Alias: bloc_transform, event_transformer, debounce_bloc
///
/// For events like search queries, use EventTransformer to debounce or
/// throttle, preventing excessive API calls.
///
/// **BAD:**
/// ```dart
/// class SearchBloc extends Bloc<SearchEvent, SearchState> {
///   SearchBloc() : super(SearchInitial()) {
///     on<SearchQueryChanged>(_onQueryChanged); // No debounce!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class SearchBloc extends Bloc<SearchEvent, SearchState> {
///   SearchBloc() : super(SearchInitial()) {
///     on<SearchQueryChanged>(
///       _onQueryChanged,
///       transformer: debounce(Duration(milliseconds: 300)),
///     );
///   }
/// }
/// ```
class PreferBlocTransformRule extends SaropaLintRule {
  const PreferBlocTransformRule() : super(code: _code);

  /// Performance suggestion.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  /// Alias: prefer_bloc_transform_pattern
  static const LintCode _code = LintCode(
    name: 'prefer_bloc_transform',
    problemMessage:
        '[prefer_bloc_transform] Search/input event without transformer. Consider debounce/throttle.',
    correctionMessage:
        'Add transformer: debounce(Duration(milliseconds: 300)) to on<Event>().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Event name patterns that typically need debouncing.
  static const Set<String> _debounceCandidates = <String>{
    'SearchQueryChanged',
    'SearchTextChanged',
    'QueryChanged',
    'TextChanged',
    'InputChanged',
    'FilterChanged',
    'TypeaheadChanged',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'on') return;

      // Check if inside a Bloc constructor
      if (!_isInsideBlocConstructor(node)) return;

      // Check type argument
      final typeArgs = node.typeArguments;
      if (typeArgs == null || typeArgs.arguments.isEmpty) return;

      final eventType = typeArgs.arguments.first.toSource();

      // Check if event looks like it needs debouncing
      final needsDebounce = _debounceCandidates.any(
        (candidate) => eventType.contains(candidate),
      );

      if (!needsDebounce) return;

      // Check if transformer is provided
      final args = node.argumentList.arguments;
      final hasTransformer = args.any((arg) {
        return arg is NamedExpression && arg.name.label.name == 'transformer';
      });

      if (!hasTransformer) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideBlocConstructor(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ConstructorDeclaration) {
        // Check if constructor belongs to a Bloc
        final parent = current.parent;
        if (parent is ClassDeclaration) {
          final extendsClause = parent.extendsClause;
          if (extendsClause != null) {
            final superName = extendsClause.superclass.name.lexeme;
            return superName == 'Bloc';
          }
        }
      }
      current = current.parent;
    }
    return false;
  }
}

// =============================================================================
// NEW ROADMAP STAR RULES - Bloc/Cubit Rules

/// Warns when Bloc constructor receives another Bloc as dependency.
///
/// Blocs should not directly depend on other Blocs. This creates tight coupling
/// and makes testing difficult. Use streams or events for inter-Bloc communication.
///
/// **BAD:**
/// ```dart
/// class CartBloc extends Bloc<CartEvent, CartState> {
///   CartBloc(this.userBloc) : super(CartInitial());
///   final UserBloc userBloc; // Direct Bloc dependency!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class CartBloc extends Bloc<CartEvent, CartState> {
///   CartBloc({required Stream<User> userStream}) : super(CartInitial()) {
///     userStream.listen((user) => add(UserChanged(user)));
///   }
/// }
/// ```
class AvoidPassingBlocToBlocRule extends SaropaLintRule {
  const AvoidPassingBlocToBlocRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_passing_bloc_to_bloc',
    problemMessage:
        '[avoid_passing_bloc_to_bloc] Bloc should not depend on another Bloc. '
        'This creates tight coupling and makes testing difficult.',
    correctionMessage:
        'Use streams or events for inter-Bloc communication instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Check constructor parameters for Bloc types
      for (final member in node.members) {
        if (member is ConstructorDeclaration) {
          _checkConstructorParams(member, reporter);
        }
        // Also check field types
        if (member is FieldDeclaration) {
          _checkFieldTypes(member, reporter);
        }
      }
    });
  }

  void _checkConstructorParams(
    ConstructorDeclaration constructor,
    SaropaDiagnosticReporter reporter,
  ) {
    final params = constructor.parameters;
    for (final param in params.parameters) {
      final String? typeName = _getParameterTypeName(param);
      if (typeName != null && _isBlocType(typeName)) {
        reporter.atNode(param, code);
      }
    }
  }

  void _checkFieldTypes(
    FieldDeclaration field,
    SaropaDiagnosticReporter reporter,
  ) {
    final typeName = field.fields.type?.toSource();
    if (typeName != null && _isBlocType(typeName)) {
      for (final variable in field.fields.variables) {
        reporter.atNode(variable, code);
      }
    }
  }

  String? _getParameterTypeName(FormalParameter param) {
    if (param is SimpleFormalParameter) {
      return param.type?.toSource();
    } else if (param is DefaultFormalParameter) {
      final inner = param.parameter;
      if (inner is SimpleFormalParameter) {
        return inner.type?.toSource();
      }
    }
    return null;
  }

  bool _isBlocType(String typeName) {
    return typeName.endsWith('Bloc') || typeName.endsWith('Cubit');
  }
}

/// Warns when BuildContext is passed to Bloc or Cubit.
///
/// BuildContext in Blocs couples UI to business logic and makes testing
/// difficult. Blocs should be context-agnostic.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   MyBloc(this.context) : super(MyInitial());
///   final BuildContext context; // Context in Bloc!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   MyBloc({required this.repository}) : super(MyInitial());
///   final MyRepository repository;
/// }
/// ```
class AvoidPassingBuildContextToBlocsRule extends SaropaLintRule {
  const AvoidPassingBuildContextToBlocsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_passing_build_context_to_blocs',
    problemMessage:
        '[avoid_passing_build_context_to_blocs] BuildContext in Bloc couples '
        'UI to business logic and makes testing difficult.',
    correctionMessage:
        'Remove BuildContext parameter. Extract needed values before passing to Bloc.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Check constructor parameters
      for (final member in node.members) {
        if (member is ConstructorDeclaration) {
          _checkForBuildContext(member, reporter);
        }
        // Also check field types
        if (member is FieldDeclaration) {
          final typeName = member.fields.type?.toSource();
          if (typeName == 'BuildContext') {
            for (final variable in member.fields.variables) {
              reporter.atNode(variable, code);
            }
          }
        }
      }
    });
  }

  void _checkForBuildContext(
    ConstructorDeclaration constructor,
    SaropaDiagnosticReporter reporter,
  ) {
    for (final param in constructor.parameters.parameters) {
      String? typeName;
      if (param is SimpleFormalParameter) {
        typeName = param.type?.toSource();
      } else if (param is DefaultFormalParameter) {
        final inner = param.parameter;
        if (inner is SimpleFormalParameter) {
          typeName = inner.type?.toSource();
        }
      }
      if (typeName == 'BuildContext') {
        reporter.atNode(param, code);
      }
    }
  }
}

/// Warns when Cubit methods return values instead of emitting states.
///
/// Cubit methods should emit states, not return values. Returning values
/// bypasses the reactive state management pattern.
///
/// **BAD:**
/// ```dart
/// class CounterCubit extends Cubit<int> {
///   CounterCubit() : super(0);
///   int increment() {
///     emit(state + 1);
///     return state; // Don't return values!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class CounterCubit extends Cubit<int> {
///   CounterCubit() : super(0);
///   void increment() {
///     emit(state + 1);
///   }
/// }
/// ```
class AvoidReturningValueFromCubitMethodsRule extends SaropaLintRule {
  const AvoidReturningValueFromCubitMethodsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_returning_value_from_cubit_methods',
    problemMessage:
        '[avoid_returning_value_from_cubit_methods] Cubit methods should emit '
        'states, not return values. This bypasses reactive state management.',
    correctionMessage:
        'Change return type to void and use emit() to update state.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Cubit') return;

      // Check methods
      for (final member in node.members) {
        if (member is MethodDeclaration) {
          _checkMethod(member, reporter);
        }
      }
    });
  }

  void _checkMethod(
      MethodDeclaration method, SaropaDiagnosticReporter reporter) {
    // Skip getters, setters, and special methods
    if (method.isGetter || method.isSetter || method.isStatic) return;
    if (method.name.lexeme == 'close' || method.name.lexeme == 'emit') return;

    // Check return type
    final returnType = method.returnType?.toSource();
    if (returnType == null) return;

    // void, Future<void>, and FutureOr<void> are acceptable
    if (returnType == 'void' ||
        returnType == 'Future<void>' ||
        returnType == 'FutureOr<void>') {
      return;
    }

    // Check if method calls emit()
    bool hasEmit = false;
    method.body.visitChildren(_EmitCallVisitor(() => hasEmit = true));

    if (hasEmit) {
      // Method both emits and returns a value - warn
      reporter.atNode(method.returnType!, code);
    }
  }
}

class _EmitCallVisitor extends RecursiveAstVisitor<void> {
  _EmitCallVisitor(this.onEmit);
  final void Function() onEmit;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'emit') {
      onEmit();
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when Bloc creates its own repository instead of receiving via constructor.
///
/// Blocs should receive repositories via constructor injection for testability.
///
/// **BAD:**
/// ```dart
/// class UserBloc extends Bloc<UserEvent, UserState> {
///   UserBloc() : super(UserInitial()) {
///     _repository = UserRepository(); // Creating dependency internally!
///   }
///   late final UserRepository _repository;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserBloc extends Bloc<UserEvent, UserState> {
///   UserBloc({required this.repository}) : super(UserInitial());
///   final UserRepository repository;
/// }
/// ```
class RequireBlocRepositoryInjectionRule extends SaropaLintRule {
  const RequireBlocRepositoryInjectionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_bloc_repository_injection',
    problemMessage:
        '[require_bloc_repository_injection] Bloc creates its own repository. '
        'This makes testing difficult and violates dependency injection.',
    correctionMessage:
        'Inject the repository via constructor parameter instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _repositorySuffixes = <String>{
    'Repository',
    'Service',
    'DataSource',
    'Api',
    'Client',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Check for repository creation inside constructors or field initializers
      for (final member in node.members) {
        if (member is ConstructorDeclaration) {
          _checkConstructor(member, reporter);
        }
        if (member is FieldDeclaration) {
          _checkFieldInitializer(member, reporter);
        }
      }
    });
  }

  void _checkConstructor(
    ConstructorDeclaration constructor,
    SaropaDiagnosticReporter reporter,
  ) {
    constructor.body.visitChildren(
      _RepositoryCreationVisitor((node) => reporter.atNode(node, code)),
    );
  }

  void _checkFieldInitializer(
    FieldDeclaration field,
    SaropaDiagnosticReporter reporter,
  ) {
    for (final variable in field.fields.variables) {
      final initializer = variable.initializer;
      if (initializer is InstanceCreationExpression) {
        final typeName = initializer.constructorName.type.name2.lexeme;
        if (_repositorySuffixes.any((s) => typeName.endsWith(s))) {
          reporter.atNode(initializer, code);
        }
      }
    }
  }
}

class _RepositoryCreationVisitor extends RecursiveAstVisitor<void> {
  _RepositoryCreationVisitor(this.onCreation);
  final void Function(AstNode) onCreation;

  static const Set<String> _repositorySuffixes = <String>{
    'Repository',
    'Service',
    'DataSource',
    'Api',
    'Client',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;
    if (_repositorySuffixes.any((s) => typeName.endsWith(s))) {
      onCreation(node);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when Bloc uses SharedPreferences instead of HydratedBloc for persistence.
///
/// Persistent state should use HydratedBloc for automatic persistence.
/// Manual SharedPreferences in Bloc is error-prone and creates coupling.
///
/// **BAD:**
/// ```dart
/// class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
///   SettingsBloc(this.prefs) : super(SettingsInitial());
///   final SharedPreferences prefs;
///
///   Future<void> _saveTheme(ThemeMode mode) async {
///     await prefs.setString('theme', mode.name);
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class SettingsBloc extends HydratedBloc<SettingsEvent, SettingsState> {
///   SettingsBloc() : super(SettingsInitial());
///
///   @override
///   SettingsState? fromJson(Map<String, dynamic> json) => SettingsState.fromJson(json);
///
///   @override
///   Map<String, dynamic>? toJson(SettingsState state) => state.toJson();
/// }
/// ```
class PreferBlocHydrationRule extends SaropaLintRule {
  const PreferBlocHydrationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_bloc_hydration',
    problemMessage:
        '[prefer_bloc_hydration] Bloc uses SharedPreferences for persistence. '
        'Consider using HydratedBloc for automatic state persistence.',
    correctionMessage:
        'Extend HydratedBloc instead and implement fromJson/toJson.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final superName = extendsClause.superclass.name.lexeme;
      // Skip if already using HydratedBloc
      if (superName == 'HydratedBloc' || superName == 'HydratedCubit') return;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Check for SharedPreferences usage
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          final typeName = member.fields.type?.toSource();
          if (typeName == 'SharedPreferences') {
            reporter.atToken(node.name, code);
            return;
          }
        }
      }

      // Also check method bodies for SharedPreferences calls
      for (final member in node.members) {
        if (member is MethodDeclaration) {
          bool hasSharedPrefs = false;
          member.body.visitChildren(
            _SharedPrefsUsageVisitor(() => hasSharedPrefs = true),
          );
          if (hasSharedPrefs) {
            reporter.atToken(node.name, code);
            return;
          }
        }
      }
    });
  }
}

class _SharedPrefsUsageVisitor extends RecursiveAstVisitor<void> {
  _SharedPrefsUsageVisitor(this.onFound);
  final void Function() onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target is SimpleIdentifier) {
      final name = target.name.toLowerCase();
      if (name.contains('prefs') || name.contains('preferences')) {
        final method = node.methodName.name;
        if (method.startsWith('get') || method.startsWith('set')) {
          onFound();
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when a Bloc class has too many event handlers.
///
/// `[HEURISTIC]` - Counts `on<Event>` registrations in constructor.
///
/// Blocs handling too many responsibilities become hard to maintain.
/// Keep Blocs focused on a single domain.
///
/// **BAD:**
/// ```dart
/// class KitchenSinkBloc extends Bloc<Event, State> {
///   KitchenSinkBloc() : super(Initial()) {
///     on<LoadUser>(_onLoadUser);
///     on<UpdateProfile>(_onUpdateProfile);
///     on<LoadOrders>(_onLoadOrders);
///     on<ProcessPayment>(_onProcessPayment);
///     on<SendNotification>(_onSendNotification);
///     // ... 10+ more handlers
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserBloc extends Bloc<UserEvent, UserState> { /* User only */ }
/// class OrderBloc extends Bloc<OrderEvent, OrderState> { /* Orders only */ }
/// class PaymentBloc extends Bloc<PaymentEvent, PaymentState> { /* Payments only */ }
/// ```
class AvoidLargeBlocRule extends SaropaLintRule {
  const AvoidLargeBlocRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_large_bloc',
    problemMessage:
        '[avoid_large_bloc] Bloc with 7+ event handlers becomes difficult to test and reason about.',
    correctionMessage:
        'Split into smaller domain-focused Blocs: UserBloc, OrderBloc, etc.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxEventHandlers = 7;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.toSource();
      if (!superclass.startsWith('Bloc<')) return;

      // Count on<Event> calls in the class
      int eventHandlerCount = 0;
      final String classSource = node.toSource();

      // Count on< patterns (event handler registrations)
      final RegExp onPattern = RegExp(r'\bon<\w+>\s*\(');
      eventHandlerCount = onPattern.allMatches(classSource).length;

      if (eventHandlerCount > _maxEventHandlers) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Bloc states are over-engineered.
///
/// `[HEURISTIC]` - Detects state classes with redundant states.
///
/// Separate states for "loading" and "idle" when a boolean would suffice.
/// Simpler state machines are easier to reason about.
///
/// **BAD:**
/// ```dart
/// abstract class UserState {}
/// class UserInitial extends UserState {}
/// class UserLoading extends UserState {}
/// class UserIdle extends UserState {}  // Redundant with Initial
/// class UserLoadingMore extends UserState {}  // Could be bool
/// class UserRefreshing extends UserState {}  // Could be bool
/// class UserLoaded extends UserState { final User user; }
/// class UserError extends UserState { final String message; }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserState {
///   final User? user;
///   final bool isLoading;
///   final String? error;
///   // Single state class with clear properties
/// }
/// ```
class AvoidOverengineeredBlocStatesRule extends SaropaLintRule {
  const AvoidOverengineeredBlocStatesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_overengineered_bloc_states',
    problemMessage:
        '[avoid_overengineered_bloc_states] More than 5 state subclasses adds complexity without benefit. Harder to maintain and test.',
    correctionMessage:
        'Use a single state class with isLoading, error, data properties.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxStateSubclasses = 5;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track state base classes and their subclasses
    final Map<String, List<ClassDeclaration>> stateHierarchy =
        <String, List<ClassDeclaration>>{};

    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;

      // Check if this is a state base class (abstract class ending in State)
      if (node.abstractKeyword != null && className.endsWith('State')) {
        stateHierarchy[className] = <ClassDeclaration>[];
      }

      // Check if this extends a state class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superclass = extendsClause.superclass.toSource();
        if (superclass.endsWith('State')) {
          stateHierarchy.putIfAbsent(superclass, () => <ClassDeclaration>[]);
          stateHierarchy[superclass]!.add(node);
        }
      }
    });

    // After processing, check for over-engineered hierarchies
    // Note: This runs per-file, so we check accumulated state
    for (final MapEntry<String, List<ClassDeclaration>> entry
        in stateHierarchy.entries) {
      if (entry.value.length > _maxStateSubclasses) {
        // Report on the first subclass as a hint
        reporter.atNode(entry.value.first, code);
      }
    }
  }
}
