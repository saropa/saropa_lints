#!/usr/bin/env dart

/// CLI tool to generate analysis_options.yaml with explicit rule
/// configuration for the native analyzer plugin system.
///
/// Usage: `dart run saropa_lints:init [options]`
///
/// Run `dart run saropa_lints:init --help` for full usage information.
library;

import 'package:saropa_lints/src/init/init_runner.dart';

/// Entry point — delegates to [runInit].
Future<void> main(List<String> args) => runInit(args);
