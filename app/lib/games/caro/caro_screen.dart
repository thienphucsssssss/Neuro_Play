import 'package:material_ui/material_ui.dart';

import '../game_widgets.dart';
import 'caro_ai.dart';
import 'caro_board.dart';
import 'caro_game.dart';
import 'caro_grid.dart';

class CaroScreen extends StatefulWidget {
  const CaroScreen({this.createGame, super.key});

  final CaroGame Function()? createGame;

  @override
  State<CaroScreen> createState() => _CaroScreenState();
}

class _CaroScreenState extends State<CaroScreen> {
  static const _skill = 'Chiến thuật và dự đoán';
  late final CaroGame _game = widget.createGame?.call() ?? CaroGame();

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  void _zoom() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExpandedCaro(game: _game),
    );
  }

  void _replay() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          _CaroReplay(moves: _game.moves, winningLine: _game.winningLine),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _game,
    builder: (context, _) {
      final difficulty = _game.difficulty;
      final outcome = _game.outcome;
      return LocalGamePage(
        title: outcome == null ? 'Cờ Caro' : 'Kết quả Caro',
        children: difficulty == null
            ? [
                Text(
                  'Chọn độ khó',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Text(_skill),
                const Text(
                  'Bạn cầm X và đi trước. Xếp ít nhất năm quân liên tiếp để thắng.',
                ),
                for (final level in CaroDifficulty.values)
                  OutlinedButton(
                    onPressed: () => _game.start(level),
                    child: Text(level.label),
                  ),
              ]
            : outcome != null
            ? [
                LocalGameResult(
                  title: switch (outcome) {
                    CaroOutcome.playerWin => 'Bạn thắng!',
                    CaroOutcome.computerWin => 'Máy thắng',
                    CaroOutcome.draw => 'Ván hòa',
                  },
                  skill: _skill,
                  success: outcome == CaroOutcome.playerWin,
                  metrics: [
                    LocalGameMetric(label: 'Độ khó', value: difficulty.label),
                    LocalGameMetric(
                      label: 'Số nước',
                      value: '${_game.moveCount}',
                    ),
                    LocalGameMetric(
                      label: 'Thời gian',
                      value: roundTime(_game.elapsed),
                    ),
                  ],
                ),
                CaroGrid(
                  board: _game.board,
                  lastMove: _game.lastMove,
                  winningLine: _game.winningLine,
                ),
                FilledButton(
                  onPressed: _replay,
                  child: const Text('Xem lại ván'),
                ),
                OutlinedButton(
                  onPressed: () => _game.start(difficulty),
                  child: const Text('Chơi ván mới'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Về trang chủ'),
                ),
              ]
            : [
                Text('Mức ${difficulty.label.toLowerCase()} · $_skill'),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    LocalGameClock(elapsed: () => _game.elapsed),
                    LocalGameMetric(
                      label: 'Số nước',
                      value: '${_game.moveCount}',
                    ),
                  ],
                ),
                _TurnStatus(game: _game),
                CaroGrid(
                  board: _game.board,
                  lastMove: _game.lastMove,
                  onTap: _game.canPlay ? _game.play : null,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _game.canUndo ? _game.undo : null,
                      child: const Text('Hoàn tác'),
                    ),
                    OutlinedButton(
                      onPressed: _zoom,
                      child: const Text('Phóng to'),
                    ),
                    if (_game.failed)
                      FilledButton(
                        onPressed: _game.retryComputer,
                        child: const Text('Thử lại'),
                      ),
                  ],
                ),
              ],
      );
    },
  );
}

class _TurnStatus extends StatelessWidget {
  const _TurnStatus({required this.game});

  final CaroGame game;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      game.outcome != null
          ? 'Đã kết thúc ván. Đóng bàn phóng to để xem kết quả.'
          : game.failed
          ? 'Máy chưa chọn được nước đi. Bạn có thể thử lại hoặc hoàn tác.'
          : game.thinking
          ? 'Máy đang tính…'
          : 'Lượt của bạn (X)',
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );
}

class _ExpandedCaro extends StatefulWidget {
  const _ExpandedCaro({required this.game});

  final CaroGame game;

  @override
  State<_ExpandedCaro> createState() => _ExpandedCaroState();
}

class _ExpandedCaroState extends State<_ExpandedCaro> {
  static const _cell = 48.0;
  static const _side = CaroBoard.size * _cell;
  final _transform = TransformationController();
  late int _selected = widget.game.lastMove ?? CaroBoard.center;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reveal();
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _select(int index) {
    setState(() => _selected = index);
    _reveal();
  }

  void _moveCursor(int row, int column) {
    final r = (_selected ~/ CaroBoard.size + row).clamp(0, CaroBoard.size - 1);
    final c = (_selected % CaroBoard.size + column).clamp(
      0,
      CaroBoard.size - 1,
    );
    _select(r * CaroBoard.size + c);
  }

  void _reveal() {
    if (_viewport.isEmpty) return;
    // Keep the selected cell fully visible without changing the 48dp scale.
    final current = _transform.value.getTranslation();
    double reveal(double translation, int index, double viewport) {
      final leading = index * _cell + translation;
      final correction = leading < 0
          ? -leading
          : leading + _cell > viewport
          ? viewport - leading - _cell
          : 0.0;
      return (translation + correction).clamp(-(_side - viewport), 0.0);
    }

    final x = reveal(current.x, _selected % CaroBoard.size, _viewport.width);
    final y = reveal(current.y, _selected ~/ CaroBoard.size, _viewport.height);
    _transform.value = Matrix4.identity()..setTranslationRaw(x, y, 0);
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .94,
    child: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, bounds) {
          _viewport = Size(
            (bounds.maxWidth - 32).clamp(1.0, _side),
            (bounds.maxHeight * .55).clamp(96.0, 440.0),
          );
          return ListenableBuilder(
            listenable: widget.game,
            builder: (context, _) {
              final game = widget.game;
              final enabled = game.canPlay && game.board.isEmpty(_selected);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Bàn Caro phóng to',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    _TurnStatus(game: game),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '${caroCoordinates(_selected)} · ${game.board.cells[_selected]?.label ?? 'Ô trống'}',
                      ),
                    ),
                    Center(
                      child: SizedBox.fromSize(
                        size: _viewport,
                        child: InteractiveViewer(
                          transformationController: _transform,
                          constrained: false,
                          scaleEnabled: false,
                          minScale: 1,
                          maxScale: 1,
                          child: SizedBox.square(
                            dimension: _side,
                            child: CaroGrid(
                              board: game.board,
                              selected: _selected,
                              lastMove: game.lastMove,
                              winningLine: game.winningLine,
                              onTap: _select,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final (dr, dc, icon, label) in [
                          (0, -1, Icons.arrow_back, 'Sang trái'),
                          (-1, 0, Icons.arrow_upward, 'Lên một hàng'),
                          (1, 0, Icons.arrow_downward, 'Xuống một hàng'),
                          (0, 1, Icons.arrow_forward, 'Sang phải'),
                        ])
                          IconButton.outlined(
                            tooltip: label,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: () => _moveCursor(dr, dc),
                            icon: Icon(icon),
                          ),
                      ],
                    ),
                    FilledButton(
                      onPressed: enabled ? () => game.play(_selected) : null,
                      child: const Text('Đánh vào ô đã chọn'),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: game.canUndo ? game.undo : null,
                          child: const Text('Hoàn tác'),
                        ),
                        if (game.failed)
                          OutlinedButton(
                            onPressed: game.retryComputer,
                            child: const Text('Thử lại'),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ),
  );
}

class _CaroReplay extends StatefulWidget {
  const _CaroReplay({required this.moves, required this.winningLine});

  final List<CaroMove> moves;
  final List<int> winningLine;

  @override
  State<_CaroReplay> createState() => _CaroReplayState();
}

class _CaroReplayState extends State<_CaroReplay> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final end = _step == widget.moves.length;
    final last = _step == 0 ? null : widget.moves[_step - 1];
    return LocalGamePage(
      title: 'Xem lại ván Caro',
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            'Nước $_step / ${widget.moves.length}'
            '${last == null ? '' : ' · ${last.mark.label} · ${caroCoordinates(last.index)}'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        CaroGrid(
          board: CaroBoard.fromMoves(widget.moves.take(_step)),
          lastMove: last?.index,
          winningLine: end ? widget.winningLine : const [],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _step == 0 ? null : () => setState(() => _step--),
              child: const Text('Lùi một nước'),
            ),
            FilledButton(
              onPressed: end ? null : () => setState(() => _step++),
              child: const Text('Tiến một nước'),
            ),
          ],
        ),
      ],
    );
  }
}
