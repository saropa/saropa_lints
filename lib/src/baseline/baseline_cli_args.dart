/// Argument helpers for the `baseline` CLI (`bin/baseline.dart`), kept in
/// `lib/` so they are unit-tested; `bin/` entry points are not importable.
library;

/// Options that consume the following argument as their value.
const Set<String> _valueOptions = <String>{'--output', '-o', '--explain'};

/// The project directory named by [args]: the first argument that is not an
/// option and not the value of `--output` / `-o` / `--explain`. Defaults
/// to `.`.
///
/// Why an index walk: the previous loop compared `args.indexOf(arg)` with
/// `outputIndex + 1`, and with no `-o` given that index is `-1 + 1 == 0`, so
/// argument 0 was always excluded and `baseline ./my_project` silently ran
/// on the current directory. `indexOf` also returned the first occurrence
/// only, which misjudged a path equal to an earlier argument.
String baselineWorkingDir(List<String> args) {
  for (int i = 0; i < args.length; i++) {
    final String arg = args[i];
    if (_valueOptions.contains(arg)) {
      // Skip the option's value along with the option.
      i++;
      continue;
    }
    if (!arg.startsWith('-')) return arg;
  }
  return '.';
}
