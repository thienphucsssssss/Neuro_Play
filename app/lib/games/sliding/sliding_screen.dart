import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../core/neuro_theme.dart';
import '../game_widgets.dart';
import 'sliding_board.dart';
import 'sliding_game.dart';

class SlidingScreen extends StatefulWidget {
  const SlidingScreen({this.createGame, super.key});

  final SlidingGame Function()? createGame;

  @override
  State<SlidingScreen> createState() => _SlidingScreenState();
}

class _SlidingScreenState extends State<SlidingScreen> {
  static const _skill = 'Không gian và lập kế hoạch';
  late final SlidingGame _game = widget.createGame?.call() ?? SlidingGame();

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _game,
    builder: (context, _) {
      final board = _game.board;
      return LocalGamePage(
        title: _game.completed ? 'Kết quả Xếp hình' : 'Xếp hình',
        children: board == null
            ? [
                Text(
                  'Chọn kích thước bàn',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Text(_skill),
                const Text('Trượt các ô số vào chỗ trống để xếp đúng thứ tự.'),
                for (final size in [3, 4])
                  OutlinedButton(
                    onPressed: () => _game.start(size),
                    child: Text('$size × $size'),
                  ),
              ]
            : _game.completed
            ? [
                LocalGameResult(
                  title: 'Hoàn thành Xếp hình!',
                  skill: _skill,
                  success: true,
                  metrics: [
                    LocalGameMetric(
                      label: 'Kích thước',
                      value: '${board.size} × ${board.size}',
                    ),
                    LocalGameMetric(label: 'Số bước', value: '${_game.moves}'),
                    LocalGameMetric(
                      label: 'Thời gian',
                      value: roundTime(_game.elapsed),
                    ),
                  ],
                ),
                FilledButton(
                  onPressed: () => _game.start(board.size),
                  child: const Text('Chơi đề mới'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Về trang chủ'),
                ),
              ]
            : [
                const Text(_skill),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    LocalGameClock(elapsed: () => _game.elapsed),
                    LocalGameMetric(label: 'Số bước', value: '${_game.moves}'),
                  ],
                ),
                _SlidingGrid(
                  board: board,
                  hint: _game.hint,
                  onSlide: _game.slide,
                ),
                if (_game.hint case final index?)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Gợi ý: trượt ô số ${board.tiles[index]} vào ô trống.',
                    ),
                  )
                else if (_game.searching)
                  Semantics(
                    liveRegion: true,
                    child: const Text('Đang tìm gợi ý…'),
                  )
                else if (_game.hintUnavailable)
                  Semantics(
                    liveRegion: true,
                    child: const Text('Chưa tìm được gợi ý cho thế hiện tại.'),
                  ),
                OutlinedButton(
                  onPressed: _game.searching ? null : _game.requestHint,
                  child: const Text('Gợi ý'),
                ),
              ],
      );
    },
  );
}

class _SlidingGrid extends StatelessWidget {
  const _SlidingGrid({
    required this.board,
    required this.hint,
    required this.onSlide,
  });

  final SlidingBoard board;
  final int? hint;
  final ValueChanged<int> onSlide;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      const gap = 4.0;
      final size = board.size;
      final minimum = size * NeuroTheme.touch + (size - 1) * gap;
      final width = max(minimum, min(bounds.maxWidth, 456.0));
      final tileSize = (width - (size - 1) * gap) / size;
      double x(int index) => (index % size) * (tileSize + gap);
      double y(int index) => (index ~/ size) * (tileSize + gap);
      final duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 170);
      final legal = board.legalMoves.toSet();
      final grid = SizedBox.square(
        dimension: width,
        child: Stack(
          children: [
            Positioned(
              left: x(board.blank),
              top: y(board.blank),
              width: tileSize,
              height: tileSize,
              child: Semantics(
                label: 'Ô trống',
                child: const CustomPaint(painter: _BlankOutline()),
              ),
            ),
            for (var tile = 1; tile < board.tiles.length; tile++)
              Builder(
                key: ValueKey(tile),
                builder: (_) {
                  final index = board.tiles.indexOf(tile);
                  return AnimatedPositioned(
                    duration: duration,
                    curve: Curves.easeInOut,
                    left: x(index),
                    top: y(index),
                    width: tileSize,
                    height: tileSize,
                    child: _NumberTile(
                      tile: tile,
                      hinted: index == hint,
                      onTap: legal.contains(index)
                          ? () => onSlide(index)
                          : null,
                    ),
                  );
                },
              ),
          ],
        ),
      );
      return bounds.maxWidth < width
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: grid)
          : Center(child: grid);
    },
  );
}

class _NumberTile extends StatelessWidget {
  const _NumberTile({required this.tile, required this.hinted, this.onTap});

  final int tile;
  final bool hinted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(4));
    return Semantics(
      label:
          'Ô số $tile${hinted ? ', gợi ý' : ''}${onTap != null ? ', có thể trượt' : ''}',
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: hinted ? NeuroTheme.slidingFill : NeuroTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: hinted ? NeuroTheme.sliding : NeuroTheme.outline,
            width: hinted ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          focusColor: NeuroTheme.primaryContainer,
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('$tile', style: NeuroTheme.score),
                ),
              ),
              if (hinted)
                const Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: NeuroTheme.sliding,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlankOutline extends CustomPainter {
  const _BlankOutline();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1);
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)));
    final paint = Paint()
      ..color = NeuroTheme.outline
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final part in outline.computeMetrics()) {
      for (var start = 0.0; start < part.length; start += 8) {
        canvas.drawPath(
          part.extractPath(start, min(start + 4, part.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BlankOutline oldDelegate) => false;
}
