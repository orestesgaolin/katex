/// The comprehensive comparison example set, grouped by category.
///
/// Shared between the server (Dart-SVG pre-render + KaTeX-JS markup) and the
/// Flutter host gallery. Extends `reference/gallery.json` to cover every
/// category called for in T-024 (fractions, scripts, roots, big operators,
/// delimiters, accents, fonts, colors/sizing, text/spacing, environments and
/// several real-world formulas).
library;

/// A single comparison example.
class Example {
  const Example(
    this.id,
    this.tex, {
    this.displayMode = false,
    this.approx = false,
    this.note,
  });

  /// Stable id (used for DOM hooks and Flutter row alignment).
  final String id;

  /// The LaTeX math source.
  final String tex;

  /// Whether to typeset as display math.
  final bool displayMode;

  /// Whether this expression hits a known MVP approximation (e.g. some
  /// stretchy delimiters) so an expected JS-vs-Dart difference is labelled,
  /// not read as a bug. Note: accents and `\sqrt[n]` are NOT approx — they
  /// were fixed and should match.
  final bool approx;

  /// Optional human note shown beside the [approx] badge.
  final String? note;
}

/// A named group of examples.
class ExampleGroup {
  const ExampleGroup(this.title, this.examples);

  /// Category heading.
  final String title;

  /// Examples in this category.
  final List<Example> examples;
}

/// All comparison groups, in display order.
const List<ExampleGroup> kGroups = <ExampleGroup>[
  ExampleGroup('Fractions', <Example>[
    Example('frac-a-b', r'\frac{a}{b}', displayMode: true),
    Example('dfrac', r'\dfrac{a}{b}', displayMode: true),
    Example('tfrac', r'\tfrac{a}{b}', displayMode: true),
    Example('binom', r'\binom{n}{k}', displayMode: true),
    Example(
      'cfrac',
      r'\cfrac{1}{1+\cfrac{1}{1+x}}',
      displayMode: true,
    ),
    Example(
      'nested-frac',
      r'\frac{1}{1+\frac{1}{x}}',
      displayMode: true,
    ),
  ]),
  ExampleGroup('Scripts', <Example>[
    Example('sup-x-2', r'x^2'),
    Example('sub-x-i', r'x_i'),
    Example('supsub-x-2-i', r'x^2_i'),
    Example('prescript', r'{}^{n}C_k'),
    Example('multilevel', r'x^{y^{z}}'),
    Example('primes', r"f''(x) + f'(x)"),
  ]),
  ExampleGroup('Roots', <Example>[
    Example('sqrt-x', r'\sqrt{x}'),
    Example('sqrt-index-3-x', r'\sqrt[3]{x}'),
    Example('nested-radical', r'\sqrt{1+\sqrt{1+x}}', displayMode: true),
  ]),
  ExampleGroup('Big operators', <Example>[
    Example('sum-limits', r'\sum_{i=0}^n i', displayMode: true),
    Example('sum-inline', r'\sum_{i=0}^n i'),
    Example('int-limits', r'\int_0^1 x^2 dx', displayMode: true),
    Example('prod', r'\prod_{i=1}^n i', displayMode: true),
    Example(
      'oint',
      r'\oint_C \vec{F}\cdot d\vec{r}',
      displayMode: true,
      approx: true,
      note: 'stretchy/large \\oint glyph (MVP)',
    ),
    Example(
      'bigcup',
      r'\bigcup_{i=1}^n A_i',
      displayMode: true,
    ),
  ]),
  ExampleGroup('Delimiters', <Example>[
    Example('left-right-frac', r'\left(\frac{a}{b}\right)', displayMode: true),
    Example('left-bracket', r'\left[\frac{a}{b}\right]', displayMode: true),
    Example(
      'left-brace',
      r'\left\{\frac{a}{b}\right\}',
      displayMode: true,
    ),
    Example('langle', r'\langle x, y \rangle'),
    Example('lceil', r'\lceil x \rceil + \lfloor y \rfloor'),
    Example(
      'sized-delims',
      r'\bigl( \Bigl[ \biggl\{ \Biggl\langle x \Biggr\rangle \biggr\} \Bigr] \bigr)',
      displayMode: true,
      approx: true,
      note: 'manual \\bigl..\\Biggr sizing (MVP)',
    ),
  ]),
  ExampleGroup('Accents', <Example>[
    Example('accent-hat-x', r'\hat{x}'),
    Example('accent-bar-x', r'\bar{x}'),
    Example('accent-vec-x', r'\vec{x}'),
    Example('accent-tilde-x', r'\tilde{x}'),
    Example('widehat', r'\widehat{xyz}'),
    Example('widetilde', r'\widetilde{xyz}'),
    Example('overline-x', r'\overline{x+y}'),
    Example('underline-x', r'\underline{x+y}'),
    Example(
      'overrightarrow',
      r'\overrightarrow{AB}',
      approx: true,
      note: 'stretchy arrow accent (MVP)',
    ),
  ]),
  ExampleGroup('Fonts', <Example>[
    Example('mathbf', r'\mathbf{Abc}'),
    Example('mathrm', r'\mathrm{Abc}'),
    Example('mathit', r'\mathit{Abc}'),
    Example('mathbb', r'\mathbb{RNZQC}'),
    Example('mathcal', r'\mathcal{ABCL}'),
    Example('mathfrak', r'\mathfrak{ABCabc}'),
    Example('mathsf', r'\mathsf{Abc}'),
    Example('mathtt', r'\mathtt{Abc}'),
    Example('boldsymbol', r'\boldsymbol{\alpha\beta\gamma}'),
  ]),
  ExampleGroup('Colors, sizing & styling', <Example>[
    Example('color', r'\color{red}{x} + \color{blue}{y}'),
    Example('textcolor', r'\textcolor{green}{a+b}'),
    Example('displaystyle', r'\displaystyle\sum_{i=0}^n i'),
    Example('scriptstyle', r'x + \scriptstyle y + z'),
    Example('large', r'\Large x \normalsize + \small y'),
  ]),
  ExampleGroup('Text & spacing', <Example>[
    Example('text', r'\text{if } x > 0 \text{ then } y'),
    Example(
      'thin-space',
      r'a\,b\;c\quad d\qquad e',
      approx: true,
      note: r'\, and \; thin-spaces unimplemented (MVP); \quad/\qquad OK',
    ),
    Example('greek-alpha-beta', r'\alpha + \beta + \gamma'),
    Example('cdot', r'a \cdot b \times c'),
  ]),
  ExampleGroup('Environments', <Example>[
    Example(
      'matrix',
      r'\begin{matrix} a & b \\ c & d \end{matrix}',
      displayMode: true,
    ),
    Example(
      'pmatrix',
      r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}',
      displayMode: true,
    ),
    Example(
      'bmatrix',
      r'\begin{bmatrix} a & b \\ c & d \end{bmatrix}',
      displayMode: true,
    ),
    Example(
      'Bmatrix',
      r'\begin{Bmatrix} a & b \\ c & d \end{Bmatrix}',
      displayMode: true,
    ),
    Example(
      'vmatrix',
      r'\begin{vmatrix} a & b \\ c & d \end{vmatrix}',
      displayMode: true,
    ),
    Example(
      'aligned',
      r'\begin{aligned} a &= b + c \\ d &= e \end{aligned}',
      displayMode: true,
    ),
    Example(
      'cases',
      r'f(x) = \begin{cases} 1 & x > 0 \\ 0 & x \le 0 \end{cases}',
      displayMode: true,
    ),
    Example(
      'array',
      r'\begin{array}{c|c} a & b \\ \hline c & d \end{array}',
      displayMode: true,
      approx: true,
      note: 'array rules/alignment (MVP)',
    ),
  ]),
  ExampleGroup('Real-world formulas', <Example>[
    Example(
      'quadratic',
      r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}',
      displayMode: true,
    ),
    Example('euler', r'e^{i\pi} + 1 = 0', displayMode: true),
    Example(
      'maxwell',
      r'\nabla \times \vec{B} = \mu_0 \vec{J} + \mu_0 \varepsilon_0 \frac{\partial \vec{E}}{\partial t}',
      displayMode: true,
    ),
    Example(
      'gaussian-cdf',
      r'\Phi(x) = \frac{1}{\sqrt{2\pi}} \int_{-\infty}^x e^{-t^2/2}\,dt',
      displayMode: true,
      approx: true,
      note: r'uses \, thin-space (unimplemented in MVP); rest matches',
    ),
    Example(
      'sum-identity',
      r'\sum_{k=0}^n \binom{n}{k} = 2^n',
      displayMode: true,
    ),
    Example(
      'continued-fraction',
      r'\phi = 1 + \cfrac{1}{1 + \cfrac{1}{1 + \cfrac{1}{1 + \cdots}}}',
      displayMode: true,
    ),
  ]),
];

/// Flat view of every example (in group order).
List<Example> get kAllExamples =>
    kGroups.expand((ExampleGroup g) => g.examples).toList();
