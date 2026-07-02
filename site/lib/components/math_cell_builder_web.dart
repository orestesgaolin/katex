/// Web variant: constructs the real Flutter [MathCell] widget.
library;

import '../widgets/math_cell.dart';

dynamic mathCellWidget(
  String tex, {
  required bool displayMode,
  int heightPx = 0,
  String animation = 'none',
  int stepMillis = 0,
}) =>
    MathCell(
      tex: tex,
      displayMode: displayMode,
      heightPx: heightPx,
      animation: animation,
      stepMillis: stepMillis,
    );
