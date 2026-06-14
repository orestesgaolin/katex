/// Environment-registry machinery: a Dart port of KaTeX's
/// `defineEnvironment.ts` (parser-facing parts only; builders are T-011).
library;

import 'package:katex/src/ast/parse_node.dart';
import 'package:katex/src/functions/function_spec.dart' show ArgType;
import 'package:katex/src/parse/parser.dart';
import 'package:katex/src/types.dart';

/// Context provided to an [EnvHandler], mirroring KaTeX's `EnvContext`.
class EnvContext {
  /// Creates an environment context.
  const EnvContext({
    required this.mode,
    required this.envName,
    required this.parser,
  });

  /// The current parsing mode.
  final Mode mode;

  /// The environment name (one of the registered names).
  final String envName;

  /// The driving parser.
  final Parser parser;
}

/// An environment handler producing a [ParseNode] from `\begin{name}` args.
typedef EnvHandler =
    ParseNode Function(
      EnvContext context,
      List<ParseNode> args,
      List<ParseNode?> optArgs,
    );

/// Final environment spec, mirroring KaTeX's `EnvSpec`.
class EnvSpec {
  /// Creates an environment spec.
  const EnvSpec({
    required this.type,
    required this.numArgs,
    required this.handler,
    this.argTypes,
    this.allowedInText = false,
    this.numOptionalArgs = 0,
  });

  /// The node `type` string the handler produces.
  final String type;

  /// The number of mandatory arguments after `\begin{name}`.
  final int numArgs;

  /// The handler.
  final EnvHandler handler;

  /// Per-argument types, or `null`.
  final List<ArgType?>? argTypes;

  /// Whether the environment is allowed in text mode.
  final bool allowedInText;

  /// The number of optional arguments.
  final int numOptionalArgs;
}

/// The global environment registry, mirroring KaTeX's `_environments`.
final Map<String, EnvSpec> environments = <String, EnvSpec>{};

/// Register [spec] under each of [names]. Mirrors KaTeX's `defineEnvironment`.
void defineEnvironment(List<String> names, EnvSpec spec) {
  for (final name in names) {
    environments[name] = spec;
  }
}
