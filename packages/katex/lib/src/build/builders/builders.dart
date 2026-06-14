/// Registration barrel for the MVP per-group box builders.
///
/// Each builder ports the BOX-PRODUCING `htmlBuilder` of a KaTeX function/group
/// (from `reference/node_modules/katex/src/functions/*.ts` and `buildHTML.ts`),
/// emitting box-tree nodes. They are registered into the `groupBuilders` map by
/// [registerAll], mirroring KaTeX's `_htmlGroupBuilders`.
library;

import 'package:katex/src/build/build_expression.dart' show GroupBuilder;
import 'package:katex/src/build/builders/accent_builders.dart';
import 'package:katex/src/build/builders/array_builder.dart';
import 'package:katex/src/build/builders/delimiter_builders.dart';
import 'package:katex/src/build/builders/genfrac_builder.dart';
import 'package:katex/src/build/builders/op_builders.dart';
import 'package:katex/src/build/builders/sqrt_builder.dart';
import 'package:katex/src/build/builders/styling_builders.dart';
import 'package:katex/src/build/builders/supsub_builder.dart';
import 'package:katex/src/build/builders/symbol_builders.dart';

/// Registers every MVP builder into [registry] (keyed by node `type`).
void registerAll(Map<String, GroupBuilder> registry) {
  registerSymbolBuilders(registry);
  registerSupSubBuilder(registry);
  registerGenfracBuilder(registry);
  registerSqrtBuilder(registry);
  registerOpBuilders(registry);
  registerDelimiterBuilders(registry);
  registerAccentBuilders(registry);
  registerStylingBuilders(registry);
  registerArrayBuilder(registry);
}
