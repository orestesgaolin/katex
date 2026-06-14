/// Scoped storage for nameable things (macros, lengths) with a TeX-style
/// `begingroup`/`endgroup` undo stack.
///
/// Port of KaTeX's `Namespace.ts`.
library;

import 'package:katex/src/parse/parse_error.dart';

/// A mapping from names to values, mirroring KaTeX's `Mapping<Value>`
/// (`Record<string, Value>`).
typedef Mapping<Value> = Map<String, Value>;

/// A `Namespace` refers to a space of nameable things like macros or lengths,
/// which can be [set] either globally or local to a nested group, using an
/// undo stack similar to how TeX implements this functionality.
///
/// Performance-wise, [get] and local [set] take constant time, while global
/// [set] takes time proportional to the depth of group nesting.
class Namespace<Value> {
  /// Creates a namespace.
  ///
  /// [builtins] is a map of built-in mappings which never change.
  /// [globalMacros] is a map of initial (global-level) mappings, which will
  /// constantly change according to any global/top-level [set]s done. Both are
  /// optional.
  Namespace([Mapping<Value>? builtins, Mapping<Value>? globalMacros])
    : builtins = builtins ?? <String, Value>{},
      current = globalMacros ?? <String, Value>{},
      undefStack = <Mapping<Value?>>[];

  /// The current (global-level) mappings, mutated by top-level [set]s.
  Mapping<Value> current;

  /// The built-in mappings, which never change.
  Mapping<Value> builtins;

  /// The undo stack: one entry per active nested group. Each entry records the
  /// values to restore in [current] when that group ends. A `null` value means
  /// the name should be deleted (it had no prior definition).
  List<Mapping<Value?>> undefStack;

  /// Start a new nested group, affecting future local [set]s.
  void beginGroup() {
    undefStack.add(<String, Value?>{});
  }

  /// End current nested group, restoring values before the group began.
  void endGroup() {
    if (undefStack.isEmpty) {
      throw ParseError(
        'Unbalanced namespace destruction: attempt to pop global '
        'namespace; please report this as a bug',
      );
    }
    final undefs = undefStack.removeLast();
    for (final entry in undefs.entries) {
      final value = entry.value;
      if (value == null) {
        current.remove(entry.key);
      } else {
        current[entry.key] = value;
      }
    }
  }

  /// Ends all currently nested groups (if any), restoring values before the
  /// groups began. Useful in case of an error in the middle of parsing.
  void endGroups() {
    while (undefStack.isNotEmpty) {
      endGroup();
    }
  }

  /// Detect whether [name] has a definition. Equivalent to
  /// `get(name) != null`.
  bool has(String name) =>
      current.containsKey(name) || builtins.containsKey(name);

  /// Get the current value of [name], or `null` if there is no value.
  ///
  /// Note: Because Dart maps cannot store a `null` value distinct from "absent"
  /// here, this faithfully mirrors KaTeX where a missing definition is
  /// `undefined`. Use [has] to detect whether a macro is defined.
  Value? get(String name) {
    if (current.containsKey(name)) {
      return current[name];
    } else {
      return builtins[name];
    }
  }

  /// Set the current value of [name], and optionally set it globally too.
  ///
  /// Local `set` sets the current value and (when appropriate) adds an undo
  /// operation to the undo stack. Global `set` may change the undo operation at
  /// every level, so takes time linear in their number. A [value] of `null`
  /// means to delete existing definitions.
  void set(String name, Value? value, {bool global = false}) {
    if (global) {
      // Global set is equivalent to setting in all groups. Simulate this by
      // destroying any undos currently scheduled for this name, and adding an
      // undo with the *new* value (in case it later gets locally reset within
      // this environment).
      for (var i = 0; i < undefStack.length; i++) {
        undefStack[i].remove(name);
      }
      if (undefStack.isNotEmpty) {
        undefStack[undefStack.length - 1][name] = value;
      }
    } else {
      // Undo this set at end of this group (possibly to `null`), unless an undo
      // is already in place, in which case that older value is the correct one.
      if (undefStack.isNotEmpty) {
        final top = undefStack[undefStack.length - 1];
        if (!top.containsKey(name)) {
          top[name] = current[name];
        }
      }
    }
    if (value == null) {
      current.remove(name);
    } else {
      current[name] = value;
    }
  }
}
