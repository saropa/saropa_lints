# Dart SDK 3.1.5

## 3.1.5

- 2023-10-25

This is a patch release that:

- Fixes an issue affecting Dart compiled to JavaScript running in Node.js 21. A
  change in Node.js 21 affected the Dart Web compiler runtime. This patch
  release accommodates for those changes (issue #53810).

[#53810]: https://github.com/dart-lang/sdk/issues/53810
