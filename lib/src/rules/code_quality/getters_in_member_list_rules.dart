// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';

import '../../analyzer_compat.dart';
import '../../saropa_lint_rule.dart';

// ============================================================================
// GETTER MEMBER-ORDERING RULE
// ============================================================================
//
// A class/mixin/extension body implicitly splits into a "what does this
// object look like" section (fields, getters, setters) and a "what does it
// do" section (constructors, methods). When a getter is declared after a
// regular method, a reader scanning for the object's data shape has to
// re-scan the whole body instead of stopping at the first method. This rule
// flags that specific case: a getter that trails at least one method, when
// there was an earlier field/getter/setter it could have been grouped with
// instead.
// ============================================================================

/// Flags a getter (`Type get name => ...`) declared after a regular method
/// in the same class, mixin, or extension body, when the body already has
/// an earlier field, getter, or setter the getter could have been grouped
/// with instead.
///
/// Since: v15.4.0 | Updated: v15.4.0 | Rule version: v1
///
/// Only plain (non-`@override`) getters are flagged. Overriding getters are
/// exempt: they are frequently kept next to other overridden members for
/// interface-conformance readability rather than grouped with the class's
/// own fields, and flagging them would fight that equally valid convention.
/// A getter with nothing earlier to group with (no prior field, getter, or
/// setter in the body) is never flagged — there is nothing to reorder
/// against. Constructors are not treated as a "behavior member" that trips
/// this rule: their position relative to getters is a separate convention
/// this rule does not enforce.
///
/// **BAD:**
/// ```dart
/// class Order {
///   final List<Item> items;
///
///   Order(this.items);
///
///   void addItem(Item item) {
///     items.add(item);
///   }
///
///   double get total => items.fold(0, (sum, i) => sum + i.price);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Order {
///   final List<Item> items;
///
///   double get total => items.fold(0, (sum, i) => sum + i.price);
///
///   Order(this.items);
///
///   void addItem(Item item) {
///     items.add(item);
///   }
/// }
/// ```
class GettersInMemberListRule extends SaropaLintRule {
  GettersInMemberListRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'convention', 'readability'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  String get exampleBad =>
      'void addItem() {}\n\ndouble get total => 0; // after a method';

  @override
  String get exampleGood => 'double get total => 0;\n\nvoid addItem() {}';

  static const LintCode _code = LintCode(
    'getters_in_member_list',
    '[getters_in_member_list] This getter is declared after at least one '
        'regular method, even though the class already has an earlier '
        'field, getter, or setter it could have been grouped with instead. '
        'Scattering getters among unrelated methods forces a reader who '
        'wants to know "what does this object look like" to scan the whole '
        'class body instead of stopping at the first method; keeping '
        'getters grouped with fields near the top keeps the data contract '
        'scannable independent of when each member was added. {v1}',
    correctionMessage:
        'Move this getter up next to the class\'s field declarations and '
        'other getters/setters, before the first method.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // `.bodyMembers` (lib/src/analyzer_compat.dart) rather than `.members`
    // directly — ClassDeclaration/MixinDeclaration/ExtensionDeclaration no
    // longer expose `.members` in analyzer 12 (members moved under
    // `.body`), and older pinned analyzer versions have their own quirks
    // the shim absorbs.
    context.addClassDeclaration(
      (ClassDeclaration node) => _checkMembers(reporter, node.bodyMembers),
    );
    context.addMixinDeclaration(
      (MixinDeclaration node) => _checkMembers(reporter, node.bodyMembers),
    );
    context.addExtensionDeclaration(
      (ExtensionDeclaration node) => _checkMembers(reporter, node.bodyMembers),
    );
  }

  /// Walks one class/mixin/extension body's member list in source order,
  /// flagging any plain getter that appears after a regular method AND has
  /// an earlier field/getter/setter it could have been grouped with.
  void _checkMembers(
    SaropaDiagnosticReporter reporter,
    List<ClassMember> members,
  ) {
    // True once a field, getter, or setter has been seen — the "data shape"
    // section a later getter could have joined instead of trailing a
    // method.
    var hasEarlierPropertyMember = false;
    // True once a regular (non-getter/setter) method has been seen — the
    // "behavior" section that should come after the data shape section.
    var sawBehaviorMember = false;

    for (final member in members) {
      if (member is FieldDeclaration) {
        hasEarlierPropertyMember = true;
        continue;
      }

      // Constructors are deliberately NOT treated as a "behavior member"
      // here: the proposal's own GOOD example places the constructor after
      // the getter, and the BAD example places it before an unrelated
      // method — only a *method* declaration breaks getter grouping, a
      // constructor's position is a separate convention this rule doesn't
      // enforce.
      if (member is ConstructorDeclaration) continue;

      if (member is! MethodDeclaration) continue;

      if (member.isGetter) {
        // Overriding getters are exempt (edge case: they are often kept
        // near other overrides rather than the field block).
        final isOverride = member.metadata.any(
          (Annotation a) => a.name.name == 'override',
        );
        if (sawBehaviorMember && hasEarlierPropertyMember && !isOverride) {
          reporter.atNode(member);
        }
        hasEarlierPropertyMember = true;
        continue;
      }

      if (member.isSetter) {
        hasEarlierPropertyMember = true;
        continue;
      }

      // Any other method declaration (regular method or operator) marks
      // the start/continuation of the behavior section.
      sawBehaviorMember = true;
    }
  }
}
