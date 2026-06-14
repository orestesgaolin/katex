/// Shared cross-cutting types for the KaTeX port.
///
/// Keeping the canonical [Mode] here avoids duplicate, ambiguous definitions
/// across the `font/` and `symbols/` layers (both of which re-export it).
library;

/// The TeX mode an expression/symbol/glyph is processed in, mirroring KaTeX's
/// `Mode` type. KaTeX keys its symbol map by mode (`symbols[mode][name]`) and
/// threads mode through parsing, building, and font-metric lookup.
enum Mode {
  /// Math mode (between `$...$`, `\(...\)`, display math, etc.).
  math,

  /// Text mode (inside `\text{...}`, `\hbox{...}`, etc.).
  text,
}
