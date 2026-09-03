// ignore_for_file: unused_element

/// Fixture for `todo_with_story_links`.
///
/// BAD cases: `// TODO`/`// FIXME` comments with no issue-tracker reference.
/// GOOD cases: comments that include a URL, `#123`, or `PROJ-123`-shaped
/// ticket ID, plus near-miss cases (doc comments, block comments) that must
/// not be flagged even without a reference.
library;

// expect_lint: todo_with_story_links
// TODO(alice): clean this up later
void legacyMigration() {}

// expect_lint: todo_with_story_links
// TODO fix this without any author or reference
void noAuthorNoReference() {}

// expect_lint: todo_with_story_links
// FIXME(carol): this workaround needs revisiting
void untrackedFixme() {}

// GOOD — ticket-prefix reference present.
// TODO(bob): remove after PROJ-4821 ships
void trackedWithTicketPrefix() {}

// GOOD — GitHub short-reference present.
// TODO(dave): revisit once #512 is resolved
void trackedWithHashReference() {}

// GOOD — full URL reference present.
// FIXME(erin): https://github.com/saropa/app/issues/512
void trackedWithUrlReference() {}

// GOOD — doc comments are out of scope for this rule (format-only markers
// like `prefer_todo_format` cover `///`, this rule only inspects `//`).
/// TODO: this is a dartdoc line, not a `//` marker, and must not be flagged.
void docCommentTodoIsIgnored() {}

// GOOD — an ordinary comment that happens to mention neither TODO nor
// FIXME is never in scope.
// Just a regular explanatory comment with a URL: https://example.com
void ordinaryCommentIsIgnored() {}
