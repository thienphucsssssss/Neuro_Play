import 'package:material_ui/material_ui.dart';

import '../core/neuro_theme.dart';
import 'sudoku_board.dart';

class SudokuGrid extends StatelessWidget {
  const SudokuGrid({
    required this.board,
    required this.onSelect,
    this.hint,
    this.lastCorrect,
    this.enlarged = false,
    super.key,
  });

  final SudokuBoard board;
  final ValueChanged<int>? onSelect;
  final int? hint;
  final int? lastCorrect;
  final bool enlarged;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        primary: false,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 9,
        ),
        itemCount: 81,
        itemBuilder: (context, index) => _SudokuCell(
          key: ValueKey('${enlarged ? 'enlarged' : 'sudoku'}-cell-$index'),
          board: board,
          index: index,
          hinted: hint == index,
          correct: lastCorrect == index,
          compact: constraints.maxWidth < 400,
          enlarged: enlarged,
          onSelect: onSelect == null ? null : () => onSelect!(index),
        ),
      ),
    ),
  );
}

class _SudokuCell extends StatefulWidget {
  const _SudokuCell({
    required super.key,
    required this.board,
    required this.index,
    required this.hinted,
    required this.correct,
    required this.compact,
    required this.enlarged,
    required this.onSelect,
  });

  final SudokuBoard board;
  final int index;
  final bool hinted;
  final bool correct;
  final bool compact;
  final bool enlarged;
  final VoidCallback? onSelect;

  @override
  State<_SudokuCell> createState() => _SudokuCellState();
}

class _SudokuCellState extends State<_SudokuCell> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final board = widget.board;
    final index = widget.index;
    final row = index ~/ 9;
    final column = index % 9;
    final selected = board.selected == index;
    final related = !selected && board.isRelated(index);
    final given = board.isGiven(index);
    final wrong = board.isWrong(index);
    final conflict = board.conflicts.contains(index);
    final isError = wrong || conflict;
    final value = board.valueAt(index);
    final notes = board.notesAt(index);
    final noteDigits = [
      for (var digit = 1; digit <= 9; digit++)
        if ((notes & (1 << digit)) != 0) digit,
    ];
    final description = [
      'Hàng ${row + 1}, cột ${column + 1}',
      if (value == 0)
        'ô trống'
      else if (given)
        'số cho sẵn $value'
      else
        'số đã nhập $value',
      if (selected) 'đang chọn',
      if (related) 'ô liên quan',
      if (wrong) 'sai',
      if (conflict) 'trùng số',
      if (widget.hinted) 'gợi ý 1',
      if (widget.correct && !isError) 'đã điền đúng',
      if (noteDigits.isNotEmpty) 'ghi chú ${noteDigits.join(', ')}',
    ].join(', ');
    final (background, markColor, duration) = switch ((
      isError,
      widget.hinted,
      widget.correct,
      selected,
      related,
    )) {
      (true, _, _, _, _) => (
        NeuroTheme.errorFill,
        NeuroTheme.error,
        NeuroTheme.wrong,
      ),
      (_, true, _, _, _) => (
        NeuroTheme.primaryContainer,
        NeuroTheme.onPrimaryContainer,
        NeuroTheme.select,
      ),
      (_, _, true, _, _) => (
        NeuroTheme.successFill,
        NeuroTheme.success,
        NeuroTheme.correct,
      ),
      (_, _, _, true, _) => (
        NeuroTheme.selected,
        NeuroTheme.ink,
        NeuroTheme.select,
      ),
      (_, _, _, _, true) => (
        NeuroTheme.related,
        NeuroTheme.ink,
        NeuroTheme.select,
      ),
      _ => (NeuroTheme.board, NeuroTheme.ink, NeuroTheme.select),
    };
    final hasFeedback = isError || widget.hinted || widget.correct;
    const strong = BorderSide(color: NeuroTheme.group, width: 2);
    const light = BorderSide(color: NeuroTheme.grid);
    final chosen = board.selected;
    return Semantics(
      label: description,
      selected: selected,
      button: true,
      onTap: widget.onSelect,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : duration,
        curve: Curves.easeOut,
        color: background,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onSelect,
            onFocusChange: (focused) => setState(() => _focused = focused),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: row == 0 ? strong : BorderSide.none,
                  left: column == 0 ? strong : BorderSide.none,
                  bottom: row % 3 == 2 ? strong : light,
                  right: column % 3 == 2 ? strong : light,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CustomPaint(
                  foregroundPainter: _CellMarks(
                    selected: selected,
                    focus: _focused,
                    feedback: hasFeedback ? markColor : null,
                    dashed: widget.hinted && !isError,
                    rowStart:
                        chosen != null && row == chosen ~/ 9 && column == 0,
                    rowEnd: chosen != null && row == chosen ~/ 9 && column == 8,
                    columnStart:
                        chosen != null && column == chosen % 9 && row == 0,
                    columnEnd:
                        chosen != null && column == chosen % 9 && row == 8,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (value != 0)
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$value',
                              style: TextStyle(
                                fontSize: widget.compact ? 18 : 20,
                                height: 1.2,
                                fontFeatures: NeuroTheme.digits,
                                fontWeight: given
                                    ? FontWeight.w700
                                    : hasFeedback
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: markColor,
                              ),
                            ),
                          ),
                        )
                      else if (notes != 0)
                        _PencilNotes(
                          digits: noteDigits,
                          enlarged: widget.enlarged,
                        ),
                      if (hasFeedback)
                        Positioned(
                          top: 1,
                          right: 2,
                          child: Text(
                            isError
                                ? '!'
                                : widget.hinted
                                ? '1'
                                : '✓',
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: markColor,
                            ),
                          ),
                        ),
                      if (isError && widget.hinted)
                        const Positioned(
                          bottom: 1,
                          left: 2,
                          child: Text(
                            '1',
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1,
                              color: NeuroTheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CellMarks extends CustomPainter {
  const _CellMarks({
    required this.selected,
    required this.focus,
    required this.feedback,
    required this.dashed,
    required this.rowStart,
    required this.rowEnd,
    required this.columnStart,
    required this.columnEnd,
  });

  final bool selected;
  final bool focus;
  final Color? feedback;
  final bool dashed;
  final bool rowStart;
  final bool rowEnd;
  final bool columnStart;
  final bool columnEnd;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide < 12) return;
    final paint = Paint()
      ..color = NeuroTheme.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final edge = (Offset.zero & size).deflate(1);
    if (feedback != null) {
      paint.color = feedback!;
      if (dashed) {
        for (final (start, end) in [
          (edge.topLeft, edge.topRight),
          (edge.topRight, edge.bottomRight),
          (edge.bottomRight, edge.bottomLeft),
          (edge.bottomLeft, edge.topLeft),
        ]) {
          final vector = end - start;
          final length = vector.distance;
          final direction = vector / length;
          for (var step = 0.0; step < length; step += 7) {
            canvas.drawLine(
              start + direction * step,
              start + direction * (step + 4).clamp(0, length),
              paint,
            );
          }
        }
      } else {
        canvas.drawRect(edge, paint);
      }
    }
    paint.color = NeuroTheme.primary;
    if (selected) {
      if (feedback == null) canvas.drawRect(edge, paint);
      final corner = edge.topLeft + const Offset(4, 4);
      canvas.drawLine(corner, corner + const Offset(5, 0), paint);
      canvas.drawLine(corner, corner + const Offset(0, 5), paint);
    }
    if (focus) canvas.drawRect(edge.deflate(4), paint);
    final center = size.center(Offset.zero);
    if (rowStart) {
      canvas.drawLine(Offset(0, center.dy), Offset(4, center.dy), paint);
    }
    if (rowEnd) {
      canvas.drawLine(
        Offset(size.width - 4, center.dy),
        Offset(size.width, center.dy),
        paint,
      );
    }
    if (columnStart) {
      canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, 4), paint);
    }
    if (columnEnd) {
      canvas.drawLine(
        Offset(center.dx, size.height - 4),
        Offset(center.dx, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CellMarks old) =>
      old.selected != selected ||
      old.focus != focus ||
      old.feedback != feedback ||
      old.dashed != dashed ||
      old.rowStart != rowStart ||
      old.rowEnd != rowEnd ||
      old.columnStart != columnStart ||
      old.columnEnd != columnEnd;
}

class _PencilNotes extends StatelessWidget {
  const _PencilNotes({required this.digits, required this.enlarged});

  final List<int> digits;
  final bool enlarged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var row = 0; row < 3; row++)
        Expanded(
          child: Row(
            children: [
              for (var column = 0; column < 3; column++)
                Expanded(child: Center(child: _note(row * 3 + column + 1))),
            ],
          ),
        ),
    ],
  );

  Widget _note(int digit) => !digits.contains(digit)
      ? const SizedBox.shrink()
      : FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$digit',
            style: TextStyle(
              fontSize: enlarged ? 10 : 9,
              height: 1.15,
              fontWeight: FontWeight.w500,
              color: NeuroTheme.muted,
              fontFeatures: NeuroTheme.digits,
            ),
          ),
        );
}
