/// Web variant: constructs the real Flutter [MathCell] widget.
library;

import '../widgets/math_cell.dart';

dynamic mathCellWidget(String tex, {required bool displayMode}) =>
    MathCell(tex: tex, displayMode: displayMode);
