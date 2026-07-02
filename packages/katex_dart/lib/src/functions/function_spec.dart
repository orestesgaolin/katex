/// Function-registry machinery: a Dart port of KaTeX's `defineFunction.ts`
/// (the parser-facing parts; HTML/MathML builders are T-011, not here).
library;

import 'package:katex_dart/src/ast/parse_node.dart';
import 'package:katex_dart/src/parse/parser.dart';
import 'package:katex_dart/src/parse/token.dart';

/// A LaTeX argument type, mirroring KaTeX's `ArgType`.
///
/// `original` is represented by `null` in [FunctionSpec.argTypes] (matching
/// KaTeX, where an absent entry means "same mode as the surrounding context").
enum ArgType {
  /// A size-like value such as `1em`.
  size,

  /// An HTML color.
  color,

  /// A URL string.
  url,

  /// A raw string (single char / percent / nested braces).
  raw,

  /// Wraps the argument like `\hbox` (text mode + `\textstyle`).
  hbox,

  /// A primitive grouped argument.
  primitive,

  /// A group parsed in math mode.
  math,

  /// A group parsed in text mode.
  text,
}

/// Context provided to a [FunctionHandler], mirroring KaTeX's
/// `FunctionContext`.
class FunctionContext {
  /// Creates a function context.
  const FunctionContext({
    required this.funcName,
    required this.parser,
    this.token,
    this.breakOnTokenText,
  });

  /// The control-sequence name being handled (e.g. `\frac`).
  final String funcName;

  /// The driving parser.
  final Parser parser;

  /// The token that triggered the function, for error reporting.
  final Token? token;

  /// The token text the surrounding expression should break on, or `null`.
  final String? breakOnTokenText;
}

/// A function handler: produces a [ParseNode] from the parsed arguments.
/// Mirrors KaTeX's `FunctionHandler`.
typedef FunctionHandler =
    ParseNode Function(
      FunctionContext context,
      List<ParseNode> args,
      List<ParseNode?> optArgs,
    );

/// Parser-facing function specification, mirroring KaTeX's `FunctionSpec`.
class FunctionSpec {
  /// Creates a function spec. Defaults follow KaTeX's documented behavior.
  const FunctionSpec({
    required this.type,
    required this.numArgs,
    this.handler,
    this.argTypes,
    this.allowedInArgument = false,
    this.allowedInText = false,
    this.allowedInMath = true,
    this.numOptionalArgs = 0,
    this.infix = false,
    this.primitive = false,
  });

  /// The node `type` string the handler produces.
  final String type;

  /// The number of mandatory arguments.
  final int numArgs;

  /// The handler, or `null` if handled directly in the Parser.
  final FunctionHandler? handler;

  /// Per-argument types (length `numOptionalArgs + numArgs`); a `null` entry
  /// means `original` (same mode as the context).
  final List<ArgType?>? argTypes;

  /// Whether the function may be used as a primitive argument.
  final bool allowedInArgument;

  /// Whether the function is allowed in text mode.
  final bool allowedInText;

  /// Whether the function is allowed in math mode.
  final bool allowedInMath;

  /// The number of optional arguments.
  final int numOptionalArgs;

  /// Whether the function is an infix operator.
  final bool infix;

  /// Whether the function is a TeX primitive.
  final bool primitive;
}

/// The global function registry, mirroring KaTeX's `_functions`.
final Map<String, FunctionSpec> functions = <String, FunctionSpec>{};

/// Register [spec] under each of [names]. Mirrors KaTeX's `defineFunction`
/// (builder registration is deferred to T-011).
void defineFunction(List<String> names, FunctionSpec spec) {
  for (final name in names) {
    functions[name] = spec;
  }
}

/// If [arg] is an ordgroup of exactly one node, return that node; otherwise
/// return [arg]. Mirrors KaTeX's `normalizeArgument`.
ParseNode normalizeArgument(ParseNode arg) =>
    arg is OrdGroupNode && arg.body.length == 1 ? arg.body[0] : arg;

/// If [arg] is an ordgroup, return its body; otherwise wrap [arg] in a list.
/// Mirrors KaTeX's `ordargument`.
List<ParseNode> ordargument(ParseNode arg) =>
    arg is OrdGroupNode ? arg.body : <ParseNode>[arg];
