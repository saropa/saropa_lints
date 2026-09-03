// ignore_for_file: unused_local_variable

/// Fixture for `start_comments_with_space` lint rule.
///
/// BAD cases have a `//` line comment with no space before the text.
/// GOOD cases are properly spaced, or are exempt kinds (`///` doc comments,
/// `//!` comments, `// ignore:` directives) that this rule intentionally
/// does not touch.

void process() {
  //this comment has no space after the slashes // LINT: start_comments_with_space
  final int x = 1;

  // OK — space after the slashes
  final int y = 2;

  //  OK — more than one space is still spaced
  final int z = 3;

  final int total = x + y + z;
  print(total);
}

//!banged comments are exempt from this rule regardless of spacing
void bangComment() {}

/// Doc comments are a different token kind and are never checked by this
/// rule, regardless of spacing after the slashes.
///no space here either, but `///` is exempt
void documented() {}

void ignoreDirectives() {
  //ignore:unused_local_variable
  // The line above has no space after `//`, but it starts with the
  // `ignore:` directive prefix, which is owned by the more specific
  // require_ignore_comment_spacing rule — not flagged here.
  final int a = 1;
  print(a);
}
