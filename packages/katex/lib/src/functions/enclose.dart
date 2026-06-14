/// Parser handlers for KaTeX's `enclose` group, ported from
/// `reference/node_modules/katex/src/functions/enclose.ts` (pinned KaTeX
/// 0.17.0): `\colorbox`, `\fcolorbox`, `\fbox`, `\cancel`, `\bcancel`,
/// `\xcancel`, `\sout`, `\angl`.
///
/// `\boxed` and `\angln` are macros (registered in `parse/macros.dart`, not
/// touched here) expanding to `\fbox{$\displaystyle{...}$}` and `{\angl n}`,
/// so they route through these handlers. `\phase` (also in `enclose.ts`) draws
/// a Steinmetz phasor angle; its geometry lives in the builder.
///
/// The box-producing builder lives in `build/builders/enclose_builder.dart`.
library;

import 'package:katex/src/ast/parse_node.dart';
import 'package:katex/src/functions/function_spec.dart';
import 'package:katex/src/parse/parse_error.dart';
import 'package:katex/src/types.dart' show Mode;

ColorTokenNode _assertColorToken(ParseNode node) {
  if (node is ColorTokenNode) {
    return node;
  }
  throw ParseError('Expected node of type color-token, but got ${node.type}');
}

/// Registers the enclose-group function handlers.
void registerEnclose() {
  // \colorbox{color}{body} — background fill.
  defineFunction(
    <String>[r'\colorbox'],
    FunctionSpec(
      type: 'enclose',
      numArgs: 2,
      allowedInText: true,
      argTypes: const <ArgType?>[ArgType.color, ArgType.hbox],
      handler: (context, args, optArgs) {
        final color = _assertColorToken(args[0]).color;
        return EncloseParseNode(
          mode: context.parser.mode,
          label: context.funcName,
          backgroundColor: color,
          body: args[1],
        );
      },
    ),
  );

  // \fcolorbox{frameColor}{bgColor}{body} — frame + background fill.
  defineFunction(
    <String>[r'\fcolorbox'],
    FunctionSpec(
      type: 'enclose',
      numArgs: 3,
      allowedInText: true,
      argTypes: const <ArgType?>[ArgType.color, ArgType.color, ArgType.hbox],
      handler: (context, args, optArgs) {
        final borderColor = _assertColorToken(args[0]).color;
        final backgroundColor = _assertColorToken(args[1]).color;
        return EncloseParseNode(
          mode: context.parser.mode,
          label: context.funcName,
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          body: args[2],
        );
      },
    ),
  );

  // \fbox{body} — text-mode framed box.
  defineFunction(
    <String>[r'\fbox'],
    FunctionSpec(
      type: 'enclose',
      numArgs: 1,
      allowedInText: true,
      argTypes: const <ArgType?>[ArgType.hbox],
      handler: (context, args, optArgs) {
        return EncloseParseNode(
          mode: context.parser.mode,
          label: r'\fbox',
          body: args[0],
        );
      },
    ),
  );

  // \cancel \bcancel \xcancel \phase — strike-through(s) + the phasor angle.
  defineFunction(
    <String>[r'\cancel', r'\bcancel', r'\xcancel', r'\phase'],
    FunctionSpec(
      type: 'enclose',
      numArgs: 1,
      handler: (context, args, optArgs) {
        return EncloseParseNode(
          mode: context.parser.mode,
          label: context.funcName,
          body: args[0],
        );
      },
    ),
  );

  // \sout — horizontal strike-through (text mode in LaTeX).
  defineFunction(
    <String>[r'\sout'],
    FunctionSpec(
      type: 'enclose',
      numArgs: 1,
      allowedInText: true,
      handler: (context, args, optArgs) {
        if (context.parser.mode == Mode.math) {
          context.parser.settings.reportNonstrict(
            'mathVsSout',
            r"LaTeX's \sout works only in text mode",
          );
        }
        return EncloseParseNode(
          mode: context.parser.mode,
          label: context.funcName,
          body: args[0],
        );
      },
    ),
  );

  // \angl — actuarial angle (top + right border).
  defineFunction(
    <String>[r'\angl'],
    FunctionSpec(
      type: 'enclose',
      numArgs: 1,
      argTypes: const <ArgType?>[ArgType.hbox],
      handler: (context, args, optArgs) {
        return EncloseParseNode(
          mode: context.parser.mode,
          label: r'\angl',
          body: args[0],
        );
      },
    ),
  );
}
