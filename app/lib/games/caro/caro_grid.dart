import 'package:material_ui/material_ui.dart';

import '../../core/neuro_theme.dart';
import 'caro_board.dart';

class CaroGrid extends StatelessWidget {
  const CaroGrid({
    required this.board,
    this.lastMove,
    this.winningLine = const [],
    this.selected,
    this.onTap,
    super.key,
  });

  final CaroBoard board;
  final int? lastMove;
  final List<int> winningLine;
  final int? selected;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(border: Border.all(color: NeuroTheme.group)),
      child: GridView.builder(
        primary: false,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: CaroBoard.size,
        ),
        itemCount: CaroBoard.cellCount,
        itemBuilder: (context, index) {
          final mark = board.cells[index];
          final last = index == lastMove;
          final winning = winningLine.contains(index);
          final focused = index == selected;
          final description = [
            caroCoordinates(index),
            mark?.label ?? 'ô trống',
            if (focused) 'đang chọn',
            if (last) 'nước cuối',
            if (winning) 'chuỗi thắng',
          ].join(', ');
          final action = onTap;
          final tap = action == null || (mark != null && selected == null)
              ? null
              : () => action(index);
          return Semantics(
            label: description,
            selected: selected == null ? null : focused,
            button: tap != null,
            onTap: tap,
            excludeSemantics: true,
            child: Material(
              color: winning
                  ? NeuroTheme.successFill
                  : focused
                  ? NeuroTheme.selected
                  : NeuroTheme.board,
              child: InkWell(
                onTap: tap,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      right: index % CaroBoard.size == CaroBoard.size - 1
                          ? BorderSide.none
                          : const BorderSide(color: NeuroTheme.grid),
                      bottom: index ~/ CaroBoard.size == CaroBoard.size - 1
                          ? BorderSide.none
                          : const BorderSide(color: NeuroTheme.grid),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(1.5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: focused || last || winning
                            ? Border.all(
                                color: focused
                                    ? NeuroTheme.primary
                                    : winning
                                    ? NeuroTheme.success
                                    : NeuroTheme.caro,
                                width: focused || winning ? 2 : 1.5,
                              )
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: mark == null
                            ? const SizedBox.expand()
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Icon(
                                  mark == CaroMark.x
                                      ? Icons.close
                                      : Icons.circle_outlined,
                                  size: 23,
                                  color: mark == CaroMark.x
                                      ? NeuroTheme.ink
                                      : NeuroTheme.caro,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

String caroCoordinates(int index) =>
    'Hàng ${index ~/ CaroBoard.size + 1}, cột ${index % CaroBoard.size + 1}';
