// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// device_calendar package lint rules.
///
/// Catch the common device_calendar footguns: data operations without a
/// permission check, discarded `Result`s, invalid `RetrieveEventsParams`,
/// events with no calendar id, and the Android UTC-timezone display bug.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// device_calendar plugin data operations (return `Future<Result<T>>`).
const Set<String> _dataOps = <String>{
  'retrieveCalendars',
  'retrieveEvents',
  'createOrUpdateEvent',
  'deleteEvent',
  'deleteEventInstance',
  'createCalendar',
  'deleteCalendar',
};

/// The two permission gate methods on DeviceCalendarPlugin.
const Set<String> _permissionMethods = <String>{
  'hasPermissions',
  'requestPermissions',
};

/// Result-inspection members; accessing any one counts as "checked".
const Set<String> _resultCheckMembers = <String>{
  'isSuccess',
  'hasErrors',
  'errors',
};

bool _isTestFilePath(String path) {
  final String normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('_test.dart') || normalized.contains('/test/');
}

Expression? _namedArg(InstanceCreationExpression node, String name) {
  for (final Expression arg in node.argumentList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) {
      return arg.expression;
    }
  }
  return null;
}

/// A named argument is "present and non-null" when supplied with a value that
/// is not the `null` literal.
bool _argProvided(InstanceCreationExpression node, String name) {
  final Expression? value = _namedArg(node, name);
  return value != null && value is! NullLiteral;
}

FunctionBody? _enclosingMemberBody(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is MethodDeclaration) return current.body;
    if (current is FunctionDeclaration) {
      return current.functionExpression.body;
    }
    if (current is ConstructorDeclaration) return current.body;
    current = current.parent;
  }
  return null;
}

/// Collects the AST nodes the flow rules reason over, in one traversal.
class _MemberScan extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> invocations = <MethodInvocation>[];
  final List<AssignmentExpression> assignments = <AssignmentExpression>[];
  final List<PrefixedIdentifier> prefixedIds = <PrefixedIdentifier>[];
  final List<PropertyAccess> propertyAccesses = <PropertyAccess>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    invocations.add(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    assignments.add(node);
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    prefixedIds.add(node);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    propertyAccesses.add(node);
    super.visitPropertyAccess(node);
  }

  /// True when [varName]'s member [member] is accessed anywhere in the scan
  /// (e.g. `result.isSuccess`).
  bool accessesMember(String varName, String member) {
    for (final PrefixedIdentifier id in prefixedIds) {
      if (id.prefix.name == varName && id.identifier.name == member) {
        return true;
      }
    }
    for (final PropertyAccess pa in propertyAccesses) {
      final Expression target = pa.target ?? pa.realTarget;
      if (target is SimpleIdentifier &&
          target.name == varName &&
          pa.propertyName.name == member) {
        return true;
      }
    }
    return false;
  }
}

// =============================================================================
// device_calendar_missing_permission_check
// =============================================================================

/// Flags device_calendar data operations in a file with no permission check.
///
/// Since: v4.16.0 | Rule version: v1
///
/// DeviceCalendarPlugin returns a failed `Result` (not an exception) on
/// permission denial, so an app that skips `hasPermissions()`/
/// `requestPermissions()` silently shows zero calendars on first install. INFO:
/// the iOS plist requirement is already covered by `require_ios_permission_*`,
/// and the check may live in a helper file (false positive).
///
/// **BAD:**
/// ```dart
/// await plugin.retrieveCalendars(); // no permission check in the file
/// ```
///
/// **GOOD:**
/// ```dart
/// if ((await plugin.hasPermissions()).data ?? false) {
///   await plugin.retrieveCalendars();
/// }
/// ```
class DeviceCalendarMissingPermissionCheckRule extends SaropaLintRule {
  DeviceCalendarMissingPermissionCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'device_calendar_missing_permission_check',
    '[device_calendar_missing_permission_check] This file calls device_calendar data operations but never calls hasPermissions() or requestPermissions(). DeviceCalendarPlugin returns a failed Result (it does not throw) when calendar permission is missing, so the app silently shows zero calendars or events on first install. Reported at INFO: the iOS Info.plist requirement is enforced separately, and the permission flow may legitimately live in a helper file. {v1}',
    correctionMessage:
        'Call hasPermissions() and, if needed, requestPermissions() before any retrieve/create/delete operation, and act on the returned Result.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
      if (!fileImportsPackage(unit, PackageImports.deviceCalendar)) return;
      if (_isTestFilePath(context.filePath)) return;

      final _MemberScan scan = _MemberScan();
      unit.accept(scan);

      final List<MethodInvocation> dataCalls = scan.invocations
          .where(
            (MethodInvocation inv) => _dataOps.contains(inv.methodName.name),
          )
          .toList();
      if (dataCalls.isEmpty) return;

      final bool hasPermissionCall = scan.invocations.any(
        (MethodInvocation inv) =>
            _permissionMethods.contains(inv.methodName.name),
      );
      if (hasPermissionCall) return;

      // Report once, at the first data operation, to avoid file-wide noise.
      reporter.atNode(dataCalls.first.methodName);
    });
  }
}

// =============================================================================
// device_calendar_unchecked_result
// =============================================================================

/// Flags a discarded `await` of a device_calendar data operation.
///
/// Since: v4.16.0 | Rule version: v1
///
/// Every operation returns `Result<T>`; awaiting it as a bare statement
/// swallows permission denials and platform errors silently. (The stored-but-
/// unchecked case is covered by `device_calendar_result_data_before_success_check`
/// when the result's `data` is read.)
///
/// **BAD:**
/// ```dart
/// await plugin.createOrUpdateEvent(event); // result discarded
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await plugin.createOrUpdateEvent(event);
/// if (!result.isSuccess) handleError(result.errors);
/// ```
class DeviceCalendarUncheckedResultRule extends SaropaLintRule {
  DeviceCalendarUncheckedResultRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'device_calendar_unchecked_result',
    '[device_calendar_unchecked_result] A device_calendar data operation is awaited as a bare statement, discarding its Result. Every DeviceCalendarPlugin method returns Result<T> carrying isSuccess/errors; discarding it silently swallows permission denials, platform exceptions, and invalid-argument errors, so the code proceeds as if the operation succeeded. {v1}',
    correctionMessage:
        'Assign the awaited Result and check isSuccess (or hasErrors/errors) before proceeding.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_dataOps.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.deviceCalendar)) return;
      if (_isTestFilePath(context.filePath)) return;

      // Discarded shape: `await plugin.op(...);` as its own statement. The await
      // is the expression of an ExpressionStatement, so its result is dropped.
      final AstNode? awaitNode = node.parent;
      if (awaitNode is! AwaitExpression) return;
      if (awaitNode.parent is! ExpressionStatement) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// device_calendar_retrieve_events_empty_params
// =============================================================================

/// Flags `RetrieveEventsParams()` with no date range and no event ids.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `retrieveEvents` needs either a `startDate`+`endDate` range or `eventIds`;
/// with all three null the plugin returns an `invalidArguments` error.
///
/// **BAD:**
/// ```dart
/// plugin.retrieveEvents(id, RetrieveEventsParams());
/// ```
///
/// **GOOD:**
/// ```dart
/// plugin.retrieveEvents(id, RetrieveEventsParams(startDate: a, endDate: b));
/// ```
class DeviceCalendarRetrieveEventsEmptyParamsRule extends SaropaLintRule {
  DeviceCalendarRetrieveEventsEmptyParamsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'RetrieveEventsParams'};

  static const LintCode _code = LintCode(
    'device_calendar_retrieve_events_empty_params',
    '[device_calendar_retrieve_events_empty_params] RetrieveEventsParams is constructed with no startDate, endDate, or eventIds (all absent or null) and passed to retrieveEvents. The plugin requires either a complete date range or a non-empty eventIds list; with none it returns an invalidArguments error and a null data, so the lookup is a guaranteed failure that the nullable-by-design params class never flags at construction. {v1}',
    correctionMessage:
        'Provide a startDate and endDate range, or an eventIds list, on RetrieveEventsParams.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.constructorName.type.name.lexeme != 'RetrieveEventsParams') {
        return;
      }
      if (!fileImportsPackage(node, PackageImports.deviceCalendar)) return;

      final bool anyProvided =
          _argProvided(node, 'startDate') ||
          _argProvided(node, 'endDate') ||
          _argProvided(node, 'eventIds');
      if (anyProvided) return;

      // Only when it is the direct argument to a retrieveEvents call.
      if (!_isDirectArgTo(node, 'retrieveEvents')) return;

      reporter.atNode(node);
    });
  }
}

/// True when [node] is a direct argument of a `<receiver>.<method>(...)` call.
bool _isDirectArgTo(Expression node, String method) {
  final AstNode? argList = node.parent;
  if (argList is! ArgumentList) return false;
  final AstNode? call = argList.parent;
  return call is MethodInvocation && call.methodName.name == method;
}

// =============================================================================
// device_calendar_retrieve_events_missing_end_date
// =============================================================================

/// Flags a `RetrieveEventsParams` with only one of `startDate`/`endDate`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// A half-specified range (only a start, or only an end) with no `eventIds` is
/// an invalid argument the plugin rejects.
///
/// **BAD:**
/// ```dart
/// RetrieveEventsParams(startDate: a); // no endDate, no eventIds
/// ```
///
/// **GOOD:**
/// ```dart
/// RetrieveEventsParams(startDate: a, endDate: b);
/// ```
class DeviceCalendarRetrieveEventsMissingEndDateRule extends SaropaLintRule {
  DeviceCalendarRetrieveEventsMissingEndDateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'RetrieveEventsParams'};

  static const LintCode _code = LintCode(
    'device_calendar_retrieve_events_missing_end_date',
    '[device_calendar_retrieve_events_missing_end_date] RetrieveEventsParams provides only one of startDate / endDate (and no eventIds). retrieveEvents requires both bounds of a date range to be non-null; a half-specified range produces an invalidArguments error and returns no events. This is the off-by-one that copy-pasting a date-range example commonly introduces. {v1}',
    correctionMessage:
        'Provide both startDate and endDate (or use eventIds instead of a date range).',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.constructorName.type.name.lexeme != 'RetrieveEventsParams') {
        return;
      }
      if (!fileImportsPackage(node, PackageImports.deviceCalendar)) return;

      final bool hasStart = _argProvided(node, 'startDate');
      final bool hasEnd = _argProvided(node, 'endDate');
      final bool hasIds = _argProvided(node, 'eventIds');

      // Exactly one bound, and not rescued by an eventIds path.
      if (hasStart == hasEnd) return;
      if (hasIds) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// device_calendar_event_missing_calendar_id
// =============================================================================

/// Flags an `Event` with no `calendarId` passed to `createOrUpdateEvent`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `createOrUpdateEvent` rejects an event whose `calendarId` is null/empty
/// ("New events must specify a calendar id"); the event is not persisted.
///
/// **BAD:**
/// ```dart
/// final e = Event(title: 'x'); // no calendarId
/// await plugin.createOrUpdateEvent(e);
/// ```
///
/// **GOOD:**
/// ```dart
/// final e = Event(calendarId, title: 'x');
/// await plugin.createOrUpdateEvent(e);
/// ```
class DeviceCalendarEventMissingCalendarIdRule extends SaropaLintRule {
  DeviceCalendarEventMissingCalendarIdRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'createOrUpdateEvent'};

  static const LintCode _code = LintCode(
    'device_calendar_event_missing_calendar_id',
    '[device_calendar_event_missing_calendar_id] An Event with no calendarId is passed to createOrUpdateEvent. The plugin validates that calendarId is non-null and non-empty for both new and existing events ("New events must specify a calendar id") and otherwise returns an invalidArguments error without persisting anything. Because Event.calendarId is a nullable, non-required constructor parameter, the omission is invisible until runtime. {v1}',
    correctionMessage:
        'Set calendarId on the Event (the id of the user-selected calendar) before passing it to createOrUpdateEvent.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.constructorName.type.name.lexeme != 'Event') return;
      if (!fileImportsPackage(node, PackageImports.deviceCalendar)) return;

      // calendarId may be the first positional arg or a named arg; only flag
      // when neither a positional value nor a non-null calendarId: is present.
      final bool hasPositional =
          node.argumentList.arguments.isNotEmpty &&
          node.argumentList.arguments.first is! NamedExpression &&
          node.argumentList.arguments.first is! NullLiteral;
      if (hasPositional) return;
      if (_argProvided(node, 'calendarId')) return;

      // Inline: createOrUpdateEvent(Event(...)).
      if (_isDirectArgTo(node, 'createOrUpdateEvent')) {
        reporter.atNode(node);
        return;
      }

      // Variable: final e = Event(...); ... createOrUpdateEvent(e); with no
      // intervening `e.calendarId = ...` assignment.
      final AstNode? decl = node.parent;
      if (decl is! VariableDeclaration) return;
      final String varName = decl.name.lexeme;

      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;
      final _MemberScan scan = _MemberScan();
      body.accept(scan);

      final bool passedToCreate = scan.invocations.any((MethodInvocation inv) {
        if (inv.methodName.name != 'createOrUpdateEvent') return false;
        final args = inv.argumentList.arguments;
        return args.isNotEmpty &&
            args.first is SimpleIdentifier &&
            (args.first as SimpleIdentifier).name == varName;
      });
      if (!passedToCreate) return;

      // A later calendarId setter rescues it — do not flag.
      final bool setsCalendarId = scan.assignments.any((
        AssignmentExpression a,
      ) {
        final Expression lhs = a.leftHandSide;
        return lhs is PrefixedIdentifier &&
            lhs.prefix.name == varName &&
            lhs.identifier.name == 'calendarId';
      });
      if (setsCalendarId) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// device_calendar_event_utc_timezone
// =============================================================================

/// Flags `TZDateTime.utc(...)` used as an `Event.start`/`end`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// A known Android bug writes the timezone display name (not the IANA id) to
/// EVENT_TIMEZONE; UTC happens to mask it, but the pattern shows events at the
/// wrong local time. Use `TZDateTime.from(dt, tz.local)`.
///
/// **BAD:**
/// ```dart
/// Event(calendarId, start: TZDateTime.utc(2026, 1, 1));
/// ```
///
/// **GOOD:**
/// ```dart
/// Event(calendarId, start: TZDateTime.from(dt, tz.local));
/// ```
class DeviceCalendarEventUtcTimezoneRule extends SaropaLintRule {
  DeviceCalendarEventUtcTimezoneRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'TZDateTime'};

  static const LintCode _code = LintCode(
    'device_calendar_event_utc_timezone',
    '[device_calendar_event_utc_timezone] TZDateTime.utc(...) is used as the start or end of a device_calendar Event. A known Android bug writes the timezone display name instead of the IANA id to EVENT_TIMEZONE; UTC masks the bug, but the pattern stores events that display at the wrong local time for users in non-UTC locales. Use TZDateTime.from(dateTime, tz.local) with the device timezone instead. {v1}',
    correctionMessage:
        'Use TZDateTime.from(dateTime, tz.local) (the device timezone) for Event.start / Event.end, not TZDateTime.utc.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (_isTestFilePath(context.filePath)) return;

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      // TZDateTime.utc(...) — named constructor `utc` on TZDateTime.
      if (node.constructorName.type.name.lexeme != 'TZDateTime') return;
      if (node.constructorName.name?.name != 'utc') return;
      if (!fileImportsPackage(node, PackageImports.deviceCalendar)) return;

      // Used as the start: or end: argument of an Event(...) construction.
      final AstNode? namedExpr = node.parent;
      if (namedExpr is! NamedExpression) return;
      final String label = namedExpr.name.label.name;
      if (label != 'start' && label != 'end') return;

      final AstNode? argList = namedExpr.parent;
      final AstNode? creation = argList?.parent;
      if (creation is! InstanceCreationExpression) return;
      if (creation.constructorName.type.name.lexeme != 'Event') return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// device_calendar_result_data_before_success_check
// =============================================================================

/// Flags `.data` read on a device_calendar `Result` with no `isSuccess` guard.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `Result.isSuccess` is `data != null && errors.isEmpty`; reading `.data`
/// (especially `.data!`) without checking `isSuccess` first can return a silent
/// null or a meaningless value from a failed operation.
///
/// **BAD:**
/// ```dart
/// final r = await plugin.retrieveCalendars();
/// use(r.data!); // no isSuccess check
/// ```
///
/// **GOOD:**
/// ```dart
/// final r = await plugin.retrieveCalendars();
/// if (r.isSuccess) use(r.data!);
/// ```
class DeviceCalendarResultDataBeforeSuccessCheckRule extends SaropaLintRule {
  DeviceCalendarResultDataBeforeSuccessCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'.data'};

  static const LintCode _code = LintCode(
    'device_calendar_result_data_before_success_check',
    '[device_calendar_result_data_before_success_check] A device_calendar Result\'s data is read in a member that never checks isSuccess (or hasErrors / errors) on the same result. Result.isSuccess is computed as data != null && errors.isEmpty, so reading .data — especially .data! — from an unchecked result can return a silent null or a stale value from a failed operation, masking the original error behind a later null dereference. {v1}',
    correctionMessage:
        'Guard the .data read with if (result.isSuccess) (or an early return on !isSuccess) before using it.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (_isTestFilePath(context.filePath)) return;

    // Operate per member so the isSuccess check is scoped to the same flow.
    context.addMethodInvocation((MethodInvocation node) {
      if (!_dataOps.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.deviceCalendar)) return;

      // The awaited result must be assigned to a local variable.
      final AstNode? awaitNode = node.parent;
      if (awaitNode is! AwaitExpression) return;
      final AstNode? maybeDecl = awaitNode.parent;
      if (maybeDecl is! VariableDeclaration) return;
      final String varName = maybeDecl.name.lexeme;

      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;
      final _MemberScan scan = _MemberScan();
      body.accept(scan);

      // If the member checks isSuccess/hasErrors/errors on this var, it's fine.
      final bool checked = _resultCheckMembers.any(
        (String m) => scan.accessesMember(varName, m),
      );
      if (checked) return;

      // Report each `.data` read on the unchecked result.
      bool reported = false;
      for (final PrefixedIdentifier id in scan.prefixedIds) {
        if (id.prefix.name == varName && id.identifier.name == 'data') {
          reporter.atNode(id);
          reported = true;
        }
      }
      if (reported) return;
      for (final PropertyAccess pa in scan.propertyAccesses) {
        final Expression target = pa.target ?? pa.realTarget;
        if (target is SimpleIdentifier &&
            target.name == varName &&
            pa.propertyName.name == 'data') {
          reporter.atNode(pa);
        }
      }
    });
  }
}

/// Warns when device_calendar Event doesn't specify time zone handling.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: calendar_timezone, device_calendar_timezone
///
/// Calendar events without explicit time zone handling may display at wrong
/// times when users travel or when syncing across devices.
///
/// **Note:** This rule specifically targets device_calendar package Events.
/// It requires both a positional calendarId AND start/end parameters to match,
/// reducing false positives from other Event classes.
///
/// **BAD:**
/// ```dart
/// final event = Event(
///   calendarId,
///   title: 'Meeting',
///   start: TZDateTime.now(local),
///   end: TZDateTime.now(local).add(Duration(hours: 1)),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final event = Event(
///   calendarId,
///   title: 'Meeting',
///   start: TZDateTime.now(local),
///   end: TZDateTime.now(local).add(Duration(hours: 1)),
///   timeZone: 'America/New_York', // or local.name
/// );
/// ```
class RequireCalendarTimezoneHandlingRule extends SaropaLintRule {
  RequireCalendarTimezoneHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_calendar_timezone_handling',
    '[require_calendar_timezone_handling] device_calendar Event is missing an explicit timeZone. This can cause events to appear at the wrong time for users in different time zones, leading to missed or misaligned appointments. {v2}',
    correctionMessage:
        'Add the timeZone parameter to device_calendar Event to ensure events are scheduled and displayed correctly across different time zones. This prevents confusion and missed appointments for users in other regions.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Event') return;

      final ArgumentList args = node.argumentList;

      // device_calendar Event requires a positional calendarId as first arg
      // This helps distinguish it from other Event classes
      final bool hasPositionalArg =
          args.arguments.isNotEmpty && args.arguments.first is! NamedExpression;
      if (!hasPositionalArg) return;

      // Must have both 'start' and 'end' named parameters (device_calendar pattern)
      bool hasStart = false;
      bool hasEnd = false;
      bool hasTimeZone = false;

      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'start') hasStart = true;
          if (name == 'end') hasEnd = true;
          if (name == 'timeZone') hasTimeZone = true;
        }
      }

      // Only flag if it looks like a device_calendar Event (has start AND end)
      if (!hasStart || !hasEnd) return;

      if (!hasTimeZone) {
        reporter.atNode(node);
      }
    });
  }
}
