// ignore_for_file: always_specify_types, avoid_catching_generic_exception

/// Project-wide context and caches for saropa_lints rules.
///
/// **Purpose:** Avoid redundant I/O and parsing. Package detection, file type,
/// and content filters are computed once per project/file and reused. Rules
/// call [ProjectContext.of(context)] to get the singleton; all heavy data
/// (pubspec deps, path normalization, bloom filters, etc.) lives here.
library;

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

part 'project_context_path_bloom_git.dart';
part 'project_context_project_file.dart';
part 'project_context_pattern_metrics.dart';
part 'project_context_incremental_priority.dart';
part 'project_context_ast_violations.dart';
part 'project_context_parallel_batch.dart';
part 'project_context_dispatch_baseline.dart';
part 'project_context_import_location.dart';
part 'project_context_semantic_compilation.dart';
part 'project_context_throttle_memory.dart';
